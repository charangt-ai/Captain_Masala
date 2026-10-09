const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { protect, superAdmin } = require('../middleware/auth');
const QualityControl = require('../models/QualityControl');
const ProductionPlan = require('../models/ProductionPlan');
const ManufacturingBatch = require('../models/ManufacturingBatch');
const FinishedGoodsBatch = require('../models/FinishedGoodsBatch');
const MasterProduct = require('../models/MasterProduct');
const InventoryLog = require('../models/InventoryLog');

// @desc    Submit QC results for a batch
// @route   POST /api/quality-control
// @access  Private (QC Inspector / Admin)
router.post('/', protect, superAdmin, async (req, res) => {
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

    let batch = await ManufacturingBatch.findById(manufacturingBatchId).session(session);
    if (!batch) {
      batch = await ManufacturingBatch.findOne({ productionPlanId }).session(session);
    }
    if (!batch) throw new Error('Manufacturing batch not found');

    const count = await QualityControl.countDocuments();
    const qcNumber = `QC-${new Date().getFullYear()}-${(count + 1).toString().padStart(3, '0')}`;

    const qc = new QualityControl({
      qcNumber,
      productionPlanId,
      manufacturingBatchId,
      masterProductId: plan.masterProductId,
      masterProductName: plan.masterProductName,
      parameters,
      overallResult,
      batchWeight,
      sampleSize,
      inspectedById: req.user._id,
      inspectedByName: req.user.name || req.user.email,
      inspectedAt: Date.now(),
      remarks,
      rejectionReason
    });

    await qc.save({ session });

    // Update Plan and Batch Status
    if (overallResult === 'PASSED' || overallResult === 'CONDITIONAL_PASS') {
      // 1. Auto-create Finished Goods Batch
      const masterProduct = await MasterProduct.findById(plan.masterProductId).session(session);
      if (!masterProduct) throw new Error('Master product not found');

      const fgCount = await FinishedGoodsBatch.countDocuments();
      const fgBatchNumber = `FG-CM-${new Date().getFullYear()}-${(fgCount + 1).toString().padStart(4, '0')}`;

      const fgBatch = new FinishedGoodsBatch({
        batchNumber: fgBatchNumber,
        masterProductId: plan.masterProductId,
        masterProductName: plan.masterProductName,
        productionPlanId: plan._id,
        manufacturingBatchId: batch._id,
        qcId: qc._id,
        initialQuantity: batch.finalOutputWeight,
        currentQuantity: batch.finalOutputWeight,
        manufacturingDate: new Date(),
        expiryDate: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000) // 1 year expiry
      });
      await fgBatch.save({ session });

      // 2. Update Master Product Stock
      masterProduct.totalStockKg += batch.finalOutputWeight;
      await masterProduct.save({ session });

      // 3. Create Inventory Log
      const log = new InventoryLog({
        productId: masterProduct._id.toString(),
        productName: masterProduct.name,
        changeQuantity: batch.finalOutputWeight,
        type: 'Production Output',
        dateTime: new Date(),
        notes: `Generated FG Batch ${fgBatchNumber} automatically from passed QC ${qc.qcNumber}`,
      });
      await log.save({ session });

      // 4. Update statuses (Mark as COMPLETED directly since FG is generated)
      plan.status = 'COMPLETED';
      batch.status = 'QC_PASSED'; // Must be a valid enum in ManufacturingBatch schema
    } else if (overallResult === 'FAILED') {
      plan.status = 'QC_FAILED';
      batch.status = 'QC_FAILED';
    }
    
    plan.qualityControlId = qc._id;
    await plan.save({ session });
    await batch.save({ session });

    await session.commitTransaction();
    res.status(201).json({ success: true, data: qc });
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
// @access  Private
router.get('/', protect, superAdmin, async (req, res) => {
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
// @access  Private
router.get('/plan/:planId', protect, superAdmin, async (req, res) => {
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
