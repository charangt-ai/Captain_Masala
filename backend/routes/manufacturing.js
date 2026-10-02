const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const ManufacturingBatch = require('../models/ManufacturingBatch');
const MasterProduct = require('../models/MasterProduct');
const Product = require('../models/Product');
const InventoryLog = require('../models/InventoryLog');
const Recipe = require('../models/Recipe');
const RawMaterial = require('../models/RawMaterial');

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
      rawMaterials,
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
      rawMaterials,
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

    // Deduct Raw Material IMMEDIATELY upon batch creation
    if (rawMaterials && rawMaterials.length > 0) {
      for (const rm of rawMaterials) {
        const rawMatDoc = await RawMaterial.findOne({ name: rm.name });
        if (rawMatDoc) {
          rawMatDoc.currentStock -= rm.quantity;
          await rawMatDoc.save();
          
          const deductionLog = new InventoryLog({
            productId: rawMatDoc._id.toString(),
            productName: rm.name,
            changeQuantity: -rm.quantity,
            type: 'Manufacturing Raw Material Usage',
            dateTime: new Date(),
            notes: `Batch for ${targetProductName} created`,
          });
          await deductionLog.save();
        }
      }
    } else if (rawMaterialName && rawMaterialQuantity) {
      const rawMatDoc = await RawMaterial.findOne({ name: rawMaterialName });
      if (rawMatDoc) {
        rawMatDoc.currentStock -= rawMaterialQuantity;
        await rawMatDoc.save();
        
        const deductionLog = new InventoryLog({
          productId: rawMatDoc._id.toString(),
          productName: rawMaterialName,
          changeQuantity: -rawMaterialQuantity,
          type: 'Manufacturing Raw Material Usage',
          dateTime: new Date(),
          notes: `Batch for ${targetProductName} created`,
        });
        await deductionLog.save();
      }
    }

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

    // ALWAYS Rollback Raw Materials since they are deducted on creation
    if (batch.rawMaterials && batch.rawMaterials.length > 0) {
      for (const rm of batch.rawMaterials) {
        const rawMatDoc = await RawMaterial.findOne({ name: rm.name }).session(session);
        if (rawMatDoc) {
          rawMatDoc.currentStock += rm.quantity; // Add back the consumed stock
          await rawMatDoc.save({ session });
        }
      }
    } else if (batch.rawMaterialName && batch.rawMaterialQuantity) {
      const rawMatDoc = await RawMaterial.findOne({ name: batch.rawMaterialName }).session(session);
      if (rawMatDoc) {
        rawMatDoc.currentStock += batch.rawMaterialQuantity; // Add back the consumed stock
        await rawMatDoc.save({ session });
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
    // NOTE: Raw material is now deducted immediately upon batch creation (in POST /batch).
    // No need to deduct it here again.

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

// @desc    Validate stock for a manufacturing batch
// @route   POST /api/manufacturing/validate-stock
// @access  Private
router.post('/validate-stock', protect, async (req, res) => {
  try {
    const { productId, batchSize } = req.body;
    
    const recipe = await Recipe.findOne({ productId }).populate('ingredients.rawMaterialId');
    if (!recipe) {
      return res.status(404).json({ success: false, message: 'Recipe not found for this product' });
    }

    const validationResults = [];
    let isStockSufficient = true;

    for (let ingredient of recipe.ingredients) {
      // Calculate required amount for this batch size
      const requiredQty = (ingredient.requiredQuantity / recipe.baseBatchSize) * batchSize;
      const rawMaterial = ingredient.rawMaterialId;
      
      const availableQty = rawMaterial ? rawMaterial.currentStock : 0;
      const isSufficient = availableQty >= requiredQty;
      
      if (!isSufficient) {
        isStockSufficient = false;
      }
      
      validationResults.push({
        rawMaterialId: rawMaterial ? rawMaterial._id : null,
        rawMaterialName: rawMaterial ? rawMaterial.name : 'Unknown',
        requiredQty,
        availableQty,
        isSufficient
      });
    }

    res.json({
      success: true,
      isStockSufficient,
      ingredients: validationResults
    });
  } catch (error) {
    console.error('Error validating stock:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

module.exports = router;
