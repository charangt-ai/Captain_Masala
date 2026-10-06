const mongoose = require('mongoose');

const PackagingMaterialSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true, unique: true },
  type: {
    type: String,
    enum: ['POUCH', 'BOX', 'LABEL', 'SEAL', 'CARTON', 'OTHER'],
    required: true
  },
  currentStock: { type: Number, default: 0 },
  unit: { type: String, required: true },                           // 'pcs', 'rolls', 'kg'
  minimumStockLevel: { type: Number, default: 0 },
  costPerUnit: { type: Number, default: 0 },
  supplierName: String,
  lastUpdated: { type: Date, default: Date.now },
}, { timestamps: true });

module.exports = mongoose.model('PackagingMaterial', PackagingMaterialSchema);
