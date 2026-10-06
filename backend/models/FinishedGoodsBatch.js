const mongoose = require('mongoose');

const FinishedGoodsBatchSchema = new mongoose.Schema({
  batchNumber: { type: String, required: true, unique: true },    // Auto: "FG-CM-2026-001"
  masterProductId: { type: String, ref: 'MasterProduct', required: true },
  masterProductName: String,

  // Source traceability
  productionPlanId: { type: mongoose.Schema.Types.ObjectId, ref: 'ProductionPlan' },
  manufacturingBatchId: { type: mongoose.Schema.Types.ObjectId, ref: 'ManufacturingBatch' },
  qcId: { type: mongoose.Schema.Types.ObjectId, ref: 'QualityControl' },

  // Stock
  initialQuantity: { type: Number, required: true },              // kg produced
  currentQuantity: { type: Number, required: true },              // kg remaining
  unit: { type: String, default: 'kg' },

  // Dates
  manufacturingDate: { type: Date, required: true },
  expiryDate: { type: Date, required: true },

  // Costing (from BatchCosting)
  costPerKg: { type: Number, default: 0 },

  // Status
  status: {
    type: String,
    enum: ['ACTIVE', 'DEPLETED', 'EXPIRED', 'RECALLED'],
    default: 'ACTIVE'
  },
}, { timestamps: true });

module.exports = mongoose.model('FinishedGoodsBatch', FinishedGoodsBatchSchema);
