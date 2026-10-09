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

// @desc    Update a raw material
// @route   PUT /api/inventory/raw-materials/:id
// @access  Private
router.put('/:id', protect, async (req, res) => {
  try {
    const { name, currentStock, unit, gst, supplierName } = req.body;
    let material = await RawMaterial.findById(req.params.id);
    if (!material) {
      return res.status(404).json({ success: false, message: 'Material not found' });
    }
    
    material.name = name || material.name;
    material.currentStock = currentStock !== undefined ? Number(currentStock) : material.currentStock;
    material.unit = unit || material.unit;
    material.gst = gst !== undefined ? Number(gst) : material.gst;
    material.supplierName = supplierName || material.supplierName;
    material.lastUpdated = Date.now();
    
    await material.save();
    res.json({ success: true, data: material });
  } catch (error) {
    console.error('Error updating raw material:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @desc    Delete a raw material
// @route   DELETE /api/inventory/raw-materials/:id
// @access  Private
router.delete('/:id', protect, async (req, res) => {
  try {
    const material = await RawMaterial.findByIdAndDelete(req.params.id);
    if (!material) {
      return res.status(404).json({ success: false, message: 'Material not found' });
    }
    res.json({ success: true, message: 'Raw material deleted' });
  } catch (error) {
    console.error('Error deleting raw material:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @desc    Get history of a raw material
// @route   GET /api/inventory/raw-materials/:id/history
// @access  Private
router.get('/:id/history', protect, async (req, res) => {
  try {
    const InventoryLog = require('../models/InventoryLog');
    const logs = await InventoryLog.find({ productId: req.params.id }).sort({ dateTime: -1 });
    res.json({ success: true, count: logs.length, data: logs });
  } catch (error) {
    console.error('Error fetching raw material history:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

module.exports = router;
