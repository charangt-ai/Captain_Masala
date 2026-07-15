import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/theme.dart';
import '../../../core/models/product.dart';
import '../../../core/models/product_category.dart';
import 'widgets/shop_search_bar.dart';
import 'widgets/product_card.dart';
import 'cart_screen.dart';

class ProductListScreen extends StatefulWidget {
  final ProductCategory category;

  const ProductListScreen({Key? key, required this.category}) : super(key: key);

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final cartService = Provider.of<CartService>(context);
    final isSuperAdmin = db.currentUserProfile?.role == 'super_admin';
    
    // Filter logic: Uses the centralized db.getProductsForCategory method
    List<Product> categoryProducts = db.getProductsForCategory(widget.category.id);

    return Scaffold(
      backgroundColor: AppColors.shopBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryRed,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.category.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (isSuperAdmin)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.white),
              onPressed: () => _showAddEditProductDialog(context),
            ),
          Consumer<CartService>(
            builder: (context, cart, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CartScreen()),
                      );
                    },
                  ),
                  if (cart.totalItems > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${cart.totalItems}',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            ShopSearchBar(hintText: 'Search in ${widget.category.name}...'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.category.name,
                  style: const TextStyle(
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${categoryProducts.length} items',
                  style: const TextStyle(color: AppColors.textLight, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.70, // Adjusted for image + text + button
                ),
                itemCount: categoryProducts.length,
                itemBuilder: (context, index) {
                  final product = categoryProducts[index];
                  final originalPrice = product.originalPrice > 0 ? product.originalPrice : product.wholesalePrice * 1.5;
                  double availableStock = 0.0;
                  if (product.masterProductId.isNotEmpty) {
                    try {
                      final master = db.masterProducts.firstWhere((m) => m.id == product.masterProductId);
                      availableStock = master.totalStockKg;
                    } catch (e) {
                      availableStock = product.remainingStock;
                    }
                  } else {
                    availableStock = product.remainingStock;
                  }
                  final isAvailable = availableStock > 0;
                  
                  int discountPercent = 0;
                  if (originalPrice > product.wholesalePrice) {
                    discountPercent = ((originalPrice - product.wholesalePrice) / originalPrice * 100).round();
                  }

                  final cartQuantity = cartService.items[product.id]?.quantity ?? 0;

                  return Stack(
                    children: [
                      ShopProductCard(
                        product: product,
                        isAvailable: isAvailable,
                        discountPercentage: discountPercent > 0 ? '$discountPercent% OFF' : 'NA',
                        originalPrice: originalPrice,
                        cartQuantity: cartQuantity,
                        onAdd: () {
                          cartService.addItem(product);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${product.name} added to cart'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        onIncrement: () {
                          cartService.addItem(product);
                        },
                        onDecrement: () {
                          if (cartQuantity > 0) {
                            cartService.updateQuantity(product.id, cartQuantity - 1);
                          }
                        },
                      ),
                      if (isSuperAdmin)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: GestureDetector(
                            onTap: () => _showAddEditProductDialog(context, product),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                  )
                                ],
                              ),
                              child: const Icon(Icons.edit, size: 16, color: AppColors.primaryRed),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEditProductDialog(BuildContext context, [Product? product]) {
    final bool isEditing = product != null;
    final nameController = TextEditingController(text: product?.name ?? '');
    final packSizeController = TextEditingController(text: product?.packSize ?? widget.category.name);
    final wholesalePriceController = TextEditingController(text: product?.wholesalePrice.toString() ?? '');
    final originalPriceController = TextEditingController(text: product?.originalPrice.toString() ?? '');
    final stockController = TextEditingController(text: product?.remainingStock.toString() ?? '100');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Product' : 'Add New Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Product Name')),
                TextField(controller: packSizeController, decoration: const InputDecoration(labelText: 'Pack Size (e.g. 50g)')),
                TextField(controller: wholesalePriceController, decoration: const InputDecoration(labelText: 'Selling Price (Rs)'), keyboardType: TextInputType.number),
                TextField(controller: originalPriceController, decoration: const InputDecoration(labelText: 'Original Price (Rs)'), keyboardType: TextInputType.number),
                TextField(controller: stockController, decoration: const InputDecoration(labelText: 'Stock Quantity'), keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty || wholesalePriceController.text.trim().isEmpty) return;

                final db = Provider.of<DatabaseService>(context, listen: false);

                // Generate masterProductId from product name for proper catalog grouping
                String masterId = isEditing
                    ? (product.masterProductId)
                    : nameController.text.trim().toLowerCase().replaceAll(' ', '_');

                final newProduct = Product(
                  id: isEditing ? product.id : DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.trim(),
                  packSize: packSizeController.text.trim(),
                  wholesalePrice: double.tryParse(wholesalePriceController.text.trim()) ?? 0.0,
                  originalPrice: double.tryParse(originalPriceController.text.trim()) ?? 0.0,
                  remainingStock: double.tryParse(stockController.text.trim()) ?? 0.0,
                  categoryId: widget.category.id, // Enforce category attachment
                  isEnabled: product?.isEnabled ?? true,
                  imageUrl: product?.imageUrl ?? '',
                  masterProductId: masterId,
                );

                if (isEditing) {
                  db.updateProduct(newProduct);
                } else {
                  db.addProduct(newProduct);
                }

                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
