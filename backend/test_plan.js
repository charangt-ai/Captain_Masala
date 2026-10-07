const mongoose = require('mongoose');
const ProductionPlan = require('./models/ProductionPlan');
const Recipe = require('./models/Recipe');
const MasterProduct = require('./models/MasterProduct');
const RawMaterial = require('./models/RawMaterial');

const MONGO_URI = 'mongodb+srv://chara:chara%40123@cluster0.n1q1l.mongodb.net/captain_masala?retryWrites=true&w=majority&appName=Cluster0';

async function test() {
  await mongoose.connect(MONGO_URI);
  console.log('Connected');
  
  // Find a product
  const masterProduct = await MasterProduct.findOne();
  if (!masterProduct) return console.log('No product');
  console.log('Product:', masterProduct.name, masterProduct._id);

  // Check recipe
  let recipe = await Recipe.findOne({ productId: masterProduct._id }).populate('ingredients.rawMaterialId');
  if (!recipe) {
      console.log('No recipe found, creating one...');
      const rm = await RawMaterial.findOne();
      if (!rm) return console.log('No RM');
      recipe = new Recipe({
          productId: masterProduct._id,
          baseBatchSize: 100,
          type: 'MULTI_INGREDIENT',
          ingredients: [{ rawMaterialId: rm._id, requiredQuantity: 50 }]
      });
      await recipe.save();
      recipe = await Recipe.findOne({ productId: masterProduct._id }).populate('ingredients.rawMaterialId');
  }
  console.log('Recipe:', recipe._id);

  try {
    const plannedBatchSize = 100;
    const count = await ProductionPlan.countDocuments();
    const planNumber = `PP-2026-${(count + 1).toString().padStart(3, '0')}`;

    const plannedIngredients = [];
    for (let ingredient of recipe.ingredients) {
      const requiredQty = (ingredient.requiredQuantity / recipe.baseBatchSize) * plannedBatchSize;
      const rawMaterial = ingredient.rawMaterialId;
      const availableStock = rawMaterial ? rawMaterial.currentStock : 0;
      
      plannedIngredients.push({
        rawMaterialId: rawMaterial ? rawMaterial._id : null,
        rawMaterialName: rawMaterial ? rawMaterial.name : 'Unknown',
        requiredQuantity: requiredQty,
        availableStock: availableStock,
        isSufficient: availableStock >= requiredQty
      });
    }

    const plan = new ProductionPlan({
      planNumber,
      masterProductId: masterProduct._id,
      masterProductName: masterProduct.name,
      recipeId: recipe._id,
      plannedBatchSize,
      plannedIngredients,
      plannedDate: new Date(),
      priority: 'MEDIUM',
      notes: 'test',
      createdById: masterProduct._id, // mock user
      createdByName: 'Test User'
    });

    await plan.save();
    console.log('Plan created:', plan._id);
  } catch (error) {
    console.error('CRASH:', error);
  }

  process.exit(0);
}

test();
