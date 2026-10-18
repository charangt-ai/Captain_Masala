const express = require('express');
const mongoose = require('mongoose');
const MasterProduct = require('../models/MasterProduct');
const Product = require('../models/Product');
const InventoryLog = require('../models/InventoryLog');
const { protect } = require('../middleware/auth');
const router = express.Router();

// @desc    Get all master products
// @route   GET /api/master-products
// @access  Private
router.get('/', protect, async (req, res) => {
  try {
    const masterProducts = await MasterProduct.find({});
    res.json(masterProducts);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// @desc    Add a master product
// @route   POST /api/master-products
// @access  Private
router.post('/', protect, async (req, res) => {
  try {
    const data = req.body;
    if (data.id) data._id = data.id;
    const masterProduct = new MasterProduct(data);
    const createdMasterProduct = await masterProduct.save();
    res.status(201).json(createdMasterProduct);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// @desc    Update a master product
// @route   PUT /api/master-products/:id
// @access  Private
router.put('/:id', protect, async (req, res) => {
  try {
    const masterProduct = await MasterProduct.findById(req.params.id);
    if (masterProduct) {
      Object.assign(masterProduct, req.body);
      const updatedMasterProduct = await masterProduct.save();
      res.json(updatedMasterProduct);
    } else {
      res.status(404).json({ message: 'Master product not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// @desc    Delete a master product
// @route   DELETE /api/master-products/:id
// @access  Private
router.delete('/:id', protect, async (req, res) => {
  try {
    const masterProduct = await MasterProduct.findById(req.params.id);
    if (masterProduct) {
      await MasterProduct.findByIdAndDelete(req.params.id);
      
      // Also delete associated products
      await Product.deleteMany({ masterProductId: req.params.id });
      
      res.json({ message: 'Master product removed' });
    } else {
      res.status(404).json({ message: 'Master product not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// @desc    Allocate bulk powder from master product into retail packets
// @route   POST /api/master-products/:id/allocate-to-packets
// @access  Private
router.post('/:id/allocate-to-packets', protect, async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();
  try {
    const { allocations } = req.body;
    if (!allocations || !Array.isArray(allocations) || allocations.length === 0) {
      throw new Error('No allocations provided');
    }

    const masterProduct = await MasterProduct.findById(req.params.id).session(session);
    if (!masterProduct) throw new Error('Master Product not found');

    let totalKgToDeduct = 0;
    const updatedProducts = [];

    for (const alloc of allocations) {
      const allocatedKg = parseFloat(alloc.allocatedKg) || 0;
      const packetCount = parseInt(alloc.packetCount) || 0;

      if (allocatedKg <= 0 || packetCount <= 0) continue;

      totalKgToDeduct += allocatedKg;

      const prod = await Product.findById(alloc.productId).session(session);
      if (prod) {
        prod.remainingStock = (prod.remainingStock || 0) + packetCount;
        await prod.save({ session });

        const log = new InventoryLog({
          productId: prod._id.toString(),
          productName: prod.name,
          changeQuantity: packetCount,
          type: 'Packaging',
          dateTime: new Date(),
          notes: `Direct packet allocation: +${packetCount} packets (${allocatedKg} kg) from ${masterProduct.name}`,
        });
        await log.save({ session });
        updatedProducts.push(prod);
      }
    }

    if (totalKgToDeduct > masterProduct.totalStockKg) {
      throw new Error(`Insufficient bulk stock. Available: ${masterProduct.totalStockKg} kg, requested: ${totalKgToDeduct} kg`);
    }

    masterProduct.totalStockKg = Math.max(0, masterProduct.totalStockKg - totalKgToDeduct);
    await masterProduct.save({ session });

    await session.commitTransaction();
    session.endSession();

    res.json({
      success: true,
      message: 'Packets allocated and stock credited successfully.',
      data: {
        masterProduct,
        updatedProducts,
      },
    });
  } catch (err) {
    await session.abortTransaction();
    session.endSession();
    console.error('Error allocating packets from master product:', err);
    res.status(400).json({ success: false, message: err.message || 'Server error' });
  }
});

module.exports = router;
