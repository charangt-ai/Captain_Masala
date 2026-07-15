import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/customer.dart';
import '../../core/models/sale.dart';
import '../../core/services/database_service.dart';
import '../../core/theme.dart';
import 'invoice_generator.dart';
import 'sales_entry_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final Sale sale;

  const OrderDetailScreen({Key? key, required this.sale}) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _cancelReasonController = TextEditingController();
  final _partialPaymentController = TextEditingController();

  @override
  void dispose() {
    _cancelReasonController.dispose();
    _partialPaymentController.dispose();
    super.dispose();
  }

  String get _displayShopName =>
      widget.sale.shopName.isNotEmpty ? widget.sale.shopName : widget.sale.customerName;

  void _showCancelDialog(DatabaseService db) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to cancel this order? This action will preserve the order history but mark it as Cancelled.'),
            const SizedBox(height: 12),
            TextField(
              controller: _cancelReasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for cancellation',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No, Keep It')),
          ElevatedButton(
            onPressed: () {
              final reason = _cancelReasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a cancellation reason')));
                return;
              }
              db.cancelSale(widget.sale.id, reason);
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close detail screen
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order Cancelled')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed, foregroundColor: Colors.white),
            child: const Text('Yes, Cancel Order'),
          ),
        ],
      ),
    );
  }

  void _showMarkDeliveredDialog(DatabaseService db) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Delivered'),
        content: const Text('Are you sure you want to mark this order as delivered?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              db.markSaleDelivered(widget.sale.id);
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close detail screen
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order marked as Delivered')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    // Find the latest sale data if it was updated
    final sale = db.sales.firstWhere((s) => s.id == widget.sale.id, orElse: () => widget.sale);
    final rupeeFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final isPaid = sale.paymentStatus == 'Paid';
    final isDelivered = sale.deliveryStatus == 'Delivered';
    final isCancelled = sale.status == 'Cancelled';

    final currentUserRole = db.currentUserProfile?.role ?? '';
    bool canEditOrder = true;
    if (isPaid) {
      canEditOrder = currentUserRole == 'super_admin';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Order Details - ${sale.invoiceNumber}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status and Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order No: ${sale.invoiceNumber}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(DateFormat('dd MMM yyyy, hh:mm a').format(sale.dateTime)),
                  ],
                ),
                if (isCancelled)
                  _buildStatusBadge('Cancelled')
                else if (db.currentUserProfile?.role == 'delivery')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: sale.deliveryStatus == 'Delivered' ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: sale.deliveryStatus == 'Delivered' ? Colors.green : Colors.orange),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: sale.deliveryStatus,
                        isDense: true,
                        icon: const Icon(Icons.arrow_drop_down, size: 20),
                        style: TextStyle(
                          color: sale.deliveryStatus == 'Delivered' ? Colors.green.shade700 : Colors.orange.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Not Delivered', child: Text('Not Delivered')),
                          DropdownMenuItem(value: 'Delivered', child: Text('Delivered')),
                        ],
                        onChanged: (val) {
                          if (val != null && val != sale.deliveryStatus) {
                            db.updateDeliveryStatus(sale.id, val);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Delivery status updated to $val')),
                            );
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 32),

            // Customer Info
            const Text('Customer Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Shop/Name: $_displayShopName', style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (sale.customerName != sale.shopName && sale.shopName.isNotEmpty)
                      Text('Contact Person: ${sale.customerName}'),
                    if (sale.phone.isNotEmpty) Text('Phone: ${sale.phone}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Item List
            const Text('Order Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sale.items.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final item = sale.items[i];
                  return ListTile(
                    title: Text('${item.productName} (${item.packSize})', style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('${item.quantity} x ${rupeeFormat.format(item.rate)}'),
                    trailing: Text(rupeeFormat.format(item.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Total Summary
            Builder(
              builder: (context) {
                double totalTaxableAmount = 0.0;
                double totalSgst = 0.0;
                double totalCgst = 0.0;

                for (var item in sale.items) {
                  final totalIncl = item.totalAmount;
                  final taxable = totalIncl / 1.05;
                  final sgst = (totalIncl - taxable) / 2;
                  final cgst = (totalIncl - taxable) / 2;
                  totalTaxableAmount += taxable;
                  totalSgst += sgst;
                  totalCgst += cgst;
                }
                final calculatedNetAmount = totalTaxableAmount + totalSgst + totalCgst;

                return Card(
                  color: Colors.grey.shade50,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildSummaryRow('Total Taxable Amount', totalTaxableAmount, rupeeFormat),
                        _buildSummaryRow('Total SGST', totalSgst, rupeeFormat),
                        _buildSummaryRow('Total CGST', totalCgst, rupeeFormat),
                        const Divider(height: 12),
                        _buildSummaryRow('Gross Amount', calculatedNetAmount, rupeeFormat),
                        if (sale.discount > 0)
                          _buildSummaryRow('Discount', -sale.discount, rupeeFormat, color: AppColors.primaryGreen),
                        if (sale.prepaidAmount > 0)
                          _buildSummaryRow('Prepaid Amount', -sale.prepaidAmount, rupeeFormat, color: Colors.blue),
                        const Divider(height: 24),
                        _buildSummaryRow('Net Amount', calculatedNetAmount - sale.discount, rupeeFormat, isBold: true, size: 18),
                      ],
                    ),
                  ),
                );
              }
            ),
            const SizedBox(height: 24),

            if (isCancelled && sale.cancelReason != null && sale.cancelReason!.isNotEmpty) ...[
               Container(
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(
                   color: Colors.red.shade50,
                   borderRadius: BorderRadius.circular(8),
                   border: Border.all(color: Colors.red.shade200),
                 ),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     const Text('Cancellation Reason:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                     const SizedBox(height: 4),
                     Text(sale.cancelReason!, style: const TextStyle(color: Colors.red)),
                   ],
                 ),
               ),
               const SizedBox(height: 24),
            ],

            // Action Buttons
            if (!isCancelled) ...[
              const Text('Order Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              
              if (!isDelivered && db.currentUserProfile?.role == 'delivery')
                ElevatedButton.icon(
                  onPressed: () => _showMarkDeliveredDialog(db),
                  icon: const Icon(Icons.local_shipping),
                  label: const Text('Mark as Delivered'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: canEditOrder 
                        ? () {
                            // Navigate to edit screen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SalesEntryScreen(editSale: sale),
                              ),
                            );
                          }
                        : null,
                      icon: const Icon(Icons.edit),
                      label: Text(canEditOrder ? 'Edit Order' : 'Locked (Paid)'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showCancelDialog(db),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel Order'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryRed,
                        side: const BorderSide(color: AppColors.primaryRed),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            const Text('Invoice Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        Customer? customer;
                        try {
                           customer = db.customers.firstWhere((c) => c.id == sale.customerId);
                        } catch (e) {}
                        
                        final file = await InvoiceGenerator.generateInvoice(
                          sale,
                          customerPhone: customer?.mobileNumber ?? sale.phone,
                          customerAddress: customer != null ? '${customer.address}, ${customer.city} - ${customer.district}' : '',
                          showDeliveryStatus: db.currentUserProfile?.role == 'delivery',
                        );
                        if (context.mounted) {
                          final xFile = XFile(file.path, mimeType: 'application/pdf');
                          await Share.shareXFiles([xFile], subject: 'Invoice ${sale.invoiceNumber}');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        Customer? customer;
                        try {
                           customer = db.customers.firstWhere((c) => c.id == sale.customerId);
                        } catch (e) {}
                        
                        final file = await InvoiceGenerator.generateInvoice(
                          sale,
                          customerPhone: customer?.mobileNumber ?? sale.phone,
                          customerAddress: customer != null ? '${customer.address}, ${customer.city} - ${customer.district}' : '',
                          showDeliveryStatus: db.currentUserProfile?.role == 'delivery',
                        );
                        if (context.mounted) {
                          final xFile = XFile(file.path, mimeType: 'application/pdf');
                          await Share.shareXFiles(
                            [xFile],
                            text: 'Invoice ${sale.invoiceNumber} from Captain Masala and Spices',
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            const Text('Payment Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            if (!isPaid && !isCancelled) ...[
              const Text('Add Partial Payment', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _partialPaymentController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount (Rem: ${rupeeFormat.format(sale.finalAmount - sale.prepaidAmount)})',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      final amount = double.tryParse(_partialPaymentController.text);
                      if (amount != null && amount > 0) {
                        db.updatePrepaidAmount(sale.id, amount, sale.finalAmount);
                        _partialPaymentController.clear();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded successfully')));
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed, foregroundColor: Colors.white),
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isPaid
                        ? null
                        : () {
                            db.updatePaymentStatus(sale.id, 'Paid');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Marked invoice as Paid')),
                            );
                          },
                    icon: const Icon(Icons.check),
                    label: const Text('Mark Paid'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: !isPaid
                        ? null
                        : () {
                            db.updatePaymentStatus(sale.id, 'Pending');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Marked invoice as Pending')),
                            );
                          },
                    icon: const Icon(Icons.pending),
                    label: const Text('Mark Pending'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lowStockAlert,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    
    switch (status) {
      case 'Delivered':
        bgColor = AppColors.primaryGreen.withOpacity(0.1);
        textColor = AppColors.primaryGreen;
        break;
      case 'Cancelled':
        bgColor = AppColors.primaryRed.withOpacity(0.1);
        textColor = AppColors.primaryRed;
        break;
      default: // Not Delivered
        bgColor = AppColors.lowStockAlert.withOpacity(0.1);
        textColor = AppColors.lowStockAlert;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, NumberFormat format, {bool isBold = false, double size = 14, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: size, color: color)),
          Text(format.format(amount), style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: size, color: color)),
        ],
      ),
    );
  }
}
