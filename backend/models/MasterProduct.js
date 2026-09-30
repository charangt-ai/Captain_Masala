const mongoose = require('mongoose');

const masterProductSchema = new mongoose.Schema({
  _id: { type: String, required: true, default: () => new mongoose.Types.ObjectId().toString() },
  name: { type: String, required: true },
  totalStockKg: { type: Number, default: 0.0 },
  bom: [{
    rawMaterialId: { type: String, required: true },
    rawMaterialName: { type: String, required: true },
    quantityPerUnit: { type: Number, required: true }, // kg required for 1 unit of final product
    unitCost: { type: Number, required: true, default: 0 },
  }],
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
