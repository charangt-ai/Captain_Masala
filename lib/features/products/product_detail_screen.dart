import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/models/product.dart';
import '../../core/models/sale.dart';
import '../../core/services/database_service.dart';
import '../../core/theme.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final int initialTabIndex;

  const ProductDetailScreen({
    Key? key,
    required this.product,
    this.initialTabIndex = 0,
  }) : super(key: key);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _nameController;
  late TextEditingController _packSizeController;
  late TextEditingController _priceController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _nameController = TextEditingController(text: widget.product.name);
    _packSizeController = TextEditingController(text: widget.product.packSize);
    _priceController = TextEditingController(text: widget.product.wholesalePrice.toString());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _packSizeController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _saveProduct() {
    if (!_formKey.currentState!.validate()) return;

    final db = Provider.of<DatabaseService>(context, listen: false);
    final updated = Product(
      id: widget.product.id,
      name: widget.product.name, // Usually disabled for defaults, but leaving it as in the dialog
      packSize: _packSizeController.text.trim(),
      wholesalePrice: double.parse(_priceController.text),
      remainingStock: widget.product.remainingStock,
      isEnabled: widget.product.isEnabled,
      imageUrl: widget.product.imageUrl,
      masterProductId: widget.product.masterProductId,
      categoryId: widget.product.categoryId,
    );
    
    db.updateProduct(updated);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Product updated successfully!'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
    Navigator.of(context).pop();
  }

  Widget _buildHistoryTab(BuildContext context) {
    return Consumer<DatabaseService>(
      builder: (context, db, child) {
        // 1. Fetch Monthly Stock Entries
        final stockLogs = db.inventoryLogs.where((log) => 
            log.productId == widget.product.id && (log.type == 'Monthly Entry' || log.changeQuantity > 0)
        ).toList();
        stockLogs.sort((a, b) => b.dateTime.compareTo(a.dateTime));

        // 2. Fetch Sale Deductions
        final relevantSales = db.sales.where((sale) {
          return sale.items.any((item) => item.productId == widget.product.id);
        }).toList();
        relevantSales.sort((a, b) => b.dateTime.compareTo(a.dateTime));

        final dateFormat = DateFormat('MMM dd, yyyy - hh:mm a');
        final monthFormat = DateFormat('MMMM');
        final exactDateFormat = DateFormat('dd MMMM yyyy');

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- MONTHLY STOCK SECTION ---
            const Text(
              'Initial Monthly Stock',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (stockLogs.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, color: Colors.grey.shade500),
                    const SizedBox(width: 12),
                    Text(
                      'No monthly stock data available.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              )
            else
              ...stockLogs.map((log) {
                return Card(
                  elevation: 0,
                  color: AppColors.primaryGreen.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
                  ),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${monthFormat.format(log.dateTime)} Month Stock',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Added on: ${exactDateFormat.format(log.dateTime)}',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                            ),
                          ],
                        ),
                        Text(
                          '${log.changeQuantity.toStringAsFixed(1)} kg',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            
            const SizedBox(height: 24),
            
            // --- SALE DEDUCTIONS SECTION ---
            const Text(
              'Sale Deductions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (relevantSales.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(Icons.history_toggle_off, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'No sale deductions found.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...relevantSales.map((sale) {
                final saleItem = sale.items.firstWhere((item) => item.productId == widget.product.id);
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.outbox, color: AppColors.primaryRed),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sale.shopName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Invoice: ${sale.invoiceNumber}',
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dateFormat.format(sale.dateTime),
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '-${saleItem.quantity.toStringAsFixed(1)} kg',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.primaryRed,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${saleItem.totalAmount.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildEditTab(BuildContext context) {
    // Disable name editing for default products 1-8 like the original code
    final isDefaultProduct = ['1', '2', '3', '4', '5', '6', '7', '8'].contains(widget.product.id);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name',
                        prefixIcon: Icon(Icons.inventory_2),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter product name' : null,
                      enabled: !isDefaultProduct,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _packSizeController,
                      decoration: const InputDecoration(
                        labelText: 'Pack Size (e.g., 500 g, 1 kg)',
                        prefixIcon: Icon(Icons.straighten),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter pack size' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Wholesale Price (₹)',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) {
                        if (val == null || double.tryParse(val) == null) {
                          return 'Enter a valid wholesale price';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _saveProduct,
              icon: const Icon(Icons.save),
              label: const Text('Save Changes'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.history), text: 'History'),
            Tab(icon: Icon(Icons.edit), text: 'Edit'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHistoryTab(context),
          _buildEditTab(context),
        ],
      ),
    );
  }
}
