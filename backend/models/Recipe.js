const mongoose = require('mongoose');

const RecipeSchema = new mongoose.Schema({
  productId: {
    type: String,
    ref: 'MasterProduct',
    required: true,
  },
  baseBatchSize: {
    type: Number,
    required: true, // e.g., 100 kg
  },
  type: {
    type: String,
    enum: ['SINGLE_INGREDIENT', 'MULTI_INGREDIENT'],
    default: 'MULTI_INGREDIENT'
  },
  ingredients: [{
    rawMaterialId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'RawMaterial',
      required: true
    },
    requiredQuantity: {
      type: Number,
      required: true // Quantity required for the baseBatchSize
    }
  }],
  createdAt: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('Recipe', RecipeSchema);
