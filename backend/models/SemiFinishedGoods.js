const mongoose = require('mongoose');

const SemiFinishedGoodsSchema = new mongoose.Schema({
  name: { type: String, required: true },
  sourceMasterProductId: { type: String, ref: 'MasterProduct' },
  batchNumber: String,
  quantity: { type: Number, required: true },
  unit: { type: String, default: 'kg' },
  stage: {
    type: String,
    enum: ['ROASTED', 'GROUND', 'MIXED', 'DRIED', 'OTHER'],
    required: true
  },
  productionPlanId: { type: mongoose.Schema.Types.ObjectId, ref: 'ProductionPlan' },
  manufacturingDate: Date,
  expiryDate: Date,
  status: {
    type: String,
    enum: ['IN_PROCESS', 'READY_FOR_NEXT_STAGE', 'CONSUMED', 'WASTED'],
    default: 'IN_PROCESS'
  },
}, { timestamps: true });

module.exports = mongoose.model('SemiFinishedGoods', SemiFinishedGoodsSchema);
