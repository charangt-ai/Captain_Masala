const mongoose = require('mongoose');
require('dotenv').config();

const ProductionPlan = require('./models/ProductionPlan');
const FinishedGoodsBatch = require('./models/FinishedGoodsBatch');
const MasterProduct = require('./models/MasterProduct');
const QualityControl = require('./models/QualityControl');
const InventoryLog = require('./models/InventoryLog');

mongoose.connect(process.env.MONGODB_URI || 'mongodb+srv://charan:Charan%40007@cluster0.kl7xj4d.mongodb.net/captain_masala?retryWrites=true&w=majority&appName=Cluster0')
  .then(async () => {
    console.log('Connected to MongoDB for Migration...');
    
    // Find all plans that passed QC but don't have a Finished Goods batch
    const strandedPlans = await ProductionPlan.find({ status: { $in: ['QC_PASSED', 'COMPLETED'] } });
    
    let fixedCount = 0;

    for (let plan of strandedPlans) {
      const existingFg = await FinishedGoodsBatch.findOne({ productionPlanId: plan._id });
      
      if (!existingFg) {
        console.log(`Fixing missing FG Batch for Plan: ${plan.planNumber}`);
        
        const masterProduct = await MasterProduct.findById(plan.masterProductId);
        if (!masterProduct) continue;

        const qc = await QualityControl.findOne({ productionPlanId: plan._id });
        const batchWeight = qc ? qc.batchWeight : plan.plannedBatchSize;

        const fgCount = await FinishedGoodsBatch.countDocuments();
        const fgBatchNumber = `FG-CM-${new Date().getFullYear()}-${(fgCount + 1).toString().padStart(4, '0')}`;

        const fgBatch = new FinishedGoodsBatch({
          batchNumber: fgBatchNumber,
          masterProductId: plan.masterProductId,
          masterProductName: plan.masterProductName,
          productionPlanId: plan._id,
          manufacturingBatchId: plan.manufacturingBatchId,
          qcId: qc ? qc._id : null,
          initialQuantity: batchWeight,
          currentQuantity: batchWeight,
          manufacturingDate: new Date(),
          expiryDate: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000)
        });
        await fgBatch.save();

        masterProduct.totalStockKg += batchWeight;
        await masterProduct.save();

        plan.status = 'COMPLETED';
        await plan.save();

        fixedCount++;
      }
    }
    
    console.log(`Migration Complete! Successfully generated ${fixedCount} missing Finished Goods Batches.`);
    process.exit(0);
  })
  .catch(err => {
    console.error(err);
    process.exit(1);
  });
