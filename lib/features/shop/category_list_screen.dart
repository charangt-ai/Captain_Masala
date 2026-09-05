import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/models/product_category.dart';
import '../../../core/theme.dart';
import '../../../core/permissions.dart';
import 'widgets/shop_search_bar.dart';
import 'product_list_screen.dart';
import 'cart_screen.dart';

class CategoryListScreen extends StatefulWidget {
  final bool isEmbedded;
  const CategoryListScreen({Key? key, this.isEmbedded = false}) : super(key: key);

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.shopBackground,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primaryRed,
      elevation: 0,
      leading: widget.isEmbedded ? null : IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Categories',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: false,
      actions: [
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
    );
  }

  Widget _buildBody() {
    final db = Provider.of<DatabaseService>(context);
    final _categories = db.categories;
    final isSuperAdmin = Permissions.isSuperAdmin(db.currentUserProfile?.role);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const ShopSearchBar(hintText: 'Search products...'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CATEGORIES',
                style: TextStyle(
                  color: AppColors.primaryRed,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontSize: 12,
                ),
              ),
              Row(
                children: [
                  if (isSuperAdmin)
                    IconButton(
                      onPressed: () => _showAddCategoryDialog(context),
                      icon: const Icon(Icons.add_circle, color: AppColors.primaryRed, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.refresh, size: 14, color: AppColors.textLight),
                    label: const Text(
                      'Refresh',
                      style: TextStyle(color: AppColors.textLight, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductListScreen(category: cat),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200, width: 2),
                                ),
                                child: cat.image.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: cat.image.startsWith('data:image')
                                            ? Image.memory(
                                                base64Decode(cat.image.split(',')[1]),
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                errorBuilder: (context, error, stackTrace) => const Center(
                                                  child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                                ),
                                              )
                                            : CachedNetworkImage(
                                                imageUrl: cat.image,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                placeholder: (context, url) => const Center(
                                                  child: CircularProgressIndicator(),
                                                ),
                                                errorWidget: (context, url, error) => const Center(
                                                  child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                                ),
                                              ),
                                      )
                                    : const Center(
                                        child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Text(
                                  cat.name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isSuperAdmin)
                          Positioned(
                            top: -8,
                            right: -8,
                            child: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textLight),
                              padding: EdgeInsets.zero,
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit', style: TextStyle(fontSize: 14)),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete', style: TextStyle(fontSize: 14, color: Colors.red)),
                                ),
                              ],
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showEditCategoryDialog(context, cat);
                                } else if (value == 'delete') {
                                  _showDeleteConfirmationDialog(context, cat);
                                }
                              },
                            ),
                          ),
                      ],
                    ),

                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    File? selectedImage;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Category'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final pickedFile = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 400,
                          maxHeight: 400,
                          imageQuality: 60,
                        );
                        if (pickedFile != null) {
                          setState(() {
                            selectedImage = File(pickedFile.path);
                          });
                        }
                      },
                      child: Container(
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: selectedImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(selectedImage!, fit: BoxFit.cover),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, color: Colors.grey),
                                  SizedBox(height: 4),
                                  Text('Add Photo', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(hintText: 'Category Name'),
                    ),
                    if (isUploading) ...[
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUploading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isUploading ? null : () async {
                    if (nameController.text.trim().isNotEmpty) {
                      setState(() {
                        isUploading = true;
                      });
                      final db = Provider.of<DatabaseService>(context, listen: false);
                      final id = DateTime.now().millisecondsSinceEpoch.toString();
                      String imageUrl = '';

                      if (selectedImage != null) {
                        try {
                          final bytes = await selectedImage!.readAsBytes();
                          
                          // Enforce pure Dart compression to fix PNG issues
                          img.Image? decodedImage = img.decodeImage(bytes);
                          if (decodedImage != null) {
                            if (decodedImage.width > 400 || decodedImage.height > 400) {
                              decodedImage = img.copyResize(decodedImage, width: 400);
                            }
                            
                            final compressedBytes = img.encodeJpg(decodedImage, quality: 60);
                            final base64String = base64Encode(compressedBytes);
                            imageUrl = 'data:image/jpeg;base64,$base64String';
                          }
                        } catch (e) {
                          debugPrint('Error encoding image: $e');
                        }
                      }

                      final newCat = ProductCategory(
                        id: id,
                        name: nameController.text.trim(),
                        image: imageUrl,
                      );
                      db.addCategory(newCat);
                      if (context.mounted) Navigator.pop(context);
                    }
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

  void _showEditCategoryDialog(BuildContext context, ProductCategory category) {
    final TextEditingController nameController = TextEditingController(text: category.name);
    File? selectedImage;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Category'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final pickedFile = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 400,
                          maxHeight: 400,
                          imageQuality: 60,
                        );
                        if (pickedFile != null) {
                          setState(() {
                            selectedImage = File(pickedFile.path);
                          });
                        }
                      },
                      child: Container(
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: selectedImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(selectedImage!, fit: BoxFit.cover),
                              )
                            : category.image.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: category.image.startsWith('data:image')
                                        ? Image.memory(
                                            base64Decode(category.image.split(',')[1]),
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => const Center(
                                              child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                            ),
                                          )
                                        : CachedNetworkImage(
                                            imageUrl: category.image,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                            errorWidget: (context, url, error) => const Center(
                                              child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                            ),
                                          ),
                                  )
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo, color: Colors.grey),
                                      SizedBox(height: 4),
                                      Text('Add Photo', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(hintText: 'Category Name'),
                    ),
                    if (isUploading) ...[
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUploading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isUploading ? null : () async {
                    if (nameController.text.trim().isNotEmpty) {
                      setState(() {
                        isUploading = true;
                      });
                      final db = Provider.of<DatabaseService>(context, listen: false);
                      String imageUrl = category.image;

                      if (selectedImage != null) {
                        final url = await db.uploadCategoryImage(selectedImage!, category.id);
                        if (url != null) {
                          imageUrl = url;
                        }
                      }

                      final updatedCat = ProductCategory(
                        id: category.id,
                        name: nameController.text.trim(),
                        image: imageUrl,
                      );
                      db.updateCategory(updatedCat);
                      if (context.mounted) Navigator.pop(context);
                    }
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

  void _showDeleteConfirmationDialog(BuildContext context, ProductCategory category) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Category'),
          content: Text('Are you sure you want to delete "${category.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                final db = Provider.of<DatabaseService>(context, listen: false);
                db.deleteCategory(category.id);
                Navigator.pop(context);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
