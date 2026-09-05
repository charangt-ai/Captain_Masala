const mongoose = require('mongoose');
const dotenv = require('dotenv');
const User = require('./models/User');
const Product = require('./models/Product');
const ProductCategory = require('./models/Category');
const MasterProduct = require('./models/MasterProduct');
const Customer = require('./models/Customer');
const Sale = require('./models/Sale');
const InventoryLog = require('./models/InventoryLog');

dotenv.config();

async function inspectMongo() {
  await mongoose.connect(process.env.MONGODB_URI);
  
  console.log('=== MONGODB DATA ===\n');
  
  console.log('--- Categories ---');
  const cats = await ProductCategory.find({});
  cats.forEach(c => console.log(`  ${c._id}: name="${c.name}", image=${c.image ? c.image.substring(0,50)+'...' : 'EMPTY'}`));
  
  console.log('\n--- Master Products ---');
  const mps = await MasterProduct.find({});
  console.log(`  Count: ${mps.length}`);
  mps.forEach(m => console.log(`  ${m._id}: name="${m.name}", totalStockKg=${m.totalStockKg}`));
  
  console.log('\n--- Products (first 5) ---');
  const prods = await Product.find({}).limit(5);
  prods.forEach(p => console.log(`  ${p._id}: name="${p.name}", packSize="${p.packSize}", categoryId="${p.categoryId}", masterProductId="${p.masterProductId}", stock=${p.remainingStock}`));

  console.log('\n--- Sales (first 3) ---');
  const sales = await Sale.find({}).limit(3);
  sales.forEach(s => console.log(`  ${s._id}: inv="${s.invoiceNumber}", customer="${s.customerName}", items=${s.items?.length}, total=${s.totalAmount}, status="${s.status}"`));

  console.log('\n--- Users ---');
  const users = await User.find({});
  users.forEach(u => console.log(`  ${u._id}: name="${u.name}", username="${u.username}", role="${u.role}"`));

  console.log('\n--- Inventory Logs (first 3) ---');
  const logs = await InventoryLog.find({}).limit(3);
  logs.forEach(l => console.log(`  ${l._id}: product="${l.productName}", qty=${l.changeQuantity}, type="${l.type}"`));

  process.exit(0);
}

inspectMongo();
