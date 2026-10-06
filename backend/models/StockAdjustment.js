const mongoose = require('mongoose');

const StockAdjustmentSchema = new mongoose.Schema({
  adjustmentNumber: { type: String, required: true, unique: true },  // Auto: "ADJ-2026-001"

  // What is being adjusted
  itemType: {
    type: String,
    enum: ['RAW_MATERIAL', 'PACKAGING_MATERIAL', 'SEMI_FINISHED', 'FINISHED_GOODS'],
    required: true
  },
  itemId: { type: String, required: true },
  itemName: { type: String, required: true },

  // Quantities
  currentStock: { type: Number, required: true },                    // Stock before adjustment
  adjustedStock: { type: Number, required: true },                   // Stock after adjustment
  difference: { type: Number, required: true },                      // adjustedStock - currentStock

  // Reason
  reason: {
    type: String,
    enum: ['DAMAGE', 'EXPIRY', 'THEFT', 'COUNTING_ERROR', 'SPILLAGE', 'RETURN', 'OTHER'],
    required: true
  },
  notes: String,

  // Approval workflow
  status: {
    type: String,
    enum: ['PENDING_APPROVAL', 'APPROVED', 'REJECTED'],
    default: 'PENDING_APPROVAL'
  },
  requestedById: { type: String, ref: 'User' },
  requestedByName: String,
  approvedById: { type: String, ref: 'User' },
  approvedByName: String,
  approvedAt: Date,
  rejectionReason: String,
}, { timestamps: true });

module.exports = mongoose.model('StockAdjustment', StockAdjustmentSchema);
