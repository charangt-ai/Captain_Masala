const express = require('express');
const InventoryLog = require('../models/InventoryLog');
const Product = require('../models/Product');
const MasterProduct = require('../models/MasterProduct');
const { protect } = require('../middleware/auth');
const router = express.Router();

// @desc    Get inventory logs
// @route   GET /api/inventory-logs
// @access  Private
router.get('/', protect, async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 200;
    const skip = parseInt(req.query.skip) || 0;

    const logs = await InventoryLog.find({})
      .sort({ dateTime: -1 })
      .skip(skip)
      .limit(limit);
      
    res.json(logs);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// @desc    Update stock for a specific product
// @route   PUT /api/inventory-logs/stock/:id
// @access  Private
router.put('/stock/:id', protect, async (req, res) => {
  const { newOpeningStock, notes } = req.body;
  try {
    const product = await Product.findById(req.params.id);
    if (!product) return res.status(404).json({ message: 'Product not found' });

    const diff = newOpeningStock - product.remainingStock;
    product.remainingStock = newOpeningStock;
    await product.save();

    const log = new InventoryLog({
      productId: product._id,
      productName: product.name,
      changeQuantity: diff,
      type: 'Monthly Entry',
      dateTime: new Date(),
      notes: notes || '',
    });
    await log.save();

    res.json({ success: true, product });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// @desc    Update stock for a master product
// @route   PUT /api/inventory-logs/master-stock/:id
// @access  Private
router.put('/master-stock/:id', protect, async (req, res) => {
  const { newOpeningStock, notes } = req.body;
  try {
    const master = await MasterProduct.findById(req.params.id);
    if (!master) return res.status(404).json({ message: 'Master product not found' });

    const diff = newOpeningStock - master.totalStockKg;
    master.totalStockKg = newOpeningStock;
    await master.save();

    const log = new InventoryLog({
      productId: master._id,
      productName: master.name,
      changeQuantity: diff,
      type: 'Monthly Entry',
      dateTime: new Date(),
      notes: notes || '',
    });
    await log.save();

    res.json({ success: true, master });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
