import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/sale.dart';
import '../../../core/theme.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController _discountController = TextEditingController(text: '0');
  final TextEditingController _prepaidAmountController = TextEditingController(text: '0');
  String _paymentStatus = 'Pending';
  String _deliveryStatus = 'Delivered';
  bool _isProcessing = false;

  @override
  void dispose() {
    _discountController.dispose();
    _prepaidAmountController.dispose();
    super.dispose();
  }

  void _checkout() async {
    final cart = Provider.of<CartService>(context, listen: false);
    final db = Provider.of<DatabaseService>(context, listen: false);

    // Sync cart items with latest product data before checkout
    cart.refreshProducts(db.products);

    final activeCustomer = cart.activeCustomer;

    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart is empty')));
      return;
    }
    if (activeCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a customer')));
      return;
    }

    setState(() => _isProcessing = true);

    double discount = double.tryParse(_discountController.text) ?? 0.0;
    double totalAmount = cart.subtotalAmount - discount;
    if (totalAmount < 0) totalAmount = 0;

    final invoiceNumber = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    final saleItems = cart.items.values.map((item) {
      return SaleItem(
        productId: item.product.id,
        productName: item.product.name,
        packSize: item.product.packSize,
        quantity: item.quantity.toDouble(),
        rate: item.product.wholesalePrice,
        totalAmount: item.product.wholesalePrice * item.quantity.toDouble(),
      );
    }).toList();

    final sale = Sale(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      customerId: activeCustomer.id,
      customerName: activeCustomer.shopName.isNotEmpty ? activeCustomer.shopName : activeCustomer.name,
      shopName: activeCustomer.shopName.isNotEmpty ? activeCustomer.shopName : activeCustomer.name,
      sellerId: db.currentUserProfile?.id ?? 'Unknown ID',
      sellerName: db.currentUserProfile?.username.isNotEmpty == true 
          ? db.currentUserProfile!.username 
          : (db.currentUserProfile?.email ?? 'Unknown Seller'),
      sellerRole: db.currentUserProfile?.role,
      items: saleItems,
      totalAmount: totalAmount + discount,
      discount: discount,
      finalAmount: totalAmount,
      paymentStatus: _paymentStatus,
      prepaidAmount: _paymentStatus == 'Prepaid' ? (double.tryParse(_prepaidAmountController.text) ?? 0.0) : 0.0,
      deliveryStatus: db.currentUserProfile?.role == 'delivery' ? _deliveryStatus : 'Delivered',
      dateTime: DateTime.now(),
      invoiceNumber: invoiceNumber,
    );

    try {
      final success = await db.recordSale(sale);
      if (mounted) {
        if (success) {
          cart.clearCart();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sale successful! $invoiceNumber')));
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to record sale. Check database permissions.'),
            backgroundColor: Colors.red,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartService>(context);
    final db = Provider.of<DatabaseService>(context);
    final isDeliveryRole = db.currentUserProfile?.role == 'delivery';

    return Scaffold(
      backgroundColor: AppColors.shopBackground,
      appBar: AppBar(
        title: const Text('Your Cart', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primaryRed,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: cart.items.isEmpty
          ? const Center(child: Text('Your cart is empty', style: TextStyle(fontSize: 18, color: Colors.grey)))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items.values.elementAt(index);
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('₹${item.product.wholesalePrice} x ${item.quantity}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: AppColors.primaryRed),
                                onPressed: () => cart.updateQuantity(item.product.id, item.quantity - 1),
                              ),
                              Text('${item.quantity}', style: const TextStyle(fontSize: 16)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryRed),
                                onPressed: () => cart.updateQuantity(item.product.id, item.quantity + 1),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Autocomplete<Customer>(
                        initialValue: cart.activeCustomer != null ? TextEditingValue(text: cart.activeCustomer!.shopName.isNotEmpty ? cart.activeCustomer!.shopName : cart.activeCustomer!.name) : const TextEditingValue(),
                        displayStringForOption: (Customer option) => option.shopName.isNotEmpty ? option.shopName : option.name,
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text == '') {
                            return db.customers;
                          }
                          return db.customers.where((Customer option) {
                            final label = option.shopName.isNotEmpty ? option.shopName : option.name;
                            return label.toLowerCase().contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        onSelected: (Customer selection) {
                          cart.setActiveCustomer(selection);
                        },
                        fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
                          return TextField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Search Customer',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.search),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _discountController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Discount (₹)', border: OutlineInputBorder()),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(labelText: 'Payment', border: OutlineInputBorder()),
                              value: _paymentStatus,
                              items: const [
                                DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                                DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                                DropdownMenuItem(value: 'Prepaid', child: Text('Prepaid')),
                              ],
                              onChanged: (val) => setState(() => _paymentStatus = val!),
                            ),
                          ),
                        ],
                      ),
                      if (_paymentStatus == 'Prepaid') ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _prepaidAmountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Prepaid Amount (₹)', border: OutlineInputBorder()),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                      if (isDeliveryRole) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Delivery Status', border: OutlineInputBorder()),
                          value: _deliveryStatus,
                          items: const [
                            DropdownMenuItem(value: 'Delivered', child: Text('Delivered')),
                            DropdownMenuItem(value: 'Not Delivered', child: Text('Not Delivered')),
                          ],
                          onChanged: (val) => setState(() => _deliveryStatus = val!),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal:', style: TextStyle(fontSize: 16)),
                          Text('₹${cart.subtotalAmount}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _checkout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryRed,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isProcessing
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Checkout', style: TextStyle(fontSize: 18, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
