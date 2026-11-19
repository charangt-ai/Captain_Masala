const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { protect, admin } = require('../middleware/auth');
const QualityControl = require('../models/QualityControl');
const ProductionPlan = require('../models/ProductionPlan');
const ManufacturingBatch = require('../models/ManufacturingBatch');
const FinishedGoodsBatch = require('../models/FinishedGoodsBatch');
const MasterProduct = require('../models/MasterProduct');
const InventoryLog = require('../models/InventoryLog');

// @desc    Submit QC results for a batch
// @route   POST /api/quality-control
// @access  Private (Admin / QC Inspector / Super Admin)
router.post('/', protect, admin, async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const {
      productionPlanId,
      manufacturingBatchId,
      parameters,
      overallResult,
      batchWeight,
      sampleSize,
      remarks,
      rejectionReason
    } = req.body;

    const plan = await ProductionPlan.findById(productionPlanId).session(session);
    if (!plan) throw new Error('Production plan not found');

    // Resilient ManufacturingBatch lookup
    let batch = null;
    if (manufacturingBatchId && mongoose.Types.ObjectId.isValid(manufacturingBatchId)) {
      batch = await ManufacturingBatch.findById(manufacturingBatchId).session(session);
    }
    if (!batch && plan._id) {
      batch = await ManufacturingBatch.findOne({ productionPlanId: plan._id }).session(session);
    }
    if (!batch && plan.manufacturingBatchId) {
      batch = await ManufacturingBatch.findById(plan.manufacturingBatchId).session(session);
    }
    if (!batch && plan.masterProductId) {
      batch = await ManufacturingBatch.findOne({ targetProductId: plan.masterProductId }).sort({ createdAt: -1 }).session(session);
    }

    if (!batch) {
      throw new Error('Manufacturing batch associated with this plan was not found. Please complete the manufacturing process step first.');
    }

    // Determine actual output weight
    const parsedBatchWeight = Number(batchWeight);
    const finalYield = (parsedBatchWeight && parsedBatchWeight > 0)
      ? parsedBatchWeight
      : (batch.finalOutputWeight && batch.finalOutputWeight > 0 ? batch.finalOutputWeight : (plan.plannedBatchSize || 0));

    if (finalYield <= 0) {
      throw new Error('Final batch weight must be greater than 0 kg');
    }

    // Sync weight back to batch if updated during QC
    if (parsedBatchWeight && parsedBatchWeight > 0 && parsedBatchWeight !== batch.finalOutputWeight) {
      batch.finalOutputWeight = parsedBatchWeight;
    }

    const year = new Date().getFullYear();
    const qcPrefix = `QC-${year}-`;
    const latestQc = await QualityControl.findOne({ qcNumber: new RegExp(`^${qcPrefix}`) })
      .sort({ qcNumber: -1 })
      .session(session);

    let nextQcSeq = 1;
    if (latestQc && latestQc.qcNumber) {
      const parts = latestQc.qcNumber.split('-');
      const lastNum = parseInt(parts[parts.length - 1], 10);
      if (!isNaN(lastNum)) nextQcSeq = lastNum + 1;
    }
    const qcNumber = `${qcPrefix}${nextQcSeq.toString().padStart(3, '0')}`;

    const qc = new QualityControl({
      qcNumber,
      productionPlanId: plan._id,
      manufacturingBatchId: batch._id,
      masterProductId: plan.masterProductId,
      masterProductName: plan.masterProductName,
      parameters: parameters || [],
      overallResult: overallResult || 'PENDING',
      batchWeight: finalYield,
      sampleSize: Number(sampleSize) || 0,
      inspectedById: req.user.id || req.user._id,
      inspectedByName: req.user.name || req.user.email || 'Inspector',
      inspectedAt: Date.now(),
      remarks,
      rejectionReason: overallResult === 'FAILED' ? rejectionReason : ''
    });

    await qc.save({ session });

    // Update Plan and Batch Status
    if (overallResult === 'PASSED' || overallResult === 'CONDITIONAL_PASS') {
      // 1. Auto-create Finished Goods Batch
      const masterProduct = await MasterProduct.findById(plan.masterProductId).session(session);
      if (!masterProduct) throw new Error('Master product not found');

      const fgPrefix = `FG-CM-${year}-`;
      const latestFg = await FinishedGoodsBatch.findOne({ batchNumber: new RegExp(`^${fgPrefix}`) })
        .sort({ batchNumber: -1 })
        .session(session);

      let nextFgSeq = 1;
      if (latestFg && latestFg.batchNumber) {
        const parts = latestFg.batchNumber.split('-');
        const lastNum = parseInt(parts[parts.length - 1], 10);
        if (!isNaN(lastNum)) nextFgSeq = lastNum + 1;
      }
      const fgBatchNumber = `${fgPrefix}${nextFgSeq.toString().padStart(4, '0')}`;

      const fgBatch = new FinishedGoodsBatch({
        batchNumber: fgBatchNumber,
        masterProductId: plan.masterProductId,
        masterProductName: plan.masterProductName,
        productionPlanId: plan._id,
        manufacturingBatchId: batch._id,
        qcId: qc._id,
        initialQuantity: finalYield,
        currentQuantity: finalYield,
        manufacturingDate: new Date(),
        expiryDate: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000) // 1 year expiry
      });
      await fgBatch.save({ session });

      // 2. Update Master Product Stock
      masterProduct.totalStockKg += finalYield;
      await masterProduct.save({ session });

      // 3. Create Inventory Log
      const log = new InventoryLog({
        productId: masterProduct._id.toString(),
        productName: masterProduct.name,
        changeQuantity: finalYield,
        type: 'Production Output',
        dateTime: new Date(),
        notes: `Generated FG Batch ${fgBatchNumber} automatically from passed QC ${qc.qcNumber}`,
      });
      await log.save({ session });

      // 4. Update statuses
      plan.status = 'COMPLETED';
      batch.status = 'QC_PASSED';
      batch.qcStatus = 'PASSED';
    } else if (overallResult === 'FAILED') {
      plan.status = 'QC_FAILED';
      batch.status = 'QC_FAILED';
      batch.qcStatus = 'FAILED';
    }
    
    plan.qualityControlId = qc._id;
    plan.manufacturingBatchId = batch._id;
    await plan.save({ session });
    await batch.save({ session });

    await session.commitTransaction();
    res.status(201).json({ success: true, message: 'QC results submitted successfully', data: qc });
  } catch (error) {
    await session.abortTransaction();
    console.error('Error submitting QC:', error);
    res.status(400).json({ success: false, message: error.message || 'Server error' });
  } finally {
    session.endSession();
  }
});

// @desc    Get all QC records
// @route   GET /api/quality-control
// @access  Private (Admin)
router.get('/', protect, admin, async (req, res) => {
  try {
    const query = {};
    if (req.query.overallResult) query.overallResult = req.query.overallResult;

    const qcs = await QualityControl.find(query).sort({ createdAt: -1 });
    res.json({ success: true, count: qcs.length, data: qcs });
  } catch (error) {
    console.error('Error fetching QC records:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @desc    Get QC by Plan ID
// @route   GET /api/quality-control/plan/:planId
// @access  Private (Admin)
router.get('/plan/:planId', protect, admin, async (req, res) => {
  try {
    const qc = await QualityControl.findOne({ productionPlanId: req.params.planId });
    if (!qc) return res.status(404).json({ success: false, message: 'QC record not found for this plan' });
    res.json({ success: true, data: qc });
  } catch (error) {
    console.error('Error fetching QC by plan:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

module.exports = router;
