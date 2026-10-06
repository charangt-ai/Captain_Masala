const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { protect, superAdmin } = require('../middleware/auth');
const BatchCosting = require('../models/BatchCosting');
const ProductionPlan = require('../models/ProductionPlan');
const MaterialIssue = require('../models/MaterialIssue');
const QualityControl = require('../models/QualityControl');
const FinishedGoodsBatch = require('../models/FinishedGoodsBatch');

// @desc    Calculate and save batch costing
// @route   POST /api/batch-costing
// @access  Private (Admin / Finance)
router.post('/', protect, superAdmin, async (req, res) => {
  try {
    const { productionPlanId, overheadCost } = req.body;

    const plan = await ProductionPlan.findById(productionPlanId);
    if (!plan) return res.status(404).json({ success: false, message: 'Production plan not found' });

    const issue = await MaterialIssue.findOne({ productionPlanId });
    if (!issue) return res.status(404).json({ success: false, message: 'Material issue not found for this plan' });

    const qc = await QualityControl.findOne({ productionPlanId });
    if (!qc) return res.status(404).json({ success: false, message: 'QC record not found for this plan' });

    const fgBatch = await FinishedGoodsBatch.findOne({ productionPlanId });
    if (!fgBatch) return res.status(404).json({ success: false, message: 'Finished goods batch not found for this plan' });

    const count = await BatchCosting.countDocuments();
    const costingNumber = `COST-${new Date().getFullYear()}-${(count + 1).toString().padStart(4, '0')}`;

    // Calculate RM Cost
    let rmSubtotal = 0;
    const rmItems = issue.items.map(item => {
      // Assuming costPerUnit is fetched or passed. We use 0 as a placeholder if not tracked directly here
      // Realistically you'd populate RawMaterial to get costPerUnit
      const unitCost = 0; // TODO: fetch from RawMaterial
      const total = item.issuedQuantity * unitCost;
      rmSubtotal += total;
      return {
        name: item.rawMaterialName,
        quantity: item.issuedQuantity,
        unitCost: unitCost,
        totalCost: total
      };
    });

    const ohSubtotal = (overheadCost.labor || 0) + (overheadCost.electricity || 0) + 
                       (overheadCost.fuel || 0) + (overheadCost.depreciation || 0) + 
                       (overheadCost.miscellaneous || 0);

    const totalCost = rmSubtotal + ohSubtotal; // Ignoring packaging cost for now for simplicity
    const outputQuantity = fgBatch.initialQuantity;
    const costPerKg = outputQuantity > 0 ? (totalCost / outputQuantity) : 0;
    
    // Process loss: Issued qty - Output qty
    const totalIssued = issue.items.reduce((acc, item) => acc + item.issuedQuantity, 0);
    const processLossKg = totalIssued - outputQuantity;
    const processLossPercentage = totalIssued > 0 ? (processLossKg / totalIssued) * 100 : 0;

    const costing = new BatchCosting({
      costingNumber,
      productionPlanId,
      manufacturingBatchId: fgBatch.manufacturingBatchId,
      masterProductId: fgBatch.masterProductId,
      masterProductName: fgBatch.masterProductName,
      batchNumber: fgBatch.batchNumber,
      rawMaterialCost: {
        items: rmItems,
        subtotal: rmSubtotal,
      },
      overheadCost: {
        ...overheadCost,
        subtotal: ohSubtotal,
      },
      totalCost,
      outputQuantity,
      costPerKg,
      processLossKg,
      processLossPercentage
    });

    await costing.save();

    // Update FG Batch with cost
    fgBatch.costPerKg = costPerKg;
    await fgBatch.save();

    res.status(201).json({ success: true, data: costing });
  } catch (error) {
    console.error('Error saving batch costing:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @desc    Get all batch costings
// @route   GET /api/batch-costing
// @access  Private
router.get('/', protect, superAdmin, async (req, res) => {
  try {
    const costings = await BatchCosting.find().sort({ createdAt: -1 });
    res.json({ success: true, count: costings.length, data: costings });
  } catch (error) {
    console.error('Error fetching batch costings:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

module.exports = router;
