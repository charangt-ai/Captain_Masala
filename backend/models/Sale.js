const mongoose = require('mongoose');

const saleItemSchema = new mongoose.Schema({
  productId: { type: String, required: true },
  productName: { type: String, required: true },
  packSize: { type: String, required: true },
  quantity: { type: Number, required: true },
  rate: { type: Number, required: true },
  totalAmount: { type: Number, required: true },
});

const saleSchema = new mongoose.Schema({
  _id: { type: String, required: true, default: () => new mongoose.Types.ObjectId().toString() },
  invoiceNumber: { type: String, required: true },
  customerId: { type: String, required: true },
  customerName: { type: String, required: true },
  shopName: { type: String, required: true },
  sellerId: { type: String, default: '' },
  sellerName: { type: String, default: '' },
  sellerRole: { type: String },
  items: [saleItemSchema],
  totalAmount: { type: Number, required: true },
  discount: { type: Number, required: true },
  finalAmount: { type: Number, required: true },
  paymentStatus: { type: String, required: true },
  prepaidAmount: { type: Number, default: 0.0 },
  deliveryStatus: { type: String, default: 'Delivered' },
  dateTime: { type: Date, required: true },
  phone: { type: String, default: '' },
  status: { type: String, default: 'Active' },
  cancelReason: { type: String },
  updatedAt: { type: Date },
}, { timestamps: true });

saleSchema.set('toJSON', {
  virtuals: true,
  transform: (doc, ret) => {
    ret.id = ret._id;
    delete ret._id;
    delete ret.__v;
    if (ret.dateTime) ret.dateTime = ret.dateTime.toISOString();
    if (ret.updatedAt) ret.updatedAt = ret.updatedAt.toISOString();
    return ret;
  }
});

const Sale = mongoose.model('Sale', saleSchema);
module.exports = Sale;
