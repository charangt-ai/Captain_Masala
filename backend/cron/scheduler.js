const cron = require('node-cron');
const RawMaterial = require('../models/RawMaterial');
const FinishedGoodsBatch = require('../models/FinishedGoodsBatch');
const StockAlert = require('../models/StockAlert');
const DailyStockValuation = require('../models/DailyStockValuation');
const PackagingMaterial = require('../models/PackagingMaterial');

const setupCronJobs = () => {
  // 1. Low Stock Alerts (Runs every 6 hours)
  cron.schedule('0 */6 * * *', async () => {
    console.log('Running Low Stock Alert Cron Job...');
    try {
      // Raw Materials
      const rawMaterials = await RawMaterial.find();
      for (let rm of rawMaterials) {
        if (rm.currentStock <= rm.minimumStockLevel) {
          await createOrUpdateAlert(
            'LOW_STOCK', 'RAW_MATERIAL', rm._id, rm.name, rm.currentStock, rm.minimumStockLevel
          );
        }
      }
      
      // Packaging Materials
      const packagingMaterials = await PackagingMaterial.find();
      for (let pm of packagingMaterials) {
        if (pm.currentStock <= pm.minimumStockLevel) {
          await createOrUpdateAlert(
            'LOW_STOCK', 'PACKAGING_MATERIAL', pm._id, pm.name, pm.currentStock, pm.minimumStockLevel
          );
        }
      }
    } catch (error) {
      console.error('Error in Low Stock Cron:', error);
    }
  });

  // 2. Expiry Alerts (Runs daily at 6 AM)
  cron.schedule('0 6 * * *', async () => {
    console.log('Running Expiry Alert Cron Job...');
    try {
      const thirtyDaysFromNow = new Date();
      thirtyDaysFromNow.setDate(thirtyDaysFromNow.getDate() + 30);

      const batches = await FinishedGoodsBatch.find({ status: 'ACTIVE' });
      for (let batch of batches) {
        if (batch.expiryDate < new Date()) {
          batch.status = 'EXPIRED';
          await batch.save();
          await createOrUpdateAlert(
            'EXPIRED', 'FINISHED_GOODS', batch._id, batch.masterProductName, 0, 0, batch.batchNumber, batch.expiryDate
          );
        } else if (batch.expiryDate <= thirtyDaysFromNow) {
          const daysToExpiry = Math.ceil((batch.expiryDate - new Date()) / (1000 * 60 * 60 * 24));
          await createOrUpdateAlert(
            'EXPIRY_WARNING', 'FINISHED_GOODS', batch._id, batch.masterProductName, daysToExpiry, 30, batch.batchNumber, batch.expiryDate
          );
        }
      }
    } catch (error) {
      console.error('Error in Expiry Alert Cron:', error);
    }
  });

  // 3. Daily Stock Valuation (Runs daily at 11:55 PM)
  cron.schedule('55 23 * * *', async () => {
    console.log('Running Daily Stock Valuation Cron Job...');
    try {
      // Calculate Raw Material Value
      const rawMaterials = await RawMaterial.find();
      let rmTotalQty = 0;
      let rmTotalValue = 0;
      const rmItems = rawMaterials.map(rm => {
        rmTotalQty += rm.currentStock;
        const val = rm.currentStock * rm.costPerUnit;
        rmTotalValue += val;
        return { itemId: rm._id, itemName: rm.name, quantity: rm.currentStock, unitCost: rm.costPerUnit, totalValue: val };
      });

      // Calculate Finished Goods Value
      const fgBatches = await FinishedGoodsBatch.find({ status: 'ACTIVE' });
      let fgTotalQty = 0;
      let fgTotalValue = 0;
      const fgItems = fgBatches.map(fg => {
        fgTotalQty += fg.currentQuantity;
        const val = fg.currentQuantity * fg.costPerKg;
        fgTotalValue += val;
        return { itemId: fg._id, itemName: fg.masterProductName, batchNumber: fg.batchNumber, quantity: fg.currentQuantity, costPerKg: fg.costPerKg, totalValue: val };
      });

      const today = new Date();
      today.setHours(0,0,0,0);

      const valuation = new DailyStockValuation({
        date: today,
        valuationMethod: 'AVERAGE',
        rawMaterials: { totalQuantity: rmTotalQty, totalValue: rmTotalValue, items: rmItems },
        finishedGoods: { totalQuantity: fgTotalQty, totalValue: fgTotalValue, items: fgItems },
        grandTotal: rmTotalValue + fgTotalValue
      });

      await DailyStockValuation.findOneAndUpdate(
        { date: today },
        valuation,
        { upsert: true, new: true, setDefaultsOnInsert: true }
      );

    } catch (error) {
      console.error('Error in Daily Stock Valuation Cron:', error);
    }
  });
};

const createOrUpdateAlert = async (alertType, itemType, itemId, itemName, currentValue, thresholdValue, batchNumber = null, expiryDate = null) => {
  const existing = await StockAlert.findOne({ alertType, itemId, batchNumber, isResolved: false });
  if (existing) {
    existing.currentValue = currentValue;
    await existing.save();
  } else {
    await StockAlert.create({ alertType, itemType, itemId, itemName, currentValue, thresholdValue, batchNumber, expiryDate });
  }
};

module.exports = { setupCronJobs };
