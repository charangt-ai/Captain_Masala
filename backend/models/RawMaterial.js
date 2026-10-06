const mongoose = require('mongoose');

const RawMaterialSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true,
    unique: true
  },
  currentStock: {
    type: Number,
    required: true,
    default: 0
  },
  unit: {
    type: String,
    required: true,
    default: 'kg'
  },
  gst: {
    type: Number,
    default: 0
  },
  supplierName: {
    type: String,
    trim: true
  },
  lastUpdated: {
    type: Date,
    default: Date.now
  },
  category: {
    type: String,
    enum: ['CORE_SPICE', 'COMMON_INGREDIENT', 'OIL_FAT', 'ADDITIVE', 'OTHER'],
    default: 'CORE_SPICE'
  },
  minimumStockLevel: {
    type: Number,
    default: 0
  },
  costPerUnit: {
    type: Number,
    default: 0
  },
  expiryDays: {
    type: Number,
    default: 365
  }
});

module.exports = mongoose.model('RawMaterial', RawMaterialSchema);
