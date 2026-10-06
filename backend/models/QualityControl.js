const mongoose = require('mongoose');

const QualityControlSchema = new mongoose.Schema({
  qcNumber: { type: String, required: true, unique: true },      // Auto: "QC-2026-001"
  productionPlanId: { type: mongoose.Schema.Types.ObjectId, ref: 'ProductionPlan', required: true },
  manufacturingBatchId: { type: mongoose.Schema.Types.ObjectId, ref: 'ManufacturingBatch', required: true },

  // Product info
  masterProductId: { type: String, ref: 'MasterProduct' },
  masterProductName: String,

  // QC Parameters (customizable per product category)
  parameters: [{
    name: String,                                                  // e.g., "Moisture Content", "Color", "Aroma"
    expectedValue: String,                                         // e.g., "< 10%", "Dark Brown", "Strong"
    actualValue: String,
    unit: String,                                                  // e.g., "%", "pH"
    isPassed: { type: Boolean, default: false },
  }],

  // Overall result
  overallResult: {
    type: String,
    enum: ['PENDING', 'PASSED', 'FAILED', 'CONDITIONAL_PASS'],
    default: 'PENDING'
  },

  // Batch details (from manufacturing)
  batchWeight: Number,                                             // Final output weight
  sampleSize: Number,                                              // Weight of sample tested

  // Decision
  inspectedById: { type: String, ref: 'User' },
  inspectedByName: String,
  inspectedAt: Date,
  remarks: String,
  rejectionReason: String,                                         // If FAILED
}, { timestamps: true });

module.exports = mongoose.model('QualityControl', QualityControlSchema);
