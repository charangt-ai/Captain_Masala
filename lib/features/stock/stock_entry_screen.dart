import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/services/database_service.dart';
import '../../core/theme.dart';
import '../../core/models/master_product.dart';

class StockEntryScreen extends StatefulWidget {
  const StockEntryScreen({Key? key}) : super(key: key);

  @override
  State<StockEntryScreen> createState() => _StockEntryScreenState();
}

class _StockEntryScreenState extends State<StockEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  MasterProduct? _selectedProduct;
  final _stockController = TextEditingController();
  final _notesController = TextEditingController(text: 'Monthly Opening Stock Entry');

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final activeProducts = db.masterProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Stock Entry'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions Alert
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryRed.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primaryRed),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Use this screen to enter stock at the beginning of the month. This updates current stock and creates an audit log.',
                      style: TextStyle(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Form card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Product Dropdown Selection
                      DropdownButtonFormField<MasterProduct>(
                        value: _selectedProduct,
                        decoration: const InputDecoration(
                          labelText: 'Select Product',
                          prefixIcon: Icon(Icons.shopping_basket),
                        ),
                        items: activeProducts.map((p) {
                            return DropdownMenuItem<MasterProduct>(
                              value: p,
                              child: Text('${p.name} (${p.totalStockKg.toStringAsFixed(1)} kg current)'),
                            );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedProduct = val;
                            if (val != null) {
                              _stockController.text = val.totalStockKg.toString();
                            }
                          });
                        },
                        validator: (value) => value == null ? 'Please select a product' : null,
                      ),
                      const SizedBox(height: 16),

                      // Opening Stock input
                      TextFormField(
                        controller: _stockController,
                        decoration: const InputDecoration(
                          labelText: 'New Stock Level (kg)',
                          prefixIcon: Icon(Icons.scale),
                          suffixText: 'kg',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter stock quantity';
                          }
                          if (double.tryParse(value) == null || double.parse(value) < 0) {
                            return 'Enter a valid positive number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Notes input
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Stock Log Notes',
                          prefixIcon: Icon(Icons.notes),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: () async {
                          if (!_formKey.currentState!.validate() || _selectedProduct == null) return;

                          final newStock = double.parse(_stockController.text);
                          
                          // Show loading indicator or disable button if needed in a real app, 
                          // but for simplicity we'll just await the result here.
                          final success = await db.updateMasterStock(
                            _selectedProduct!.id,
                            newStock,
                            _notesController.text.trim(),
                          );

                          if (!mounted) return;

                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Stock level updated successfully!'),
                                backgroundColor: AppColors.primaryGreen,
                              ),
                            );
                            Navigator.of(context).pop();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to update stock. Please check your connection and try again.'),
                                backgroundColor: AppColors.primaryRed,
                              ),
                            );
                          }
                        },
                        child: const Text('Save Stock Level'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Stock log list
            const Text(
              'Recent Inventory Logs',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const SizedBox(height: 8),
            db.inventoryLogs.isEmpty
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No inventory records found')),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: db.inventoryLogs.length > 8 ? 8 : db.inventoryLogs.length,
                    itemBuilder: (ctx, index) {
                      final log = db.inventoryLogs[index];
                      final isAddition = log.changeQuantity > 0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isAddition
                                ? AppColors.primaryGreen.withOpacity(0.1)
                                : AppColors.primaryRed.withOpacity(0.1),
                            child: Icon(
                              isAddition ? Icons.add_circle : Icons.remove_circle,
                              color: isAddition ? AppColors.primaryGreen : AppColors.primaryRed,
                            ),
                          ),
                          title: Text(log.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${log.type} • ${log.notes}\n${DateFormat('dd MMM yy, hh:mm a').format(log.dateTime)}'),
                          isThreeLine: true,
                          trailing: Text(
                            '${isAddition ? "+" : ""}${log.changeQuantity.toStringAsFixed(1)} kg',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isAddition ? AppColors.primaryGreen : AppColors.primaryRed,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stockController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
