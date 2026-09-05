const mongoose = require('mongoose');

const customerSchema = new mongoose.Schema({
  _id: { type: String, required: true },
  name: { type: String, required: true },
  shopName: { type: String, required: true },
  ownerName: { type: String, required: true },
  mobileNumber: { type: String, required: true },
  address: { type: String, required: true },
  district: { type: String, required: true },
  city: { type: String, required: true },
  gstNumber: { type: String, default: '' },
  shopImageUrl: { type: String, default: '' },
  latitude: { type: Number },
  longitude: { type: Number },
  lastPurchaseDate: { type: Date },
  totalSpent: { type: Number, default: 0.0 },
  handledById: { type: String },
  handledByName: { type: String },
}, { timestamps: true });

customerSchema.set('toJSON', {
  virtuals: true,
  transform: (doc, ret) => {
    ret.id = ret._id;
    delete ret._id;
    delete ret.__v;
    if (ret.lastPurchaseDate) {
      ret.lastPurchaseDate = ret.lastPurchaseDate.toISOString();
    }
    return ret;
  }
});

const Customer = mongoose.model('Customer', customerSchema);
module.exports = Customer;
