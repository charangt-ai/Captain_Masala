const mongoose = require('mongoose');

const DailyStockValuationSchema = new mongoose.Schema({
  date: { type: Date, required: true, unique: true },                // One record per day
  valuationMethod: { type: String, enum: ['FIFO', 'AVERAGE'], default: 'AVERAGE' },

  rawMaterials: {
    totalQuantity: Number,
    totalValue: Number,
    items: [{
      itemId: String,
      itemName: String,
      quantity: Number,
      unitCost: Number,
      totalValue: Number,
    }]
  },

  packagingMaterials: {
    totalQuantity: Number,
    totalValue: Number,
    items: [{
      itemId: String,
      itemName: String,
      quantity: Number,
      unitCost: Number,
      totalValue: Number,
    }]
  },

  finishedGoods: {
    totalQuantity: Number,
    totalValue: Number,
    items: [{
      itemId: String,
      itemName: String,
      batchNumber: String,
      quantity: Number,
      costPerKg: Number,
      totalValue: Number,
    }]
  },

  grandTotal: Number,
  generatedAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model('DailyStockValuation', DailyStockValuationSchema);
