import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../../core/models/customer.dart';
import '../../core/services/database_service.dart';
import '../../core/theme.dart';
import 'customer_form_dialog.dart';
import 'package:share_plus/share_plus.dart';
import '../sales/invoice_generator.dart';

class CustomerDetailScreen extends StatelessWidget {
  final Customer customer;

  const CustomerDetailScreen({Key? key, required this.customer}) : super(key: key);

  Future<void> _openMapLink(BuildContext context, Customer currentCustomer) async {
    if (currentCustomer.latitude == null || currentCustomer.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No GPS coordinates saved for this customer.')),
      );
      return;
    }

    final url = 'https://www.google.com/maps/search/?api=1&query=${currentCustomer.latitude},${currentCustomer.longitude}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open map link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    
    // Fetch the latest customer data so edits reflect immediately
    final currentCustomer = db.customers.firstWhere(
      (c) => c.id == customer.id,
      orElse: () => customer,
    );

    final rupeeFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    // Calculate customer transactions
    final customerSales = db.sales.where((s) => s.customerId == currentCustomer.id).toList();
    final totalSpent = customerSales.fold<double>(0, (prev, element) => prev + element.finalAmount);

    // Calculate frequent products
    final Map<String, int> productCount = {};
    for (var sale in customerSales) {
      for (var item in sale.items) {
        productCount[item.productName] = (productCount[item.productName] ?? 0) + 1;
      }
    }
    final sortedProducts = productCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final frequentProducts = sortedProducts.take(3).map((e) => '${e.key} (${e.value} times)').toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(currentCustomer.shopName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              showCustomerFormDialog(context, customerToEdit: currentCustomer);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Customer'),
                  content: const Text('Are you sure you want to permanently delete this customer profile? This action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
                      onPressed: () {
                        db.deleteCustomer(currentCustomer.id);
                        Navigator.pop(ctx); // close dialog
                        Navigator.pop(context); // close details screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Customer deleted successfully')),
                        );
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Shop Details Card (Photo + info)
            Card(
              child: Column(
                children: [
                  // Photo Banner
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                    ),
                    child: currentCustomer.shopImageUrl.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.storefront, size: 64, color: AppColors.primaryRed),
                                SizedBox(height: 8),
                                Text('No Shop Photo Registered', style: TextStyle(color: AppColors.textLight)),
                              ],
                            ),
                          )
                        : GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: currentCustomer.shopImageUrl.startsWith('http')
                                            ? Image.network(
                                                currentCustomer.shopImageUrl,
                                                fit: BoxFit.contain,
                                              )
                                            : Image.file(
                                                File(currentCustomer.shopImageUrl),
                                                fit: BoxFit.contain,
                                              ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: IconButton(
                                          icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                          onPressed: () => Navigator.pop(ctx),
                                          style: IconButton.styleFrom(backgroundColor: Colors.black54),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                              child: currentCustomer.shopImageUrl.startsWith('http')
                                  ? Image.network(
                                      currentCustomer.shopImageUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: 180,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.broken_image, size: 64, color: Colors.grey),
                                              SizedBox(height: 8),
                                              Text('Photo missing or corrupted', style: TextStyle(color: Colors.grey)),
                                            ],
                                          ),
                                        );
                                      },
                                    )
                                  : Image.file(
                                      File(currentCustomer.shopImageUrl),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: 180,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.broken_image, size: 64, color: Colors.grey),
                                              SizedBox(height: 8),
                                              Text('Photo missing or corrupted', style: TextStyle(color: Colors.grey)),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                currentCustomer.shopName,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (currentCustomer.gstNumber.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'GST: ${currentCustomer.gstNumber}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.person, size: 16, color: AppColors.textLight),
                            const SizedBox(width: 8),
                            Text('Owner: ${currentCustomer.ownerName}', style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 16, color: AppColors.textLight),
                            const SizedBox(width: 8),
                            Text('Mobile: ${currentCustomer.mobileNumber}', style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on, size: 16, color: AppColors.textLight),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Address: ${currentCustomer.address}, ${currentCustomer.city}, ${currentCustomer.district}'),
                            ),
                          ],
                        ),
                        
                        const Divider(height: 24),

                        // GPS Actions
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('GPS Coordinates', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                                  Text(
                                    currentCustomer.latitude != null
                                        ? '${currentCustomer.latitude}, ${currentCustomer.longitude}'
                                        : 'Not Configured',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _openMapLink(context, currentCustomer),
                              icon: const Icon(Icons.map, size: 16),
                              label: const Text('Open Maps'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Customer Stats
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Purchases', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                          const SizedBox(height: 4),
                          Text(
                            rupeeFormat.format(totalSpent),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                          ),
                          Text('${customerSales.length} Invoices', style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Frequent Spice', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                          const SizedBox(height: 4),
                          Text(
                            frequentProducts.isNotEmpty ? frequentProducts.first : 'N/A',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Purchase History Log List
            const Text(
              'Purchase History Log',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const SizedBox(height: 8),

            customerSales.isEmpty
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No transaction history recorded')),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: customerSales.length,
                    itemBuilder: (ctx, idx) {
                      final sale = customerSales[idx];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(sale.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(DateFormat('dd MMM yyyy, hh:mm a').format(sale.dateTime)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(rupeeFormat.format(sale.finalAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(
                                sale.paymentStatus,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: sale.paymentStatus == 'Paid' ? AppColors.primaryGreen : AppColors.lowStockAlert,
                                ),
                              ),
                              if (db.currentUserProfile?.role == 'delivery')
                                Text(
                                  sale.deliveryStatus,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: sale.deliveryStatus == 'Delivered' ? AppColors.primaryGreen : Colors.orange,
                                  ),
                                ),
                            ],
                          ),
                          onTap: () {
                            // Show Invoice Items Popup
                            showDialog(
                              context: context,
                              builder: (dialogCtx) {
                                bool isGenerating = false;
                                return StatefulBuilder(
                                  builder: (context, setState) {
                                    return AlertDialog(
                                      title: Text('Invoice Details: ${sale.invoiceNumber}'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ...sale.items.map((i) => Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 4),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(child: Text('${i.productName} (${i.packSize}) x ${i.quantity}')),
                                                    Text(rupeeFormat.format(i.totalAmount)),
                                                  ],
                                                ),
                                              )),
                                          const Divider(),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('Subtotal:'),
                                              Text(rupeeFormat.format(sale.totalAmount)),
                                            ],
                                          ),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('Discount:'),
                                              Text('- ${rupeeFormat.format(sale.discount)}'),
                                            ],
                                          ),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('Final Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                                              Text(rupeeFormat.format(sale.finalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Close')),
                                        ElevatedButton.icon(
                                          onPressed: isGenerating
                                              ? null
                                              : () async {
                                                  setState(() => isGenerating = true);
                                                  try {
                                                    final file = await InvoiceGenerator.generateInvoice(
                                                      sale,
                                                      customerPhone: currentCustomer.mobileNumber,
                                                      customerAddress: '${currentCustomer.address}, ${currentCustomer.city} - ${currentCustomer.district}',
                                                      showDeliveryStatus: db.currentUserProfile?.role == 'delivery',
                                                    );
                                                    if (dialogCtx.mounted) {
                                                      final xFile = XFile(file.path, mimeType: 'application/pdf');
                                                      await Share.shareXFiles(
                                                        [xFile],
                                                        subject: 'Invoice ${sale.invoiceNumber}',
                                                        text: 'Hello ${currentCustomer.shopName}, here is your invoice ${sale.invoiceNumber} from Captain Masala.',
                                                      );
                                                    }
                                                  } catch (e) {
                                                    if (dialogCtx.mounted) {
                                                      ScaffoldMessenger.of(dialogCtx).showSnackBar(SnackBar(content: Text('Error generating invoice: $e')));
                                                    }
                                                  } finally {
                                                    if (dialogCtx.mounted) {
                                                      setState(() => isGenerating = false);
                                                    }
                                                  }
                                                },
                                          icon: isGenerating
                                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                              : const Icon(Icons.chat, size: 18),
                                          label: const Text('Share to WhatsApp'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF25D366),
                                            foregroundColor: Colors.white,
                                          ),
                                        )
                                      ],
                                    );
                                  }
                                );
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
