const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const connectDB = require('./config/db');

// Load env vars
dotenv.config();

// Connect to database
connectDB();

const app = express();

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' })); // For base64 images

// Route files
const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const productRoutes = require('./routes/products');
const masterProductRoutes = require('./routes/masterProducts');
const categoryRoutes = require('./routes/categories');
const customerRoutes = require('./routes/customers');
const saleRoutes = require('./routes/sales');
const inventoryRoutes = require('./routes/inventory');
const manufacturingRoutes = require('./routes/manufacturing');
const rawMaterialRoutes = require('./routes/rawMaterials');
const recipeRoutes = require('./routes/recipes');
const productionPlanRoutes = require('./routes/productionPlans');
const materialIssueRoutes = require('./routes/materialIssues');
const qualityControlRoutes = require('./routes/qualityControl');
const finishedGoodsRoutes = require('./routes/finishedGoods');
const batchCostingRoutes = require('./routes/batchCosting');
const { setupCronJobs } = require('./cron/scheduler');

// Mount routers
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/products', productRoutes);
app.use('/api/master-products', masterProductRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/api/customers', customerRoutes);
app.use('/api/sales', saleRoutes);
app.use('/api/inventory-logs', inventoryRoutes);
app.use('/api/manufacturing', manufacturingRoutes);
app.use('/api/inventory/raw-materials', rawMaterialRoutes);
app.use('/api/recipes', recipeRoutes);
app.use('/api/production-plans', productionPlanRoutes);
app.use('/api/material-issues', materialIssueRoutes);
app.use('/api/quality-control', qualityControlRoutes);
app.use('/api/finished-goods', finishedGoodsRoutes);
app.use('/api/batch-costing', batchCostingRoutes);

// Initialize Cron Jobs
setupCronJobs();

app.get('/', (req, res) => {
  res.send('Captain Masala API is running');
});

const PORT = process.env.PORT || 3000;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});
