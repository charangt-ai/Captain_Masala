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

// @desc    Allocate packaging (convert bulk to packets) -> Pending Stock Approval
// @route   POST /api/finished-goods/:id/allocate
// @access  Private
router.post('/:id/allocate', protect, superAdmin, async (req, res) => {
  try {
    const batchId = req.params.id;
    const { allocations } = req.body; // Array of { productId, allocatedKg }
    const PackagingAllocation = require('../models/PackagingAllocation');
    
    const batch = await FinishedGoodsBatch.findById(batchId);
    if (!batch) throw new Error('Finished Goods Batch not found');

    let totalAllocated = 0;
    for (let alloc of allocations) {
      totalAllocated += Number(alloc.allocatedKg);
    }

    if (totalAllocated > batch.currentQuantity) {
      throw new Error(`Insufficient bulk quantity. Available: ${batch.currentQuantity} kg, Requested: ${totalAllocated} kg`);
    }

    const allocationItems = [];

    for (let alloc of allocations) {
      if (alloc.allocatedKg <= 0) continue;

      const product = await Product.findById(alloc.productId);
      if (!product) throw new Error(`Product not found for id ${alloc.productId}`);

      // Calculate size in KG from packSize string (e.g. '100g' -> 0.1, '1kg' -> 1.0)
      let sizeInKg = 0;
      const ps = product.packSize.toLowerCase().trim();
      const numberString = ps.replace(/[^0-9.]/g, '');
      const number = parseFloat(numberString) || 0;
      
      if (ps.includes('kg')) {
        sizeInKg = number;
      } else if (ps.includes('g') || ps.includes('gram')) {
        sizeInKg = number / 1000;
      } else {
        throw new Error(`Invalid packSize format for ${product.name}: ${product.packSize}`);
      }

      if (sizeInKg <= 0) throw new Error(`Could not parse packSize: ${product.packSize}`);

      const packetCount = Math.floor(alloc.allocatedKg / sizeInKg);

      allocationItems.push({
        productId: product._id,
        packSize: product.packSize,
        packSizeKg: sizeInKg,
        allocatedKg: alloc.allocatedKg,
        calculatedPacketCount: packetCount,
      });
    }
    
    const count = await PackagingAllocation.countDocuments();
    const allocationNumber = `PKG-${new Date().getFullYear()}-${(count + 1).toString().padStart(4, '0')}`;

    const packagingAlloc = new PackagingAllocation({
      allocationNumber,
      finishedGoodsBatchId: batch._id,
      status: 'PENDING_STOCK_APPROVAL',
      allocations: allocationItems,
      totalAllocatedKg: totalAllocated,
      preparedBy: req.user.uid || req.user._id || 'admin',
    });
    
    await packagingAlloc.save();
    
    res.status(201).json({ 
      success: true, 
      message: 'Packaging allocation saved and pending stock approval.',
      data: packagingAlloc 
    });
  } catch (error) {
    console.error('Error allocating packaging:', error);
    res.status(400).json({ success: false, message: error.message || 'Server error' });
  }
});

// @desc    Get pending packaging allocations
// @route   GET /api/finished-goods/allocations/pending
// @access  Private
router.get('/allocations/pending', protect, superAdmin, async (req, res) => {
  try {
    const PackagingAllocation = require('../models/PackagingAllocation');
    const allocations = await PackagingAllocation.find({ status: 'PENDING_STOCK_APPROVAL' })
      .populate('finishedGoodsBatchId')
      .populate('preparedBy', 'name email')
      .populate('allocations.productId', 'name packSize');
    res.json({ success: true, data: allocations });
  } catch (error) {
    console.error('Error fetching pending allocations:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @desc    Approve a packaging allocation (Atomic Posting)
// @route   POST /api/finished-goods/allocations/:id/approve
// @access  Private
router.post('/allocations/:id/approve', protect, superAdmin, async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();
  try {
    const PackagingAllocation = require('../models/PackagingAllocation');
    const alloc = await PackagingAllocation.findById(req.params.id).session(session);
    if (!alloc) throw new Error('Allocation not found');
    if (alloc.status !== 'PENDING_STOCK_APPROVAL') {
      throw new Error(`Allocation is not pending (current status: ${alloc.status})`);
    }

    const batch = await FinishedGoodsBatch.findById(alloc.finishedGoodsBatchId).session(session);
    if (!batch) throw new Error('Finished Goods Batch not found');

    if (alloc.totalAllocatedKg > batch.currentQuantity) {
      throw new Error(`Insufficient bulk quantity. Available: ${batch.currentQuantity} kg, Requested: ${alloc.totalAllocatedKg} kg`);
    }

    // Process each product allocation
    for (let item of alloc.allocations) {
      const product = await Product.findById(item.productId).session(session);
      if (product) {
        product.remainingStock += item.calculatedPacketCount;
        await product.save({ session });

        const log = new InventoryLog({
          productId: product._id.toString(),
          productName: product.name,
          changeQuantity: item.calculatedPacketCount,
          type: 'Packaging',
          dateTime: new Date(),
          notes: `Approved packed ${item.calculatedPacketCount} packets (${item.allocatedKg}kg) from Batch ${batch.batchNumber}`,
        });
        await log.save({ session });
      }
    }

    // Deduct from bulk stock
    batch.currentQuantity -= alloc.totalAllocatedKg;
    
    // Also deduct from MasterProduct totalStockKg
    const masterProduct = await MasterProduct.findById(batch.masterProductId).session(session);
    if (masterProduct) {
      masterProduct.totalStockKg -= alloc.totalAllocatedKg;
      await masterProduct.save({ session });
    }

    await batch.save({ session });

    // Update allocation status
    alloc.status = 'APPROVED';
    alloc.approvedBy = req.user._id || req.user.uid || 'admin';
    alloc.approvedAt = new Date();
    await alloc.save({ session });

    // Update original ManufacturingBatch status
    if (batch.manufacturingBatchId) {
      const ManufacturingBatch = require('../models/ManufacturingBatch');
      const mBatch = await ManufacturingBatch.findById(batch.manufacturingBatchId).session(session);
      if (mBatch) {
        mBatch.status = 'INVENTORY ADDED';
        await mBatch.save({ session });
      }
    }

    await session.commitTransaction();
    res.json({ success: true, message: 'Stock approved and posted to inventory successfully.', data: alloc });
  } catch (error) {
    await session.abortTransaction();
    console.error('Error approving allocation:', error);
    res.status(400).json({ success: false, message: error.message || 'Server error' });
  } finally {
    session.endSession();
  }
});

// @desc    Return a packaging allocation for correction
// @route   POST /api/finished-goods/allocations/:id/return
// @access  Private
router.post('/allocations/:id/return', protect, superAdmin, async (req, res) => {
  try {
    const { reason } = req.body;
    if (!reason) throw new Error('Reason is required for returning an allocation');

    const PackagingAllocation = require('../models/PackagingAllocation');
    const alloc = await PackagingAllocation.findById(req.params.id);
    if (!alloc) throw new Error('Allocation not found');
    if (alloc.status !== 'PENDING_STOCK_APPROVAL') {
      throw new Error(`Allocation is not pending (current status: ${alloc.status})`);
    }

    alloc.status = 'RETURNED_FOR_CORRECTION';
    alloc.rejectionReason = reason;
    await alloc.save();

    res.json({ success: true, message: 'Allocation returned to packaging operator for correction.', data: alloc });
  } catch (error) {
    console.error('Error returning allocation:', error);
    res.status(400).json({ success: false, message: error.message || 'Server error' });
  }
});


module.exports = router;
