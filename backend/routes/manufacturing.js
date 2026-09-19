const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const ManufacturingBatch = require('../models/ManufacturingBatch');
const MasterProduct = require('../models/MasterProduct');
const Product = require('../models/Product');
const InventoryLog = require('../models/InventoryLog');

// @desc    Submit a new manufacturing batch (saved as PENDING APPROVAL)
// @route   POST /api/manufacturing/batch
// @access  Private
router.post('/batch', protect, async (req, res) => {
  try {
    const {
      targetProductId,
      targetProductName,
      createdById,
      createdByName,
      rawMaterialName,
      rawMaterialQuantity,
      rawMaterialAmount,
      gstPercentage,
      weightBeforeDrying,
      weightAfterDrying,
      dryingLoss,
      weightBeforeGrinding,
      weightAfterGrinding,
      grindingLoss,
      finalOutputWeight,
      totalLoss,
      yieldPercentage,
      timestamp,
      status
    } = req.body;

    // Validate Target Master Product exists
    const masterProduct = await MasterProduct.findById(targetProductId);
    if (!masterProduct) {
      return res.status(404).json({ success: false, message: 'Target Master Product not found' });
    }

    // Create the Manufacturing Batch Record
    const newBatch = new ManufacturingBatch({
      targetProductId,
      targetProductName,
      createdById,
      createdByName,
      rawMaterialName,
      rawMaterialQuantity,
      rawMaterialAmount,
      gstPercentage,
      weightBeforeDrying,
      weightAfterDrying,
      dryingLoss,
      weightBeforeGrinding,
      weightAfterGrinding,
      grindingLoss,
      finalOutputWeight,
      totalLoss,
      yieldPercentage,
      status: status || 'PENDING APPROVAL',
      timestamp: timestamp ? new Date(timestamp) : Date.now()
    });
    
    await newBatch.save();

    res.status(201).json({ success: true, batch: newBatch });
  } catch (error) {
    console.error('Error submitting manufacturing batch:', error);
    res.status(500).json({ success: false, message: error.message || 'Server error' });
  }
});

// @desc    Get manufacturing batches by month and year
// @route   GET /api/manufacturing/batches
// @access  Private
router.get('/batches', protect, async (req, res) => {
  try {
    const { month, year } = req.query;
    let query = {};
    
    if (month && year) {
      const startDate = new Date(year, month - 1, 1);
      const endDate = new Date(year, month, 0, 23, 59, 59, 999);
      query.timestamp = { $gte: startDate, $lte: endDate };
    }
    
    const batches = await ManufacturingBatch.find(query).sort({ timestamp: -1 });
    res.json({ success: true, count: batches.length, data: batches });
  } catch (error) {
    console.error('Error fetching manufacturing batches:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @desc    Delete a manufacturing batch and rollback inventory
// @route   DELETE /api/manufacturing/batch/:id
// @access  Private (Super Admin only typically, handled by auth middleware or frontend)
router.delete('/batch/:id', protect, async (req, res) => {
  const session = await MasterProduct.startSession();
  session.startTransaction();

  try {
    const batchId = req.params.id;
    const batch = await ManufacturingBatch.findById(batchId).session(session);
    
    if (!batch) {
      throw new Error('Batch not found');
    }

    // Rollback Master Product stock ONLY if it was added to inventory
    if (batch.addedToInventory) {
      const masterProduct = await MasterProduct.findById(batch.targetProductId).session(session);
      if (masterProduct) {
        masterProduct.totalStockKg -= batch.finalOutputWeight;
        await masterProduct.save({ session });
      }
    }

    await ManufacturingBatch.findByIdAndDelete(batchId).session(session);

    await session.commitTransaction();
    session.endSession();

    res.json({ success: true, message: 'Batch deleted and inventory rolled back' });
  } catch (error) {
    await session.abortTransaction();
    session.endSession();
    console.error('Error deleting manufacturing batch:', error);
    res.status(500).json({ success: false, message: error.message || 'Server error' });
  }
});

// @desc    Approve a manufacturing batch and update inventory
// @route   POST /api/manufacturing/batch/:id/approve
// @access  Private (Super Admin typically)
router.post('/batch/:id/approve', protect, async (req, res) => {
  const session = await MasterProduct.startSession();
  session.startTransaction();

  try {
    const batchId = req.params.id;
    const batch = await ManufacturingBatch.findById(batchId).session(session);
    
    if (!batch) {
      throw new Error('Batch not found');
    }
    
    if (batch.addedToInventory) {
      throw new Error('Batch has already been added to inventory');
    }

    const masterProduct = await MasterProduct.findById(batch.targetProductId).session(session);
    if (!masterProduct) {
      throw new Error('Target Master Product not found');
    }

    // 1. Deduct Raw Material
    const deductionLog = new InventoryLog({
      productId: 'RAW_MATERIAL',
      productName: batch.rawMaterialName,
      changeQuantity: -batch.rawMaterialQuantity,
      type: 'Manufacturing Raw Material Usage',
      dateTime: new Date(),
      notes: `Batch for ${batch.targetProductName}`,
    });
    await deductionLog.save({ session });

    // 2. Add Final Output to Master Stock
    masterProduct.totalStockKg += batch.finalOutputWeight;
    await masterProduct.save({ session });

    // 3. Log the Addition
    const yieldLog = new InventoryLog({
      productId: masterProduct._id.toString(),
      productName: masterProduct.name,
      changeQuantity: batch.finalOutputWeight,
      type: 'Manufacturing Yield',
      dateTime: new Date(),
      notes: `Batch processed. Yield: ${batch.finalOutputWeight}kg from ${batch.rawMaterialQuantity}kg of ${batch.rawMaterialName}`,
    });
    await yieldLog.save({ session });

    // 4. Mark Batch as added
    batch.addedToInventory = true;
    batch.status = 'INVENTORY ADDED';
    await batch.save({ session });

    await session.commitTransaction();
    session.endSession();

    res.json({ success: true, message: 'Batch approved and inventory updated', batch });
  } catch (error) {
    await session.abortTransaction();
    session.endSession();
    console.error('Error approving manufacturing batch:', error);
    res.status(500).json({ success: false, message: error.message || 'Server error' });
  }
});

module.exports = router;
