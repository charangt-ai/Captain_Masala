const mongoose = require('mongoose');
const dotenv = require('dotenv');

// Models
const User = require('./models/User');
const Product = require('./models/Product');
const ProductCategory = require('./models/Category');
const MasterProduct = require('./models/MasterProduct');
const Customer = require('./models/Customer');
const Sale = require('./models/Sale');
const InventoryLog = require('./models/InventoryLog');

dotenv.config();

async function checkData() {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('--- Migration Verification Report ---');
    console.log(`Users (Accounts): ${await User.countDocuments()}`);
    console.log(`Categories: ${await ProductCategory.countDocuments()}`);
    console.log(`Master Products (Masala base items): ${await MasterProduct.countDocuments()}`);
    console.log(`Products (Specific Pack Sizes): ${await Product.countDocuments()}`);
    console.log(`Customers: ${await Customer.countDocuments()}`);
    console.log(`Sales/Invoices Generated: ${await Sale.countDocuments()}`);
    console.log(`Inventory Logs (Stock tracking): ${await InventoryLog.countDocuments()}`);
    console.log('---------------------------------------');
    process.exit(0);
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
}

checkData();
