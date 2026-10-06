const mongoose = require('mongoose');

const ProductionPlanSchema = new mongoose.Schema({
  // Identity
  planNumber: { type: String, required: true, unique: true },  // Auto: "PP-2026-001"

  // What to produce
  masterProductId: { type: String, ref: 'MasterProduct', required: true },
  masterProductName: { type: String, required: true },
  recipeId: { type: mongoose.Schema.Types.ObjectId, ref: 'Recipe', required: true },

  // Quantities
  plannedBatchSize: { type: Number, required: true },          // e.g., 100 kg
  plannedIngredients: [{
    rawMaterialId: { type: mongoose.Schema.Types.ObjectId, ref: 'RawMaterial' },
    rawMaterialName: String,
    requiredQuantity: Number,                                   // Calculated from recipe
    availableStock: Number,                                     // Snapshot at plan time
    isSufficient: Boolean
  }],

  // Scheduling
  plannedDate: { type: Date, required: true },
  priority: { type: String, enum: ['LOW', 'MEDIUM', 'HIGH', 'URGENT'], default: 'MEDIUM' },

  // Status Lifecycle
  status: {
    type: String,
    enum: [
      'DRAFT',                 // Planner is preparing
      'AWAITING_APPROVAL',     // Sent for manager approval
      'APPROVED',              // Approved, ready for material issue
      'MATERIALS_ISSUED',      // Raw materials issued to floor
      'IN_PRODUCTION',         // Manufacturing started
      'QC_PENDING',            // Production done, awaiting QC
      'QC_PASSED',             // QC approved
      'QC_FAILED',             // QC rejected
      'COMPLETED',             // Added to finished goods
      'CANCELLED'
    ],
    default: 'DRAFT'
  },

  // Audit
  createdById: { type: String, ref: 'User' },
  createdByName: String,
  approvedById: { type: String, ref: 'User' },
  approvedByName: String,
  approvedAt: Date,

  // Linked records (populated after each stage)
  materialIssueId: { type: mongoose.Schema.Types.ObjectId, ref: 'MaterialIssue' },
  manufacturingBatchId: { type: mongoose.Schema.Types.ObjectId, ref: 'ManufacturingBatch' },
  qualityControlId: { type: mongoose.Schema.Types.ObjectId, ref: 'QualityControl' },

  notes: String,
}, { timestamps: true });

module.exports = mongoose.model('ProductionPlan', ProductionPlanSchema);
