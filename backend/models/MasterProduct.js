const mongoose = require('mongoose');

const masterProductSchema = new mongoose.Schema({
  _id: { type: String, required: true },
  name: { type: String, required: true },
  totalStockKg: { type: Number, default: 0.0 },
}, { timestamps: true });

masterProductSchema.set('toJSON', {
  virtuals: true,
  transform: (doc, ret) => {
    ret.id = ret._id;
    delete ret._id;
    delete ret.__v;
    return ret;
  }
});

const MasterProduct = mongoose.model('MasterProduct', masterProductSchema);
module.exports = MasterProduct;
