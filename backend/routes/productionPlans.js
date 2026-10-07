const express = require('express');
const router = express.Router();
const { protect, superAdmin } = require('../middleware/auth');
const ProductionPlan = require('../models/ProductionPlan');
const Recipe = require('../models/Recipe');
const MasterProduct = require('../models/MasterProduct');
const RawMaterial = require('../models/RawMaterial');

// @desc    Create a new production plan
// @route   POST /api/production-plans
// @access  Private
router.post('/', protect, superAdmin, async (req, res) => {
  try {
    const { masterProductId, plannedBatchSize, plannedDate, priority, notes } = req.body;

    const masterProduct = await MasterProduct.findById(masterProductId);
    if (!masterProduct) {
      return res.status(404).json({ success: false, message: 'Master Product not found' });
    }

    const recipe = await Recipe.findOne({ productId: masterProductId }).populate('ingredients.rawMaterialId');
    if (!recipe) {
      return res.status(404).json({ success: false, message: 'Recipe not found for this product' });
    }

    // Generate Plan Number
    const count = await ProductionPlan.countDocuments();
    const planNumber = `PP-${new Date().getFullYear()}-${(count + 1).toString().padStart(3, '0')}`;

    const plannedIngredients = [];
    for (let ingredient of recipe.ingredients) {
      const requiredQty = (ingredient.requiredQuantity / recipe.baseBatchSize) * plannedBatchSize;
      const rawMaterial = ingredient.rawMaterialId;
      
      if (!rawMaterial) {
        return res.status(400).json({ success: false, message: 'One of the ingredients in this recipe no longer exists in the raw materials database. Please update the recipe.' });
      }

      const availableStock = rawMaterial.currentStock || 0;
      
      plannedIngredients.push({
        rawMaterialId: rawMaterial._id,
        rawMaterialName: rawMaterial.name,
        requiredQuantity: requiredQty,
        availableStock: availableStock,
        isSufficient: availableStock >= requiredQty
      });
    }

    const plan = new ProductionPlan({
      planNumber,
      masterProductId,
      masterProductName: masterProduct.name,
      recipeId: recipe._id,
      plannedBatchSize,
      plannedIngredients,
      plannedDate,
      priority,
      notes,
      createdById: req.user._id,
      createdByName: req.user.name || req.user.email
    });

    await plan.save();
    res.status(201).json({ success: true, data: plan });
  } catch (error) {
    console.error('Error creating production plan:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @desc    Get all production plans
// @route   GET /api/production-plans
// @access  Private
router.get('/', protect, superAdmin, async (req, res) => {
  try {
    const query = {};
    if (req.query.status) query.status = req.query.status;
    
    const plans = await ProductionPlan.find(query).sort({ createdAt: -1 });
    res.json({ success: true, count: plans.length, data: plans });
  } catch (error) {
    console.error('Error fetching production plans:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @desc    Get single production plan
// @route   GET /api/production-plans/:id
// @access  Private
router.get('/:id', protect, superAdmin, async (req, res) => {
  try {
    const plan = await ProductionPlan.findById(req.params.id);
    if (!plan) return res.status(404).json({ success: false, message: 'Plan not found' });
    res.json({ success: true, data: plan });
  } catch (error) {
    console.error('Error fetching production plan:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @desc    Approve a production plan
// @route   POST /api/production-plans/:id/approve
// @access  Private (Manager only)
router.post('/:id/approve', protect, superAdmin, async (req, res) => {
  try {
    const plan = await ProductionPlan.findById(req.params.id);
    if (!plan) return res.status(404).json({ success: false, message: 'Plan not found' });
    
    if (plan.status !== 'DRAFT' && plan.status !== 'AWAITING_APPROVAL') {
      return res.status(400).json({ success: false, message: `Cannot approve plan in status: ${plan.status}` });
    }

    plan.status = 'APPROVED';
    plan.approvedById = req.user._id;
    plan.approvedByName = req.user.name || req.user.email;
    plan.approvedAt = Date.now();
    await plan.save();

    res.json({ success: true, data: plan });
  } catch (error) {
    console.error('Error approving production plan:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @desc    Update a production plan
// @route   PUT /api/production-plans/:id
// @access  Private
router.put('/:id', protect, superAdmin, async (req, res) => {
  try {
    const { plannedBatchSize, plannedDate, priority, notes } = req.body;
    let plan = await ProductionPlan.findById(req.params.id);
    
    if (!plan) {
      return res.status(404).json({ success: false, message: 'Plan not found' });
    }

    if (req.body.status) {
      plan.status = req.body.status;
      await plan.save();
      return res.json({ success: true, data: plan });
    }

    if (plan.status !== 'DRAFT') {
      return res.status(400).json({ success: false, message: 'Only DRAFT plans can be edited' });
    }

    const recipe = await Recipe.findById(plan.recipeId).populate('ingredients.rawMaterialId');
    if (!recipe) {
      return res.status(404).json({ success: false, message: 'Recipe not found for this product' });
    }

    const plannedIngredients = [];
    for (let ingredient of recipe.ingredients) {
      const requiredQty = (ingredient.requiredQuantity / recipe.baseBatchSize) * plannedBatchSize;
      const rawMaterial = ingredient.rawMaterialId;
      
      if (!rawMaterial) {
        return res.status(400).json({ success: false, message: 'One of the ingredients in this recipe no longer exists.' });
      }

      const availableStock = rawMaterial.currentStock || 0;
      plannedIngredients.push({
        rawMaterialId: rawMaterial._id,
        rawMaterialName: rawMaterial.name,
        requiredQuantity: requiredQty,
        availableStock: availableStock,
        isSufficient: availableStock >= requiredQty
      });
    }

    plan.plannedBatchSize = plannedBatchSize;
    if (plannedDate !== undefined) plan.plannedDate = plannedDate;
    if (priority !== undefined) plan.priority = priority;
    if (notes !== undefined) plan.notes = notes;
    plan.plannedIngredients = plannedIngredients;

    await plan.save();
    res.json({ success: true, data: plan });
  } catch (error) {
    console.error('Error updating production plan:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @desc    Delete a production plan
// @route   DELETE /api/production-plans/:id
// @access  Private
router.delete('/:id', protect, superAdmin, async (req, res) => {
  try {
    const plan = await ProductionPlan.findById(req.params.id);
    if (!plan) return res.status(404).json({ success: false, message: 'Plan not found' });
    
    if (plan.status !== 'DRAFT') {
      return res.status(400).json({ success: false, message: 'Only DRAFT plans can be deleted' });
    }

    await plan.deleteOne();
    res.json({ success: true, message: 'Plan deleted' });
  } catch (error) {
    console.error('Error deleting production plan:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

module.exports = router;
