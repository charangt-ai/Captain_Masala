const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { protect, superAdmin } = require('../middleware/auth');
const MaterialIssue = require('../models/MaterialIssue');
const ProductionPlan = require('../models/ProductionPlan');
const RawMaterial = require('../models/RawMaterial');
const InventoryLog = require('../models/InventoryLog');

// @desc    Create material issue for a production plan
// @route   POST /api/material-issues
// @access  Private
router.post('/', protect, superAdmin, async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const { productionPlanId, items, notes } = req.body;

    const plan = await ProductionPlan.findById(productionPlanId).session(session);
    if (!plan) throw new Error('Production plan not found');
    if (plan.status !== 'APPROVED') throw new Error(`Cannot issue materials for plan in status: ${plan.status}`);

    const count = await MaterialIssue.countDocuments();
    const issueNumber = `MI-${new Date().getFullYear()}-${(count + 1).toString().padStart(3, '0')}`;

    const issueItems = [];
    
    // Deduct stock for each item
    for (let item of items) {
      const rawMat = await RawMaterial.findById(item.rawMaterialId).session(session);
      if (!rawMat) throw new Error(`Raw material not found: ${item.rawMaterialId}`);
      if (rawMat.currentStock < item.issuedQuantity) {
        throw new Error(`Insufficient stock for ${rawMat.name}. Required: ${item.issuedQuantity}, Available: ${rawMat.currentStock}`);
      }

      rawMat.currentStock -= item.issuedQuantity;
      await rawMat.save({ session });

      issueItems.push({
        rawMaterialId: rawMat._id,
        rawMaterialName: rawMat.name,
        requestedQuantity: item.requestedQuantity,
        issuedQuantity: item.issuedQuantity,
        unit: rawMat.unit,
        batchNumber: item.batchNumber // Optional
      });

      const log = new InventoryLog({
        productId: rawMat._id.toString(),
        productName: rawMat.name,
        changeQuantity: -item.issuedQuantity,
        type: 'Manufacturing Raw Material Usage',
        dateTime: new Date(),
        notes: `Material Issue ${issueNumber} for Plan ${plan.planNumber}`,
      });
      await log.save({ session });
    }

    const materialIssue = new MaterialIssue({
      issueNumber,
      productionPlanId,
      items: issueItems,
      status: 'ISSUED',
      issuedById: req.user._id,
      issuedByName: req.user.name || req.user.email,
      issuedAt: Date.now(),
      notes
    });

    await materialIssue.save({ session });

    plan.status = 'MATERIALS_ISSUED';
    plan.materialIssueId = materialIssue._id;
    await plan.save({ session });

    await session.commitTransaction();
    res.status(201).json({ success: true, data: materialIssue });
  } catch (error) {
    await session.abortTransaction();
    console.error('Error issuing materials:', error);
    res.status(400).json({ success: false, message: error.message || 'Server error' });
  } finally {
    session.endSession();
  }
});

// @desc    Get all material issues
// @route   GET /api/material-issues
// @access  Private
router.get('/', protect, superAdmin, async (req, res) => {
  try {
    const issues = await MaterialIssue.find().sort({ createdAt: -1 });
    res.json({ success: true, count: issues.length, data: issues });
  } catch (error) {
    console.error('Error fetching material issues:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

module.exports = router;
