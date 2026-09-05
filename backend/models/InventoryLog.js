const mongoose = require('mongoose');

const inventoryLogSchema = new mongoose.Schema({
  _id: { type: String, required: true, default: () => new mongoose.Types.ObjectId().toString() },
  productId: { type: String, required: true },
  productName: { type: String, required: true },
  changeQuantity: { type: Number, required: true },
  type: { type: String, required: true }, // 'Monthly Entry', 'Sale Deduction', 'Adjustment'
  dateTime: { type: Date, required: true },
  notes: { type: String, default: '' },
}, { timestamps: true });

inventoryLogSchema.set('toJSON', {
  virtuals: true,
  transform: (doc, ret) => {
    ret.id = ret._id;
    delete ret._id;
    delete ret.__v;
    if (ret.dateTime) ret.dateTime = ret.dateTime.toISOString();
    return ret;
  }
});

const InventoryLog = mongoose.model('InventoryLog', inventoryLogSchema);
module.exports = InventoryLog;
