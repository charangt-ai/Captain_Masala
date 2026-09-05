const express = require('express');
const MasterProduct = require('../models/MasterProduct');
const Product = require('../models/Product');
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

module.exports = router;
