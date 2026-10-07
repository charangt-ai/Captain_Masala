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
    required: false, // Make optional since we use rawMaterials array now
  },
  rawMaterialQuantity: {
    type: Number,
    required: false,
  },
  gstPercentage: {
    type: Number,
    default: 0,
  },
  rawMaterialAmount: {
    type: Number,
    default: 0,
  },
  rawMaterials: [{
    name: String,
    quantity: Number,
    amount: Number,
    gstPercentage: Number
  }],
  weightBeforeDrying: Number,
  weightAfterDrying: Number,
  dryingLoss: Number,
  weightBeforeGrinding: Number,
  weightAfterGrinding: Number,
  grindingLoss: Number,
  dryingCost: {
    type: Number,
    default: 0,
  },
  grindingCost: {
    type: Number,
    default: 0,
  },
  otherCosts: [{
    name: String,
    amount: Number,
  }],
  finalOutputWeight: {
    type: Number,
    required: true,
  },
  totalLoss: Number,
  yieldPercentage: Number,
  status: {
    type: String,
    enum: [
      'PENDING APPROVAL',
      'IN_PRODUCTION',
      'PRODUCTION_COMPLETE',
      'QC_PENDING',
      'QC_PASSED',
      'QC_FAILED',
      'INVENTORY ADDED',
      'CANCELLED'
    ],
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
  productionPlanId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'ProductionPlan'
  },
  batchNumber: String,
  qcStatus: {
    type: String,
    default: 'PENDING'
  },
});

module.exports = mongoose.model('ManufacturingBatch', ManufacturingBatchSchema);
