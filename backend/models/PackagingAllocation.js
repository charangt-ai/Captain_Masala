const mongoose = require('mongoose');

const packagingAllocationSchema = new mongoose.Schema({
  allocationNumber: { type: String, required: true, unique: true }, // e.g., PKG-2026-0001
  finishedGoodsBatchId: { type: mongoose.Schema.Types.ObjectId, ref: 'FinishedGoodsBatch', required: true },
  status: { 
    type: String, 
    enum: ['DRAFT', 'PENDING_STOCK_APPROVAL', 'RETURNED_FOR_CORRECTION', 'APPROVED', 'REJECTED'], 
    default: 'PENDING_STOCK_APPROVAL' 
  },
  allocations: [{
    productId: { type: mongoose.Schema.Types.ObjectId, ref: 'Product', required: true },
    packSize: { type: String, required: true },
    packSizeKg: { type: Number, required: true },
    allocatedKg: { type: Number, required: true },
    calculatedPacketCount: { type: Number, required: true },
  }],
  totalAllocatedKg: { type: Number, required: true },
  preparedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  approvedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  rejectionReason: { type: String },
  approvedAt: { type: Date },
}, { timestamps: true });

packagingAllocationSchema.set('toJSON', {
  virtuals: true,
  transform: (doc, ret) => {
    ret.id = ret._id;
    delete ret._id;
    delete ret.__v;
    return ret;
  }
});

module.exports = mongoose.model('PackagingAllocation', packagingAllocationSchema);
