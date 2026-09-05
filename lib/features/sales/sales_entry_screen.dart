import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/models/customer.dart';
import '../../core/models/product.dart';
import '../../core/models/sale.dart';
import '../../core/services/database_service.dart';
import '../../core/theme.dart';
import 'invoice_generator.dart';

class SalesEntryScreen extends StatefulWidget {
  final Sale? editSale;
  const SalesEntryScreen({Key? key, this.editSale}) : super(key: key);

  @override
  State<SalesEntryScreen> createState() => _SalesEntryScreenState();
}

class _SalesEntryScreenState extends State<SalesEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  Customer? _selectedCustomer;
  final List<Map<String, dynamic>> _selectedItems = [];
  double _discount = 0.0;
  String _paymentStatus = 'Paid';
  String _deliveryStatus = 'Delivered';
  double _prepaidAmount = 0.0;

  bool _isPrefilled = false;

  @override
  void initState() {
    super.initState();
    if (widget.editSale == null) {
      _addItemLine();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.editSale != null && !_isPrefilled) {
      final db = Provider.of<DatabaseService>(context, listen: false);
      try {
        _selectedCustomer = db.customers.firstWhere((c) => c.id == widget.editSale!.customerId);
      } catch (e) {
        _selectedCustomer = null;
      }
      _discount = widget.editSale!.discount;
      _paymentStatus = widget.editSale!.paymentStatus;
      _deliveryStatus = widget.editSale!.deliveryStatus;
      _prepaidAmount = widget.editSale!.prepaidAmount;

      for (var item in widget.editSale!.items) {
        try {
          final product = db.products.firstWhere((p) => p.id == item.productId);
          _selectedItems.add({
            'product': product,
            'quantity': item.quantity,
            'controller': TextEditingController(text: item.quantity.toString()),
          });
        } catch (e) {
          // Product not found
        }
      }
      if (_selectedItems.isEmpty) _addItemLine();
      _isPrefilled = true;
    }
  }

  void _addItemLine() {
    setState(() {
      _selectedItems.add({
        'product': null,
        'quantity': 1.0,
        'controller': TextEditingController(text: '1'),
      });
    });
  }

  void _removeItemLine(int index) {
    setState(() {
      _selectedItems[index]['controller'].dispose();
      _selectedItems.removeAt(index);
    });
  }

  double _calculateSubtotal() {
    double subtotal = 0.0;
    for (var item in _selectedItems) {
      final Product? p = item['product'];
      final double q = item['quantity'];
      if (p != null) {
        subtotal += p.wholesalePrice * q;
      }
    }
    return subtotal;
  }

  double _calculateTotal() {
    final subtotal = _calculateSubtotal();
    final total = subtotal - _discount;
    return total < 0 ? 0.0 : total;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate() || _selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please correct form errors and select a customer.')),
      );
      return;
    }

    final db = Provider.of<DatabaseService>(context, listen: false);
    final saleItems = <SaleItem>[];

    for (var item in _selectedItems) {
      final Product? p = item['product'];
      final double q = item['quantity'];
      if (p == null) continue;

      // Check stock limit (only if new or adding more quantity)
      if (widget.editSale == null && p.remainingStock < q) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Insufficient stock for ${p.name}! Available: ${p.remainingStock} kg'),
            backgroundColor: AppColors.outOfStockAlert,
          ),
        );
        return;
      }

      saleItems.add(SaleItem(
        productId: p.id,
        productName: p.name,
        packSize: p.packSize,
        quantity: q,
        rate: p.wholesalePrice,
        totalAmount: p.wholesalePrice * q,
      ));
    }

    if (saleItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least 1 product item.')),
      );
      return;
    }

    // Generate Invoice Number
    final count = db.sales.length + 1;
    final year = DateTime.now().year;
    final invoiceNo = 'INV-$year-${count.toString().padLeft(4, '0')}';

    final sale = Sale(
      id: widget.editSale?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      invoiceNumber: widget.editSale?.invoiceNumber ?? invoiceNo,
      customerId: _selectedCustomer!.id,
      customerName: _selectedCustomer!.shopName.isNotEmpty ? _selectedCustomer!.shopName : _selectedCustomer!.ownerName,
      shopName: _selectedCustomer!.shopName,
      sellerId: db.currentUserProfile?.id ?? 'Unknown ID',
      sellerName: db.currentUserProfile?.username.isNotEmpty == true 
          ? db.currentUserProfile!.username 
          : (db.currentUserProfile?.email ?? 'Unknown Seller'),
      sellerRole: db.currentUserProfile?.role,
      items: saleItems,
      totalAmount: _calculateSubtotal(),
      discount: _discount,
      finalAmount: _calculateTotal(),
      paymentStatus: _paymentStatus,
      prepaidAmount: _paymentStatus == 'Prepaid' ? _prepaidAmount : 0.0,
      deliveryStatus: _deliveryStatus,
      dateTime: widget.editSale?.dateTime ?? DateTime.now(),
      phone: _selectedCustomer!.mobileNumber,
      status: widget.editSale?.status ?? 'Active',
      updatedAt: DateTime.now(),
    );

    try {
      if (widget.editSale != null) {
        await db.updateSale(sale);
      } else {
        final success = await db.recordSale(sale);
        if (!success) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to record sale. Check database permissions.'), backgroundColor: Colors.red),
          );
          return;
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
      return;
    }

    // Generate Invoice PDF
    try {
      final file = await InvoiceGenerator.generateInvoice(
                        sale,
                        customerPhone: _selectedCustomer?.mobileNumber ?? '',
                        customerAddress: '${_selectedCustomer?.address ?? ''}, ${_selectedCustomer?.city ?? ''} - ${_selectedCustomer?.district ?? ''}',
                      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.editSale != null ? 'Order updated!' : 'Sale recorded! Invoice $invoiceNo generated.'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );

      // Ask to Share
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Invoice Ready'),
          content: Text('Invoice ${sale.invoiceNumber} has been generated successfully.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Share via WhatsApp'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
                final xFile = XFile(file.path, mimeType: 'application/pdf');
                await Share.shareXFiles([xFile], text: 'Invoice ${sale.invoiceNumber} from Captain Masala and Spices');
              },
            ),
          ],
        ),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sale saved, but failed to generate PDF: $e')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    for (var item in _selectedItems) {
      item['controller'].dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final activeProducts = db.products.where((p) => p.isEnabled).toList();
    final rupeeFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editSale != null ? 'Edit Order' : 'Record Wholesale Sale'),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Customer dropdown
                    DropdownButtonFormField<Customer>(
                      value: _selectedCustomer,
                      decoration: const InputDecoration(
                        labelText: 'Select Customer Shop',
                        prefixIcon: Icon(Icons.storefront),
                      ),
                      items: db.customers.map((c) {
                        return DropdownMenuItem<Customer>(
                          value: c,
                          child: Text('${c.shopName} (${c.district})'),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedCustomer = val),
                      validator: (val) => val == null ? 'Select a customer' : null,
                    ),
                    const SizedBox(height: 20),

                    // Products entry list
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Spice items & Quantities',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        TextButton.icon(
                          onPressed: _addItemLine,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Row'),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),

                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _selectedItems.length,
                      itemBuilder: (ctx, index) {
                        final item = _selectedItems[index];
                        final Product? currentProduct = item['product'];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Product selection
                                Expanded(
                                  flex: 3,
                                  child: Autocomplete<Product>(
                                    initialValue: currentProduct != null ? TextEditingValue(text: '${currentProduct.name} (₹${currentProduct.wholesalePrice.toStringAsFixed(0)})') : const TextEditingValue(),
                                    displayStringForOption: (Product option) => '${option.name} (₹${option.wholesalePrice.toStringAsFixed(0)})',
                                    optionsBuilder: (TextEditingValue textEditingValue) {
                                      if (textEditingValue.text == '') {
                                        return activeProducts;
                                      }
                                      return activeProducts.where((Product option) {
                                        return option.name.toLowerCase().contains(textEditingValue.text.toLowerCase());
                                      });
                                    },
                                    onSelected: (Product selection) {
                                      setState(() {
                                        _selectedItems[index]['product'] = selection;
                                      });
                                    },
                                    fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
                                      return TextFormField(
                                        controller: textEditingController,
                                        focusNode: focusNode,
                                        decoration: const InputDecoration(
                                          labelText: 'Search Product',
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          suffixIcon: Icon(Icons.search, size: 20),
                                        ),
                                        validator: (val) => _selectedItems[index]['product'] == null ? 'Required' : null,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Quantity entry
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: item['controller'],
                                    decoration: const InputDecoration(
                                      labelText: 'Qty (kg)',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    validator: (val) {
                                      if (val == null || double.tryParse(val) == null || double.parse(val) <= 0) {
                                        return 'Invalid Qty';
                                      }
                                      return null;
                                    },
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedItems[index]['quantity'] = double.tryParse(val) ?? 0.0;
                                      });
                                    },
                                  ),
                                ),

                                // Delete row button
                                if (_selectedItems.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppColors.outOfStockAlert),
                                    onPressed: () => _removeItemLine(index),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // Discount and payment status row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Discount Amount (₹)',
                              prefixIcon: Icon(Icons.local_offer_outlined),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (val) {
                              setState(() {
                                _discount = double.tryParse(val) ?? 0.0;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _paymentStatus,
                            decoration: const InputDecoration(
                              labelText: 'Payment Status',
                              prefixIcon: Icon(Icons.payment),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                              DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                              DropdownMenuItem(value: 'Prepaid', child: Text('Prepaid')),
                            ],
                            onChanged: (val) => setState(() => _paymentStatus = val ?? 'Paid'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (_paymentStatus == 'Prepaid') ...[
                          Expanded(
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Prepaid Amount (₹)',
                                prefixIcon: Icon(Icons.currency_rupee),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (val) {
                                if (_paymentStatus == 'Prepaid') {
                                  final amount = double.tryParse(val ?? '');
                                  if (amount == null || amount <= 0) {
                                    return 'Enter valid amount';
                                  }
                                  if (amount > _calculateTotal()) {
                                    return 'Cannot exceed total (${rupeeFormat.format(_calculateTotal())})';
                                  }
                                }
                                return null;
                              },
                              onChanged: (val) {
                                setState(() {
                                  _prepaidAmount = double.tryParse(val) ?? 0.0;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _deliveryStatus,
                            decoration: const InputDecoration(
                              labelText: 'Delivery Status',
                              prefixIcon: Icon(Icons.local_shipping),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Delivered', child: Text('Delivered')),
                              DropdownMenuItem(value: 'Not Delivered', child: Text('Not Delivered')),
                            ],
                            onChanged: (val) => setState(() => _deliveryStatus = val ?? 'Delivered'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom billing summary & submit
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal:', style: TextStyle(color: AppColors.textLight)),
                      Text(rupeeFormat.format(_calculateSubtotal())),
                    ],
                  ),
                  if (_discount > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Discount:', style: TextStyle(color: AppColors.textLight)),
                        Text('- ${rupeeFormat.format(_discount)}', style: const TextStyle(color: AppColors.outOfStockAlert)),
                      ],
                    ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Payable:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      Text(
                        rupeeFormat.format(_calculateTotal()),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _handleSubmit,
                    child: Text(widget.editSale != null ? 'Update Order' : 'Generate Invoice & Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
