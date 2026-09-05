const express = require('express');
const Sale = require('../models/Sale');
const Customer = require('../models/Customer');
const Product = require('../models/Product');
const MasterProduct = require('../models/MasterProduct');
const InventoryLog = require('../models/InventoryLog');
const mongoose = require('mongoose');
const { protect } = require('../middleware/auth');
const router = express.Router();

// Helper
const getPackSizeInKg = (packSize) => {
  const lower = packSize.toLowerCase();
  if (lower === '50 gram - 1 kg bag' || lower === '50g - 1kg bag' || (lower.includes('50') && lower.includes('1 kg'))) {
    return 1.0; 
  }
  if (lower.includes('kg')) {
    const match = /([0-9.]+)\s*kg/.exec(lower);
    if (match) return parseFloat(match[1]) || 1.0;
  } else if (lower.includes('gram') || lower.includes(' g') || lower.endsWith('g')) {
    const match = /([0-9.]+)\s*(?:gram|g)/.exec(lower);
    if (match) return (parseFloat(match[1]) || 0.0) / 1000.0;
  }
  return 1.0;
};

// @desc    Get sales (paginated)
// @route   GET /api/sales
// @access  Private
router.get('/', protect, async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 200;
    const skip = parseInt(req.query.skip) || 0;
    
    const sales = await Sale.find({})
      .sort({ dateTime: -1 })
      .skip(skip)
      .limit(limit);
      
    res.json(sales);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// @desc    Record a sale
// @route   POST /api/sales
// @access  Private
router.post('/', protect, async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const saleData = req.body;
    if (saleData.id) {
      saleData._id = saleData.id;
    }
    const sale = new Sale(saleData);
    await sale.save({ session });

    // Update customer total spent & last purchase
    await Customer.findByIdAndUpdate(
      sale.customerId,
      {
        $inc: { totalSpent: sale.finalAmount },
        lastPurchaseDate: sale.dateTime
      },
      { session }
    );

    // Update inventory
    for (let item of sale.items) {
      const product = await Product.findById(item.productId).session(session);
      if (product) {
        product.remainingStock -= item.quantity;
        await product.save({ session });

        if (product.masterProductId) {
          const masterProduct = await MasterProduct.findById(product.masterProductId).session(session);
          if (masterProduct) {
            const weightInKg = getPackSizeInKg(product.packSize);
            const qtyInKg = item.quantity * weightInKg;

            masterProduct.totalStockKg -= qtyInKg;
            await masterProduct.save({ session });

            // Create inventory log
            const logId = `${sale._id}_${item.productId}`;
            const log = new InventoryLog({
              _id: logId,
              productId: masterProduct._id,
              productName: masterProduct.name,
              changeQuantity: -qtyInKg,
              type: 'Sale Deduction',
              dateTime: sale.dateTime,
              notes: `Invoice: ${sale.invoiceNumber} (${item.quantity}x ${product.packSize})`,
            });
            await log.save({ session });
          }
        }
      }
    }

    await session.commitTransaction();
    res.status(201).json(sale);
  } catch (error) {
    await session.abortTransaction();
    console.error(error);
    res.status(500).json({ message: 'Server error recording sale' });
  } finally {
    session.endSession();
  }
});

// @desc    Update payment status
// @route   PUT /api/sales/:id/payment
// @access  Private
router.put('/:id/payment', protect, async (req, res) => {
  try {
    const sale = await Sale.findById(req.params.id);
    if (sale) {
      sale.paymentStatus = req.body.status;
      await sale.save();
      res.json(sale);
    } else {
      res.status(404).json({ message: 'Sale not found' });
    }
  } catch (error) {
    res.status(500).json({ message: 'Server error' });
  }
});

// @desc    Update prepaid amount
// @route   PUT /api/sales/:id/prepaid
// @access  Private
router.put('/:id/prepaid', protect, async (req, res) => {
  try {
    const sale = await Sale.findById(req.params.id);
    if (sale) {
      const additional = req.body.additionalPrepaidAmount || 0;
      sale.prepaidAmount += additional;
      if (sale.prepaidAmount >= sale.finalAmount) {
        sale.paymentStatus = 'Paid';
      }
      await sale.save();
      res.json(sale);
    } else {
      res.status(404).json({ message: 'Sale not found' });
    }
  } catch (error) {
    res.status(500).json({ message: 'Server error' });
  }
});

// @desc    Cancel sale
// @route   PUT /api/sales/:id/cancel
// @access  Private
router.put('/:id/cancel', protect, async (req, res) => {
  try {
    const sale = await Sale.findById(req.params.id);
    if (sale) {
      sale.status = 'Cancelled';
      sale.cancelReason = req.body.reason;
      sale.updatedAt = new Date();
      await sale.save();
      res.json(sale);
    } else {
      res.status(404).json({ message: 'Sale not found' });
    }
  } catch (error) {
    res.status(500).json({ message: 'Server error' });
  }
});

// @desc    Update delivery status
// @route   PUT /api/sales/:id/delivery
// @access  Private
router.put('/:id/delivery', protect, async (req, res) => {
  try {
    const sale = await Sale.findById(req.params.id);
    if (sale) {
      sale.deliveryStatus = req.body.status;
      sale.updatedAt = new Date();
      await sale.save();
      res.json(sale);
    } else {
      res.status(404).json({ message: 'Sale not found' });
    }
  } catch (error) {
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
