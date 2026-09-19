const mongoose = require('mongoose');

const ManufacturingBatchSchema = new mongoose.Schema({
  targetProductId: {
    type: String,
    ref: 'MasterProduct',
    required: true,
  },
  targetProductName: {
    type: String,
    required: true,
  },
  createdById: {
    type: String,
    ref: 'User',
  },
  createdByName: {
    type: String,
  },
  rawMaterialName: {
    type: String,
    required: true,
  },
  rawMaterialQuantity: {
    type: Number,
    required: true,
  },
  gstPercentage: {
    type: Number,
    default: 0,
  },
  weightBeforeDrying: Number,
  weightAfterDrying: Number,
  dryingLoss: Number,
  weightBeforeGrinding: Number,
  weightAfterGrinding: Number,
  grindingLoss: Number,
  finalOutputWeight: {
    type: Number,
    required: true,
  },
  totalLoss: Number,
  yieldPercentage: Number,
  status: {
    type: String,
    default: 'PENDING APPROVAL',
  },
  addedToInventory: {
    type: Boolean,
    default: false,
  },
  timestamp: {
    type: Date,
    default: Date.now,
  },
});

module.exports = mongoose.model('ManufacturingBatch', ManufacturingBatchSchema);
