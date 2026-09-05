const mongoose = require('mongoose');

const productSchema = new mongoose.Schema({
  _id: { type: String, required: true, default: () => new mongoose.Types.ObjectId().toString() },
  name: { type: String, required: true },
  packSize: { type: String, required: true },
  wholesalePrice: { type: Number, required: true },
  originalPrice: { type: Number, default: 0.0 },
  remainingStock: { type: Number, required: true },
  imageUrl: { type: String, default: '' },
  isEnabled: { type: Boolean, default: true },
  categoryId: { type: String, default: '' },
  masterProductId: { type: String, default: '' },
}, { timestamps: true });

productSchema.set('toJSON', {
  virtuals: true,
  transform: (doc, ret) => {
    ret.id = ret._id;
    delete ret._id;
    delete ret.__v;
    return ret;
  }
});

const Product = mongoose.model('Product', productSchema);
module.exports = Product;
