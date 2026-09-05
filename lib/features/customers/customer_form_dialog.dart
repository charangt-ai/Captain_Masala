import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'dart:typed_data';
import '../../core/models/customer.dart';
import '../../core/services/database_service.dart';
import '../../core/theme.dart';

void showCustomerFormDialog(BuildContext context, {Customer? customerToEdit}) {
  final formKey = GlobalKey<FormState>();
  final isEditing = customerToEdit != null;

  final shopNameController = TextEditingController(text: isEditing ? customerToEdit.shopName : '');
  final ownerNameController = TextEditingController(text: isEditing ? customerToEdit.ownerName : '');
  final mobileController = TextEditingController(text: isEditing ? customerToEdit.mobileNumber : '');
  final addressController = TextEditingController(text: isEditing ? customerToEdit.address : '');
  final cityController = TextEditingController(text: isEditing ? customerToEdit.city : '');
  
  String tempDistrict = isEditing ? customerToEdit.district : 'Salem';
  String gstNumber = isEditing ? customerToEdit.gstNumber : '';
  double? lat = isEditing ? customerToEdit.latitude : null;
  double? lng = isEditing ? customerToEdit.longitude : null;
  String pickedImagePath = isEditing ? customerToEdit.shopImageUrl : '';
  Uint8List? pickedImageBytes;
  String? tempPickedPath;
  bool isSaving = false;

  final List<String> districts = [
    'Salem',
    'Namakkal',
    'Dharmapuri',
    'Krishnagiri',
    'Erode',
    'Coimbatore'
  ];

  if (!districts.contains(tempDistrict) && tempDistrict.isNotEmpty) {
    districts.add(tempDistrict);
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          
          Future<void> captureGPS() async {
            try {
              LocationPermission permission = await Geolocator.checkPermission();
              if (permission == LocationPermission.denied) {
                permission = await Geolocator.requestPermission();
              }
              if (permission == LocationPermission.deniedForever) {
                throw Exception('Location permissions are permanently denied.');
              }
              
              final pos = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high,
                timeLimit: const Duration(seconds: 5),
              );
              
              setDialogState(() {
                lat = pos.latitude;
                lng = pos.longitude;
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('GPS coordinates captured successfully!'), backgroundColor: AppColors.primaryGreen),
              );
            } catch (e) {
              setDialogState(() {
                lat = 11.6643 + (DateTime.now().millisecond / 100000.0);
                lng = 78.1460 + (DateTime.now().millisecond / 100000.0);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('GPS Permission/Service error. Using simulated coordinates: $lat, $lng'), backgroundColor: AppColors.lowStockAlert),
              );
            }
          }

          Future<void> pickImage(ImageSource source) async {
            try {
              final picker = ImagePicker();
              final picked = await picker.pickImage(
                source: source, 
                imageQuality: 50,
                maxWidth: 800,
                maxHeight: 800,
              );
              if (picked != null) {
                final bytes = await picked.readAsBytes();
                if (bytes.isNotEmpty) {
                  setDialogState(() {
                    tempPickedPath = picked.path;
                    pickedImageBytes = bytes;
                  });
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Selected image is empty or corrupted.'), backgroundColor: AppColors.lowStockAlert),
                    );
                  }
                }
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to pick image'), backgroundColor: AppColors.outOfStockAlert),
              );
            }
          }

          return AlertDialog(
            title: Text(isEditing ? 'Edit Customer' : 'Register New Customer'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 120,
                      width: MediaQuery.of(context).size.width * 0.7,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: pickedImageBytes == null && pickedImagePath.isEmpty
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.storefront_rounded, size: 40, color: Colors.grey),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => pickImage(ImageSource.camera),
                                      icon: const Icon(Icons.camera_alt),
                                      label: const Text('Camera'),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => pickImage(ImageSource.gallery),
                                      icon: const Icon(Icons.image),
                                      label: const Text('Gallery'),
                                    ),
                                  ],
                                )
                              ],
                            )
                          : Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: pickedImageBytes != null
                                      ? Image.memory(
                                          pickedImageBytes!,
                                          width: MediaQuery.of(context).size.width * 0.7,
                                          height: 120,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Center(
                                              child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                            );
                                          },
                                        )
                                      : pickedImagePath.startsWith('http')
                                          ? Image.network(
                                              pickedImagePath,
                                              width: MediaQuery.of(context).size.width * 0.7,
                                              height: 120,
                                              fit: BoxFit.cover,
                                            )
                                          : Image.file(
                                              File(pickedImagePath),
                                              width: MediaQuery.of(context).size.width * 0.7,
                                              height: 120,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return const Center(
                                                  child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                                );
                                              },
                                            ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: InkWell(
                                    onTap: () {
                                      setDialogState(() {
                                        pickedImagePath = '';
                                        pickedImageBytes = null;
                                        tempPickedPath = null;
                                      });
                                    },
                                    child: const CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Colors.white,
                                      child: Icon(Icons.close, size: 16, color: Colors.black),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: shopNameController,
                      decoration: const InputDecoration(labelText: 'Shop Name'),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter shop name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: ownerNameController,
                      decoration: const InputDecoration(labelText: 'Owner Name'),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter owner name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: mobileController,
                      decoration: const InputDecoration(labelText: 'Mobile Number'),
                      keyboardType: TextInputType.phone,
                      validator: (val) => val == null || val.trim().length < 10 ? 'Enter valid 10-digit number' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: addressController,
                      decoration: const InputDecoration(labelText: 'Street Address'),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter address' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: cityController,
                      decoration: const InputDecoration(labelText: 'City / Town'),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter city' : null,
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: tempDistrict,
                      decoration: const InputDecoration(labelText: 'District'),
                      items: districts.map((d) {
                        return DropdownMenuItem(value: d, child: Text(d));
                      }).toList(),
                      onChanged: (val) => setDialogState(() => tempDistrict = val ?? 'Salem'),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      initialValue: gstNumber,
                      decoration: const InputDecoration(labelText: 'GST IN (Optional)'),
                      onChanged: (val) => gstNumber = val.trim(),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: lat?.toString() ?? '',
                            decoration: const InputDecoration(labelText: 'Latitude (Optional)'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            onSaved: (val) {
                              lat = (val != null && val.trim().isNotEmpty) ? double.tryParse(val.trim()) : null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: lng?.toString() ?? '',
                            decoration: const InputDecoration(labelText: 'Longitude (Optional)'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            onSaved: (val) {
                              lng = (val != null && val.trim().isNotEmpty) ? double.tryParse(val.trim()) : null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : () async {
                  if (!formKey.currentState!.validate()) return;
                  
                  setDialogState(() {
                    formKey.currentState!.save();
                    isSaving = true;
                  });
                  
                  String finalImagePath = pickedImagePath;
                  
                  // Save picked image locally
                  if (pickedImageBytes != null && tempPickedPath != null) {
                    try {
                      final String extension = p.extension(tempPickedPath!).isNotEmpty ? p.extension(tempPickedPath!) : '.jpg';
                      final String fileName = 'shop_${DateTime.now().millisecondsSinceEpoch}$extension';
                      
                      final Directory appDocDir = await getApplicationDocumentsDirectory();
                      final String localPath = p.join(appDocDir.path, fileName);
                      final File localImage = File(localPath);
                      
                      await localImage.writeAsBytes(pickedImageBytes!);
                      finalImagePath = localPath;
                    } catch (e) {
                      debugPrint('Error saving shop photo locally: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to save photo locally.'), backgroundColor: AppColors.outOfStockAlert),
                        );
                      }
                    }
                  }

                  if (!context.mounted) return;

                  final db = Provider.of<DatabaseService>(context, listen: false);
                  final currentUser = db.currentUserProfile;
                  final customer = Customer(
                    id: isEditing ? customerToEdit.id : DateTime.now().millisecondsSinceEpoch.toString(),
                    name: ownerNameController.text.trim(),
                    shopName: shopNameController.text.trim(),
                    ownerName: ownerNameController.text.trim(),
                    mobileNumber: mobileController.text.trim(),
                    address: addressController.text.trim(),
                    district: tempDistrict,
                    city: cityController.text.trim(),
                    gstNumber: gstNumber,
                    shopImageUrl: finalImagePath,
                    latitude: lat,
                    longitude: lng,
                    handledById: isEditing ? customerToEdit.handledById : currentUser?.id,
                    handledByName: isEditing ? customerToEdit.handledByName : currentUser?.name,
                  );
                  
                  if (isEditing) {
                    await db.updateCustomer(customer);
                    if (context.mounted) {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Customer updated successfully!'), backgroundColor: AppColors.primaryGreen),
                      );
                    }
                  } else {
                    await db.addCustomer(customer);
                    if (context.mounted) {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Customer registered successfully!'), backgroundColor: AppColors.primaryGreen),
                      );
                    }
                  }
                },
                child: isSaving 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(isEditing ? 'Save Changes' : 'Register'),
              ),
            ],
          );
        },
      );
    },
  );
}
