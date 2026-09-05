const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const mongoose = require('mongoose');
const dotenv = require('dotenv');
const serviceAccount = require('./firebase-service-account.json');

// Models
const User = require('./models/User');
const Product = require('./models/Product');
const ProductCategory = require('./models/Category');
const MasterProduct = require('./models/MasterProduct');
const Customer = require('./models/Customer');
const Sale = require('./models/Sale');
const InventoryLog = require('./models/InventoryLog');

dotenv.config();

// Initialize Firebase
initializeApp({
  credential: cert(serviceAccount)
});
const db = getFirestore();

function parseDate(value) {
  if (!value) return new Date();
  if (value.toDate) return value.toDate(); // Firestore Timestamp
  if (typeof value === 'string') return new Date(value);
  return new Date();
}

async function migrateCollection(collectionName, Model, transformData) {
  console.log(`\nMigrating collection: "${collectionName}"...`);
  try {
    const snapshot = await db.collection(collectionName).get();
    
    if (snapshot.empty) {
      console.log(`  No documents found in "${collectionName}"`);
      return 0;
    }

    console.log(`  Found ${snapshot.size} documents. Inserting into MongoDB...`);
    
    // Clear existing data first for a clean migration
    await Model.deleteMany({});
    
    let successCount = 0;
    let errorCount = 0;
    
    for (const doc of snapshot.docs) {
      try {
        const data = doc.data();
        const transformed = transformData(data, doc.id);
        await Model.create(transformed);
        successCount++;
      } catch (err) {
        errorCount++;
        console.error(`  Error inserting "${doc.id}": ${err.message}`);
      }
    }
    
    console.log(`  ✓ Migrated ${successCount}/${snapshot.size} documents (${errorCount} errors)`);
    return successCount;
  } catch (error) {
    console.error(`  ✗ Failed to migrate "${collectionName}":`, error.message);
    return 0;
  }
}

async function runMigration() {
  try {
    console.log('Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('MongoDB Connected.\n');
    console.log('========================================');
    console.log('  FIREBASE → MONGODB FULL MIGRATION');
    console.log('========================================');

    // 1. Users
    await migrateCollection('users', User, (data, id) => ({
      _id: id,
      name: data.name || '',
      phoneNumber: data.phoneNumber || data.phone || '',
      email: data.email || `${id}@example.com`,
      username: data.username || id,
      password: data.password || 'migrated_user_password',
      role: data.role || 'pending',
      requestedRole: data.requestedRole || null,
    }));

    // 2. Categories (Firebase field: "image", MongoDB field: "image")
    await migrateCollection('categories', ProductCategory, (data, id) => ({
      _id: id,
      name: data.name,
      image: data.image || data.imageBase64 || data.imageUrl || '',
    }));

    // 3. Master Products — Firebase collection name is "master_products" (with underscore!)
    await migrateCollection('master_products', MasterProduct, (data, id) => ({
      _id: id,
      name: data.name,
      totalStockKg: data.totalStockKg || 0,
    }));

    // 4. Products
    await migrateCollection('products', Product, (data, id) => ({
      _id: id,
      name: data.name,
      packSize: data.packSize,
      wholesalePrice: data.wholesalePrice || 0,
      originalPrice: data.originalPrice || 0,
      remainingStock: data.remainingStock || 0,
      imageUrl: data.imageUrl || '',
      isEnabled: data.isEnabled === 1 || data.isEnabled === true,
      categoryId: data.categoryId || '',
      masterProductId: data.masterProductId || '',
    }));

    // 5. Customers (ALL fields from Firebase)
    await migrateCollection('customers', Customer, (data, id) => ({
      _id: id,
      name: data.name || '',
      shopName: data.shopName || '',
      ownerName: data.ownerName || '',
      mobileNumber: data.mobileNumber || data.phoneNumber || '',
      address: data.address || '',
      district: data.district || '',
      city: data.city || '',
      gstNumber: data.gstNumber || '',
      shopImageUrl: data.shopImageUrl || '',
      latitude: data.latitude || null,
      longitude: data.longitude || null,
      lastPurchaseDate: data.lastPurchaseDate ? parseDate(data.lastPurchaseDate) : null,
      totalSpent: data.totalSpent || 0,
      handledById: data.handledById || null,
      handledByName: data.handledByName || null,
    }));

    // 6. Sales (ALL fields from Firebase, correct field mapping)
    await migrateCollection('sales', Sale, (data, id) => ({
      _id: id,
      invoiceNumber: data.invoiceNumber || '',
      customerId: data.customerId || '',
      customerName: data.customerName || '',
      shopName: data.shopName || '',
      sellerId: data.sellerId || '',
      sellerName: data.sellerName || '',
      sellerRole: data.sellerRole || 'seller',
      items: (data.items || []).map(item => ({
        productId: item.productId || '',
        productName: item.productName || '',
        packSize: item.packSize || '',
        quantity: item.quantity || 0,
        rate: item.rate || 0,
        totalAmount: item.totalAmount || 0,
      })),
      totalAmount: data.totalAmount || 0,
      discount: data.discount || 0,
      finalAmount: data.finalAmount || 0,
      paymentStatus: data.paymentStatus || 'Pending',
      prepaidAmount: data.prepaidAmount || 0,
      deliveryStatus: data.deliveryStatus || 'Delivered',
      dateTime: parseDate(data.dateTime),
      phone: data.phone || '',
      status: data.status || 'Active',
      cancelReason: data.cancelReason || null,
      updatedAt: data.updatedAt ? parseDate(data.updatedAt) : null,
    }));

    // 7. Inventory Logs
    await migrateCollection('inventoryLogs', InventoryLog, (data, id) => ({
      _id: id,
      productId: data.productId || '',
      productName: data.productName || '',
      changeQuantity: data.changeQuantity || 0,
      type: data.type || 'Monthly Entry',
      dateTime: parseDate(data.dateTime),
      notes: data.notes || '',
    }));

    console.log('\n========================================');
    console.log('  MIGRATION COMPLETE!');
    console.log('========================================\n');
    
    // Verification counts
    console.log('--- Verification ---');
    console.log(`Users:           ${await User.countDocuments()}`);
    console.log(`Categories:      ${await ProductCategory.countDocuments()}`);
    console.log(`Master Products: ${await MasterProduct.countDocuments()}`);
    console.log(`Products:        ${await Product.countDocuments()}`);
    console.log(`Customers:       ${await Customer.countDocuments()}`);
    console.log(`Sales:           ${await Sale.countDocuments()}`);
    console.log(`Inventory Logs:  ${await InventoryLog.countDocuments()}`);
    
    process.exit(0);
  } catch (error) {
    console.error('Migration failed:', error);
    process.exit(1);
  }
}

runMigration();
