const mongoose = require('mongoose');

const MaterialIssueSchema = new mongoose.Schema({
  issueNumber: { type: String, required: true, unique: true },  // Auto: "MI-2026-001"
  productionPlanId: { type: mongoose.Schema.Types.ObjectId, ref: 'ProductionPlan', required: true },

  items: [{
    rawMaterialId: { type: mongoose.Schema.Types.ObjectId, ref: 'RawMaterial', required: true },
    rawMaterialName: String,
    requestedQuantity: Number,     // From production plan
    issuedQuantity: Number,        // Actually issued (may differ)
    unit: String,
    batchNumber: String,           // RM purchase batch (for FEFO)
  }],

  status: {
    type: String,
    enum: ['PENDING', 'ISSUED', 'PARTIALLY_ISSUED', 'RETURNED'],
    default: 'PENDING'
  },

  issuedById: { type: String, ref: 'User' },
  issuedByName: String,
  issuedAt: Date,

  notes: String,
}, { timestamps: true });

module.exports = mongoose.model('MaterialIssue', MaterialIssueSchema);
