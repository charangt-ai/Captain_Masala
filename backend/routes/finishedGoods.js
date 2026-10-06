const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { protect, superAdmin } = require('../middleware/auth');
const FinishedGoodsBatch = require('../models/FinishedGoodsBatch');
const MasterProduct = require('../models/MasterProduct');
const ProductionPlan = require('../models/ProductionPlan');
const InventoryLog = require('../models/InventoryLog');
const Product = require('../models/Product');

// @desc    Generate Finished Goods Batch from a passed QC
// @route   POST /api/finished-goods
// @access  Private
router.post('/', protect, superAdmin, async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const { productionPlanId, qcId, manufacturingBatchId, initialQuantity, manufacturingDate, expiryDate } = req.body;

    const plan = await ProductionPlan.findById(productionPlanId).session(session);
    if (!plan) throw new Error('Production plan not found');
    if (plan.status !== 'QC_PASSED') throw new Error('Cannot add to finished goods. QC is not passed.');

    const masterProduct = await MasterProduct.findById(plan.masterProductId).session(session);
    if (!masterProduct) throw new Error('Master product not found');

    const count = await FinishedGoodsBatch.countDocuments();
    const batchNumber = `FG-CM-${new Date().getFullYear()}-${(count + 1).toString().padStart(4, '0')}`;

    const fgBatch = new FinishedGoodsBatch({
      batchNumber,
      masterProductId: plan.masterProductId,
      masterProductName: plan.masterProductName,
      productionPlanId,
      manufacturingBatchId,
      qcId,
      initialQuantity,
      currentQuantity: initialQuantity,
      manufacturingDate,
      expiryDate
    });

    await fgBatch.save({ session });

    // Update MasterProduct Stock
    masterProduct.totalStockKg += initialQuantity;
    await masterProduct.save({ session });

    // Find and update the sub-products proportionately (optional, based on your logic, but commonly done via logs or MasterProduct sync)
    // For now, we log the addition
    const log = new InventoryLog({
      productId: masterProduct._id.toString(),
      productName: masterProduct.name,
      changeQuantity: initialQuantity,
      type: 'Production Output',
      dateTime: new Date(),
      notes: `Generated FG Batch ${batchNumber} from Plan ${plan.planNumber}`,
    });
    await log.save({ session });

    // Mark plan as COMPLETED
    plan.status = 'COMPLETED';
    await plan.save({ session });

    await session.commitTransaction();
    res.status(201).json({ success: true, data: fgBatch });
  } catch (error) {
    await session.abortTransaction();
    console.error('Error generating Finished Goods:', error);
    res.status(400).json({ success: false, message: error.message || 'Server error' });
  } finally {
    session.endSession();
  }
});

// @desc    Get all Finished Goods Batches
// @route   GET /api/finished-goods
// @access  Private
router.get('/', protect, superAdmin, async (req, res) => {
  try {
    const query = {};
    if (req.query.status) query.status = req.query.status;
    if (req.query.masterProductId) query.masterProductId = req.query.masterProductId;

    const batches = await FinishedGoodsBatch.find(query).sort({ expiryDate: 1 });
    res.json({ success: true, count: batches.length, data: batches });
  } catch (error) {
    console.error('Error fetching FG batches:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @desc    Update FG Batch Status (e.g. Expired, Recalled)
// @route   PUT /api/finished-goods/:id/status
// @access  Private
router.put('/:id/status', protect, superAdmin, async (req, res) => {
  try {
    const { status } = req.body;
    const batch = await FinishedGoodsBatch.findById(req.params.id);
    if (!batch) return res.status(404).json({ success: false, message: 'Batch not found' });

    batch.status = status;
    await batch.save();
    res.json({ success: true, data: batch });
  } catch (error) {
    console.error('Error updating FG batch status:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

module.exports = router;
