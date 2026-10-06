const mongoose = require('mongoose');

const StockAlertSchema = new mongoose.Schema({
  alertType: {
    type: String,
    enum: ['LOW_STOCK', 'EXPIRY_WARNING', 'EXPIRED'],
    required: true
  },
  itemType: {
    type: String,
    enum: ['RAW_MATERIAL', 'PACKAGING_MATERIAL', 'FINISHED_GOODS'],
    required: true
  },
  itemId: String,
  itemName: String,

  // Details
  currentValue: Number,                                               // Current stock or days to expiry
  thresholdValue: Number,                                             // Minimum stock level or expiry window
  batchNumber: String,                                                // For expiry alerts
  expiryDate: Date,

  // Status
  isRead: { type: Boolean, default: false },
  isResolved: { type: Boolean, default: false },
  resolvedAt: Date,
}, { timestamps: true });

module.exports = mongoose.model('StockAlert', StockAlertSchema);
