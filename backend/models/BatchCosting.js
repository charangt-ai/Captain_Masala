const mongoose = require('mongoose');

const BatchCostingSchema = new mongoose.Schema({
  costingNumber: { type: String, required: true, unique: true },
  productionPlanId: { type: mongoose.Schema.Types.ObjectId, ref: 'ProductionPlan' },
  manufacturingBatchId: { type: mongoose.Schema.Types.ObjectId, ref: 'ManufacturingBatch' },

  masterProductId: { type: String, ref: 'MasterProduct' },
  masterProductName: String,
  batchNumber: String,

  // Cost breakdown
  rawMaterialCost: {
    items: [{
      name: String,
      quantity: Number,
      unitCost: Number,
      gstAmount: Number,
      totalCost: Number,
    }],
    subtotal: Number,
  },

  packagingCost: {
    items: [{
      name: String,
      quantity: Number,
      unitCost: Number,
      totalCost: Number,
    }],
    subtotal: Number,
  },

  overheadCost: {
    labor: { type: Number, default: 0 },
    electricity: { type: Number, default: 0 },
    fuel: { type: Number, default: 0 },
    depreciation: { type: Number, default: 0 },
    miscellaneous: { type: Number, default: 0 },
    subtotal: Number,
  },

  // Totals
  totalCost: Number,
  outputQuantity: Number,                                           // kg of finished goods
  costPerKg: Number,                                                // totalCost / outputQuantity
  processLossKg: Number,
  processLossPercentage: Number,

  notes: String,
}, { timestamps: true });

module.exports = mongoose.model('BatchCosting', BatchCostingSchema);
