const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const Recipe = require('../models/Recipe');
const MasterProduct = require('../models/MasterProduct');

// @desc    Get recipe by Product ID
// @route   GET /api/recipes/:productId
// @access  Private
router.get('/:productId', protect, async (req, res) => {
  try {
    const recipe = await Recipe.findOne({ productId: req.params.productId })
                               .populate('ingredients.rawMaterialId');
    if (!recipe) {
      return res.status(404).json({ success: false, message: 'Recipe not found for this product' });
    }
    res.json({ success: true, data: recipe });
  } catch (error) {
    console.error('Error fetching recipe:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @desc    Create or update a recipe
// @route   POST /api/recipes
// @access  Private
router.post('/', protect, async (req, res) => {
  try {
    const { productId, baseBatchSize, type, ingredients } = req.body;
    
    let recipe = await Recipe.findOne({ productId });
    
    if (recipe) {
      recipe.baseBatchSize = baseBatchSize;
      recipe.type = type;
      recipe.ingredients = ingredients;
      await recipe.save();
    } else {
      recipe = new Recipe({
        productId,
        baseBatchSize,
        type,
        ingredients
      });
      await recipe.save();
    }
    
    res.status(201).json({ success: true, data: recipe });
  } catch (error) {
    console.error('Error saving recipe:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

module.exports = router;
