import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/models/product.dart';
import '../../core/models/master_product.dart';
import '../../core/models/product_category.dart';
import '../../core/services/database_service.dart';
import '../../core/theme.dart';
import '../../core/permissions.dart';
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
                      // Stock is managed by production/ledger, so no initial stock input
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
                        remainingStock: 0.0, // Stock is driven by production/ledger
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

  double _getSizeInKg(String packSizeStr) {
    final lower = packSizeStr.toLowerCase().trim();

    // 1. Compound master bags like "50g-1kg", "50g - 1 kg bag", "50 gram - 1 kg bag"
    if (lower.contains('50') && (lower.contains('1kg') || lower.contains('1 kg') || lower.contains('bag'))) {
      return 1.0;
    }

    // 2. Explicit KG patterns (e.g. "1kg", "1 kg", "2.5 kg")
    final kgMatch = RegExp(r'([0-9.]+)\s*kg').firstMatch(lower);
    if (kgMatch != null) {
      return double.tryParse(kgMatch.group(1) ?? '') ?? 1.0;
    }

    // 3. Gram patterns (e.g. "500 g", "500g", "50 grams", "250gm")
    final gMatch = RegExp(r'([0-9.]+)\s*(?:grams|gram|gm|g)').firstMatch(lower);
    if (gMatch != null) {
      final grams = double.tryParse(gMatch.group(1) ?? '') ?? 0.0;
      return grams / 1000.0;
    }

    return 0.0;
  }

  void _showAllocatePacketsSheet(
    BuildContext context,
    MasterProduct m,
    List<Product> variants,
    DatabaseService db,
  ) {
    final Map<String, TextEditingController> controllers = {};
    for (var p in variants) {
      controllers[p.id] = TextEditingController();
    }

    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            double totalAllocatedKg = 0.0;
            int totalNewPackets = 0;
            final List<Map<String, dynamic>> activeAllocations = [];

            for (var p in variants) {
              final c = controllers[p.id];
              final val = double.tryParse(c?.text ?? '') ?? 0.0;
              final sizeInKg = _getSizeInKg(p.packSize);
              final pkts = sizeInKg > 0 ? (val / sizeInKg).floor() : 0;
              final actualKgUsed = pkts * sizeInKg;
              if (val > 0 && pkts > 0) {
                totalAllocatedKg += actualKgUsed;
                totalNewPackets += pkts;
                activeAllocations.add({
                  'productId': p.id,
                  'allocatedKg': actualKgUsed,
                  'packetCount': pkts,
                });
              }
            }

            final double remainingBulk = m.totalStockKg - totalAllocatedKg;
            final bool isOverAllocated = remainingBulk < -0.001;

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                top: 16,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.inventory_2_outlined, color: Colors.amber.shade800, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Allocate into Packets',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${m.name} | Available Bulk: ${m.totalStockKg.toStringAsFixed(1)} kg',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Stats Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('Available Bulk', '${m.totalStockKg.toStringAsFixed(1)} kg', Colors.black87),
                          Container(height: 30, width: 1, color: Colors.grey.shade300),
                          _buildStatItem('Allocating', '${totalAllocatedKg.toStringAsFixed(1)} kg', AppColors.primaryRed),
                          Container(height: 30, width: 1, color: Colors.grey.shade300),
                          _buildStatItem(
                            'Remaining',
                            '${remainingBulk.toStringAsFixed(1)} kg',
                            isOverAllocated ? Colors.red : Colors.green.shade700,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'ENTER WEIGHT PER VARIANT (KG):',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),

                    // Variant input rows
                    ...variants.map((p) {
                      final c = controllers[p.id]!;
                      final val = double.tryParse(c.text) ?? 0.0;
                      final sizeInKg = _getSizeInKg(p.packSize);
                      final pkts = sizeInKg > 0 ? (val / sizeInKg).floor() : 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        color: Colors.grey.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  p.packSize.toLowerCase().replaceAll(' ', '') == '50g-1kg' ? '50g (1kg Bag)' : p.packSize,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: c,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Bulk Weight',
                                    hintText: 'e.g. 10',
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    suffixText: 'kg',
                                    helperText: pkts > 0 ? '$pkts pkts' : null,
                                  ),
                                  onChanged: (_) => setSheetState(() {}),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Yield', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    Text(
                                      '$pkts pkts',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: pkts > 0 ? Colors.green.shade800 : Colors.grey,
                                      ),
                                    ),
                                    if (pkts > 0 && sizeInKg > 0)
                                      Text(
                                        '${(pkts * sizeInKg).toStringAsFixed(1)} kg used',
                                        style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    if (isOverAllocated)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '❌ INSUFFICIENT BULK QUANTITY. Please reduce weights.',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Submit Button
                    ElevatedButton.icon(
                      onPressed: (isSubmitting || isOverAllocated || totalAllocatedKg <= 0)
                          ? null
                          : () async {
                              setSheetState(() => isSubmitting = true);
                              final success = await db.allocateMasterProductToPackets(
                                m.id,
                                activeAllocations,
                              );
                              if (sheetCtx.mounted) {
                                Navigator.pop(sheetCtx);
                              }
                              if (context.mounted) {
                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.check_circle, color: Colors.white),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text('Successfully credited $totalNewPackets packets to ${m.name}!'),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: Colors.green,
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Failed to allocate packets. Check server logs.'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline, color: Colors.white),
                      label: Text(
                        isSubmitting
                            ? 'CREDITING STOCK...'
                            : 'APPROVE & CREDIT $totalNewPackets PACKETS',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final rupeeFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final isSuperAdmin = Permissions.isSuperAdmin(db.currentUserProfile?.role);

    // Filter out any ghost master products that have no variants
    final validMasterProducts = db.masterProducts.where((m) {
      return db.products.any((p) => p.masterProductId == m.id);
    }).toList();

    Widget listBody = ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: validMasterProducts.length,
      itemBuilder: (ctx, idx) {
        final m = validMasterProducts[idx];
        final variants = db.products.where((p) => p.masterProductId == m.id).toList();

        int totalPackets = 0;
        double totalPackedKg = 0.0;
        for (var p in variants) {
          final pkts = p.remainingStock.toInt();
          totalPackets += pkts;
          final sizeInKg = _getSizeInKg(p.packSize);
          totalPackedKg += pkts * sizeInKg;
        }

        final double totalBrandKg = m.totalStockKg + totalPackedKg;
        final bool isOutOfStock = totalBrandKg <= 0;
        final bool isLowStock = totalBrandKg > 0 && totalBrandKg < 50.0;
        final bool hasUnallocatedBulk = m.totalStockKg > 0;
        final bool noPacketsAllocated = totalPackets == 0;

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
                                    const Text('Stock must be adjusted via Inventory Logs or Production.', 
                                      style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
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
                                          totalStockKg: m.totalStockKg, // Preserve ledger value
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
            subtitle: Row(
              children: [
                Text('${variants.length} variant(s)'),
                if (totalPackets > 0) ...[
                  const Text(' • '),
                  Text(
                    '$totalPackets pkts ready',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ] else if (hasUnallocatedBulk) ...[
                  const Text(' • '),
                  Text(
                    'No packets ready',
                    style: TextStyle(
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${totalBrandKg.toStringAsFixed(1)} kg',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isOutOfStock
                        ? AppColors.outOfStockAlert
                        : (isLowStock ? AppColors.lowStockAlert : AppColors.primaryGreen),
                  ),
                ),
                Text(
                  isOutOfStock
                      ? 'Out of stock'
                      : (totalPackets > 0
                          ? '$totalPackets pkts ready'
                          : 'Bulk only'),
                  style: TextStyle(
                    fontSize: 10,
                    color: isOutOfStock
                        ? AppColors.outOfStockAlert
                        : (totalPackets > 0 ? AppColors.primaryGreen : Colors.amber.shade800),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            children: [
              // Summary 2-card row: Bulk Available vs Packed Packets
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    // Bulk Powder Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 14, color: Colors.amber.shade900),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'BULK POWDER',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                      color: Colors.amber.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${m.totalStockKg.toStringAsFixed(1)} kg',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              m.totalStockKg > 0 ? 'In storage drums' : 'No bulk powder',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Ready Packets Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.shopping_bag_outlined, size: 14, color: Colors.green.shade900),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'READY PACKETS',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                      color: Colors.green.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${totalPackedKg.toStringAsFixed(1)} kg',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade900,
                              ),
                            ),
                            Text(
                              '$totalPackets packets sealed',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Alert banner if no packets allocated yet
              if (noPacketsAllocated && hasUnallocatedBulk)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No retail packets allocated yet for this product. Use the button below to allocate available bulk stock into sellable packets.',
                          style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                ),

              // Variant rows
              ...variants.map((p) {
                final pkts = p.remainingStock.toInt();
                final sizeInKg = _getSizeInKg(p.packSize);
                final variantKg = pkts * sizeInKg;
                final isOut = pkts <= 0;
                final isLow = pkts > 0 && pkts < 10;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
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
                    leading: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        p.packSize.toLowerCase().replaceAll(' ', '') == '50g-1kg' ? '50g (1kg Bag)' : p.packSize,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isOut
                                ? Colors.red.shade50
                                : (isLow ? Colors.amber.shade50 : Colors.green.shade50),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isOut
                                  ? Colors.red.shade200
                                  : (isLow ? Colors.amber.shade300 : Colors.green.shade300),
                            ),
                          ),
                          child: Text(
                            '$pkts Packets',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isOut
                                  ? Colors.red.shade800
                                  : (isLow ? Colors.amber.shade900 : Colors.green.shade800),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${variantKg.toStringAsFixed(1)} kg)',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      'Price: ${rupeeFormat.format(p.wholesalePrice)} / pkt',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Edit details',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProductDetailScreen(product: p),
                              ),
                            );
                          },
                        ),
                        if (isSuperAdmin)
                          Switch(
                            value: p.isEnabled,
                            onChanged: (val) {
                              final updated = p.copyWith(isEnabled: val);
                              db.updateProduct(updated);
                            },
                            activeColor: AppColors.primaryGreen,
                          ),
                      ],
                    ),
                  ),
                );
              }),

              // Allocate Stock into Packets Action Button
              if (hasUnallocatedBulk)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showAllocatePacketsSheet(context, m, variants, db),
                    icon: const Icon(Icons.inventory_2_outlined, size: 16),
                    label: Text(
                      noPacketsAllocated
                          ? 'ALLOCATE ${m.totalStockKg.toStringAsFixed(1)} KG INTO PACKETS'
                          : 'ALLOCATE MORE BULK INTO PACKETS',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: noPacketsAllocated ? AppColors.primaryRed : Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 1,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );

    Widget content = RefreshIndicator(
      onRefresh: () async {
        await db.refreshProductsAndStock();
      },
      child: listBody,
    );

    if (isEmbedded) {
      return Scaffold(
        body: content,
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
      body: content,
      floatingActionButton: isSuperAdmin ? FloatingActionButton(
        onPressed: () => _showAddEditProductDialog(context),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ) : null,
    );
  }
}
