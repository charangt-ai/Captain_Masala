const mongoose = require('mongoose');

const categorySchema = new mongoose.Schema({
  _id: { type: String, required: true },
  name: { type: String, required: true },
  image: { type: String, default: '' },
}, { timestamps: true });

categorySchema.set('toJSON', {
  virtuals: true,
  transform: (doc, ret) => {
    ret.id = ret._id;
    delete ret._id;
    delete ret.__v;
    return ret;
  }
});

const Category = mongoose.model('Category', categorySchema);
module.exports = Category;
