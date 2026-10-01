const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const RawMaterial = require('../models/RawMaterial');

// @desc    Get all raw materials
// @route   GET /api/inventory/raw-materials
// @access  Private
router.get('/', protect, async (req, res) => {
  try {
    const materials = await RawMaterial.find().sort({ name: 1 });
    res.json({ success: true, count: materials.length, data: materials });
  } catch (error) {
    console.error('Error fetching raw materials:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @desc    Add new raw material
// @route   POST /api/inventory/raw-materials
// @access  Private
router.post('/', protect, async (req, res) => {
  try {
    const { name, currentStock, unit, gst, supplierName } = req.body;

    let material = await RawMaterial.findOne({ name });
    if (material) {
      // Update existing stock
      material.currentStock += Number(currentStock);
      material.gst = gst || material.gst;
      material.supplierName = supplierName || material.supplierName;
      material.lastUpdated = Date.now();
      await material.save();
    } else {
      // Create new
      material = new RawMaterial({
        name,
        currentStock,
        unit,
        gst,
        supplierName
      });
      await material.save();
    }

    res.status(201).json({ success: true, data: material });
  } catch (error) {
    console.error('Error adding raw material:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

module.exports = router;
