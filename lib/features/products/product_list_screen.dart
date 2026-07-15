import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/models/product.dart';
import '../../core/models/master_product.dart';
import '../../core/models/product_category.dart';
import '../../core/services/database_service.dart';
import '../../core/theme.dart';
import 'product_detail_screen.dart';

class ProductListScreen extends StatelessWidget {
  final bool isEmbedded;

  const ProductListScreen({Key? key, this.isEmbedded = false}) : super(key: key);

  void _showAddEditProductDialog(BuildContext context, {Product? product, MasterProduct? parentMaster}) {
    final isEdit = product != null;
    final db = Provider.of<DatabaseService>(context, listen: false);
    final nameController = TextEditingController(text: product?.name ?? parentMaster?.name ?? '');
    final packSizeController = TextEditingController(text: product?.packSize ?? '500 g');
    final priceController = TextEditingController(text: product?.wholesalePrice.toString() ?? '');
    final originalPriceController = TextEditingController(text: product?.originalPrice.toString() ?? '');
    final stockController = TextEditingController(text: product?.remainingStock.toString() ?? '0.0');
    final formKey = GlobalKey<FormState>();

    // Category selection state
    ProductCategory? selectedCategory;
    if (isEdit && product.categoryId.isNotEmpty) {
      try {
        selectedCategory = db.categories.firstWhere((c) => c.id == product.categoryId);
      } catch (_) {
        selectedCategory = null;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Product Details' : (parentMaster != null ? 'Add Variant to ${parentMaster.name}' : 'Add New Product')),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Product Name'),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Enter product name' : null,
                        enabled: !isEdit && parentMaster == null, // Prevent modifying names when adding to a master product
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: packSizeController,
                        decoration: const InputDecoration(labelText: 'Pack Size (e.g., 500 g, 1 kg)'),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Enter pack size' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: priceController,
                        decoration: const InputDecoration(labelText: 'Wholesale Price (₹)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) {
                          if (val == null || double.tryParse(val) == null) {
                            return 'Enter a valid wholesale price';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: originalPriceController,
                        decoration: const InputDecoration(labelText: 'Original / MRP Price (₹)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ProductCategory>(
                        value: selectedCategory,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: db.categories.map((c) {
                          return DropdownMenuItem(value: c, child: Text(c.name));
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() => selectedCategory = val);
                        },
                        validator: (val) => val == null ? 'Please select a category' : null,
                      ),
                      if (!isEdit && parentMaster == null) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: stockController,
                          decoration: const InputDecoration(labelText: 'Initial Opening Stock (kg)'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (val) {
                            if (val == null || double.tryParse(val) == null) {
                              return 'Enter initial stock';
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    
                    final originalPrice = double.tryParse(originalPriceController.text) ?? 0.0;
                    if (isEdit) {
                      final updated = Product(
                        id: product.id,
                        name: nameController.text.trim(),
                        packSize: packSizeController.text,
                        wholesalePrice: double.parse(priceController.text),
                        originalPrice: originalPrice,
                        remainingStock: product.remainingStock,
                        isEnabled: product.isEnabled,
                        imageUrl: product.imageUrl,
                        masterProductId: product.masterProductId,
                        categoryId: selectedCategory?.id ?? product.categoryId,
                      );
                      db.updateProduct(updated);
                    } else {
                      // Generate masterProductId for new standalone products
                      String masterId = parentMaster?.id ?? '';
                      if (masterId.isEmpty) {
                        masterId = nameController.text.trim().toLowerCase().replaceAll(' ', '_');
                      }

                      final newProd = Product(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameController.text.trim() + (parentMaster != null ? ' ${packSizeController.text.trim()}' : ''),
                        packSize: packSizeController.text.trim(),
                        wholesalePrice: double.parse(priceController.text),
                        originalPrice: originalPrice,
                        remainingStock: parentMaster != null ? 0.0 : double.parse(stockController.text),
                        masterProductId: masterId,
                        categoryId: selectedCategory?.id ?? '',
                      );
                      db.addProduct(newProd);
                    }
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEdit ? 'Product updated successfully!' : 'Product added successfully!'),
                        backgroundColor: AppColors.primaryGreen,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final rupeeFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final isSuperAdmin = db.currentUserProfile?.role == 'super_admin';

    // Filter out any ghost master products that have no variants
    final validMasterProducts = db.masterProducts.where((m) {
      return db.products.any((p) => p.masterProductId == m.id);
    }).toList();

    Widget listBody = ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: validMasterProducts.length,
      itemBuilder: (ctx, idx) {
        final m = validMasterProducts[idx];
        final isLowStock = m.totalStockKg < 50.0;
        final isOutOfStock = m.totalStockKg <= 0;
        final variants = db.products.where((p) => p.masterProductId == m.id).toList();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: isOutOfStock ? AppColors.outOfStockAlert.withOpacity(0.1) : AppColors.primaryRed.withOpacity(0.1),
              child: Icon(
                Icons.inventory_2,
                color: isOutOfStock ? AppColors.outOfStockAlert : AppColors.primaryRed,
              ),
            ),
            title: InkWell(
              onLongPress: isSuperAdmin ? () {
                showModalBottomSheet(
                  context: context,
                  builder: (ctx) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.add_box, color: AppColors.primaryGreen),
                          title: const Text('Add Variant to Master', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                          onTap: () {
                            Navigator.pop(ctx);
                            _showAddEditProductDialog(context, parentMaster: m);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.edit),
                          title: const Text('Edit Master Product'),
                          onTap: () {
                            Navigator.pop(ctx);
                            final nameController = TextEditingController(text: m.name);
                            final stockController = TextEditingController(text: m.totalStockKg.toString());
                            showDialog(
                              context: context,
                              builder: (dialogCtx) => AlertDialog(
                                title: const Text('Edit Master Product'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      controller: nameController,
                                      decoration: const InputDecoration(labelText: 'Name'),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: stockController,
                                      decoration: const InputDecoration(labelText: 'Total Stock (kg)'),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                                  ElevatedButton(
                                    onPressed: () {
                                      if (nameController.text.trim().isNotEmpty) {
                                        final updated = MasterProduct(
                                          id: m.id,
                                          name: nameController.text.trim(),
                                          totalStockKg: double.tryParse(stockController.text) ?? m.totalStockKg,
                                        );
                                        db.updateMasterProduct(updated);
                                        Navigator.pop(dialogCtx);
                                      }
                                    },
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.delete, color: AppColors.outOfStockAlert),
                          title: const Text('Delete Master Product', style: TextStyle(color: AppColors.outOfStockAlert)),
                          onTap: () {
                            Navigator.pop(ctx);
                            showDialog(
                              context: context,
                              builder: (dialogCtx) => AlertDialog(
                                title: const Text('Delete Master Product'),
                                content: Text('Are you sure you want to delete ${m.name} and ALL its variants? This action cannot be undone.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.outOfStockAlert),
                                    onPressed: () {
                                      db.deleteMasterProduct(m.id);
                                      Navigator.pop(dialogCtx);
                                    },
                                    child: const Text('Delete All'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              } : null,
              child: Text(
                m.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            subtitle: Text('${variants.length} variant(s)'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${m.totalStockKg.toStringAsFixed(1)} kg',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isOutOfStock
                        ? AppColors.outOfStockAlert
                        : (isLowStock ? AppColors.lowStockAlert : AppColors.primaryGreen),
                  ),
                ),
                Text(
                  isOutOfStock ? 'Out of stock' : (isLowStock ? 'Low stock' : 'In stock'),
                  style: TextStyle(
                    fontSize: 10,
                    color: isOutOfStock
                        ? AppColors.outOfStockAlert
                        : (isLowStock ? AppColors.lowStockAlert : AppColors.primaryGreen),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            children: variants.map((p) {
              return ListTile(
                onLongPress: isSuperAdmin ? () {
                  showModalBottomSheet(
                    context: context,
                    builder: (ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.edit),
                            title: const Text('Edit Variant'),
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ProductDetailScreen(product: p, initialTabIndex: 1),
                                ),
                              );
                            },
                          ),
                          if (p.id != '1' && p.id != '2' && p.id != '3' && p.id != '4' && p.id != '5' && p.id != '6' && p.id != '7' && p.id != '8')
                            ListTile(
                              leading: const Icon(Icons.delete, color: AppColors.outOfStockAlert),
                              title: const Text('Delete Variant', style: TextStyle(color: AppColors.outOfStockAlert)),
                              onTap: () {
                                Navigator.pop(ctx);
                                showDialog(
                                  context: context,
                                  builder: (dialogCtx) => AlertDialog(
                                    title: const Text('Delete Variant'),
                                    content: Text('Are you sure you want to delete ${p.packSize}?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Cancel')),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.outOfStockAlert),
                                        onPressed: () {
                                          db.deleteProduct(p.id);
                                          Navigator.of(dialogCtx).pop();
                                        },
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  );
                } : null,
                title: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(product: p),
                      ),
                    );
                  },
                  child: Text(
                    'Pack: ${p.packSize}',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      decoration: p.isEnabled ? TextDecoration.underline : TextDecoration.lineThrough,
                    ),
                  ),
                ),
                subtitle: Text('Price: ${rupeeFormat.format(p.wholesalePrice)}'),
                trailing: isSuperAdmin ? Switch(
                  value: p.isEnabled,
                  onChanged: (val) {
                    final updated = Product(
                      id: p.id,
                      name: p.name,
                      packSize: p.packSize,
                      wholesalePrice: p.wholesalePrice,
                      remainingStock: p.remainingStock,
                      isEnabled: val,
                      imageUrl: p.imageUrl,
                      masterProductId: p.masterProductId,
                      categoryId: p.categoryId,
                    );
                    db.updateProduct(updated);
                  },
                  activeColor: AppColors.primaryGreen,
                ) : null,
              );
            }).toList(),
          ),
        );
      },
    );

    if (isEmbedded) {
      return Scaffold(
        body: listBody,
        floatingActionButton: isSuperAdmin ? FloatingActionButton(
          onPressed: () => _showAddEditProductDialog(context),
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
        ) : null,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Catalog'),
      ),
      body: listBody,
      floatingActionButton: isSuperAdmin ? FloatingActionButton(
        onPressed: () => _showAddEditProductDialog(context),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ) : null,
    );
  }
}
