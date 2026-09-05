import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/services/database_service.dart';
import '../../core/theme.dart';
import '../../core/permissions.dart';
import 'invoice_generator.dart';
import 'order_detail_screen.dart';

class SalesHistoryScreen extends StatefulWidget {
  final bool isEmbedded;

  const SalesHistoryScreen({Key? key, this.isEmbedded = false}) : super(key: key);

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  String _searchQuery = '';
  String _paymentFilter = 'All';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final db = Provider.of<DatabaseService>(context, listen: false);
      if (db.hasMoreSales && !db.isLoadingMoreSales) {
        db.loadMoreSales();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final rupeeFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final isSuperAdmin = Permissions.isSuperAdmin(db.currentUserProfile?.role);
    final isDeliveryRole = Permissions.isDeliveryOnly(db.currentUserProfile?.role);
    final currentUserId = db.currentUserProfile?.id;

    final filteredSales = db.sales.where((sale) {
      if (!isSuperAdmin && sale.sellerId != currentUserId) {
        return false;
      }

      final matchesSearch = sale.invoiceNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          sale.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          sale.shopName.toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesPayment = _paymentFilter == 'All' || sale.paymentStatus == _paymentFilter;

      return matchesSearch && matchesPayment;
    }).toList();

    String displayShopName(sale) => sale.shopName.isNotEmpty ? sale.shopName : sale.customerName;

    Widget listBody = Column(
      children: [
        // Search & Filter header
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search invoice, customer, shop...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Payment Status:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _paymentFilter == 'All',
                    selectedColor: AppColors.primaryRed,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(color: _paymentFilter == 'All' ? Colors.white : Colors.black87),
                    onSelected: (val) {
                      if (val) setState(() => _paymentFilter = 'All');
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Paid'),
                    selected: _paymentFilter == 'Paid',
                    selectedColor: AppColors.primaryGreen,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(color: _paymentFilter == 'Paid' ? Colors.white : Colors.black87),
                    onSelected: (val) {
                      if (val) setState(() => _paymentFilter = 'Paid');
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Pending'),
                    selected: _paymentFilter == 'Pending',
                    selectedColor: AppColors.lowStockAlert,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(color: _paymentFilter == 'Pending' ? Colors.white : Colors.black87),
                    onSelected: (val) {
                      if (val) setState(() => _paymentFilter = 'Pending');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: filteredSales.isEmpty
              ? const Center(child: Text('No transactions matching filters.'))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filteredSales.length + (db.hasMoreSales ? 1 : 0),
                  itemBuilder: (ctx, idx) {
                    // Load More indicator at the bottom
                    if (idx == filteredSales.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: db.isLoadingMoreSales
                              ? const CircularProgressIndicator()
                              : TextButton.icon(
                                  onPressed: () => db.loadMoreSales(),
                                  icon: const Icon(Icons.expand_more),
                                  label: const Text('Load older orders'),
                                ),
                        ),
                      );
                    }

                    final sale = filteredSales[idx];
                    final isPaid = sale.paymentStatus == 'Paid';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPaid
                              ? AppColors.primaryGreen.withOpacity(0.1)
                              : AppColors.lowStockAlert.withOpacity(0.1),
                          child: Icon(
                            isPaid ? Icons.check_circle : Icons.pending_actions,
                            color: isPaid ? AppColors.primaryGreen : AppColors.lowStockAlert,
                          ),
                        ),
                        title: Text(displayShopName(sale), style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${sale.invoiceNumber} • ${DateFormat('dd MMM yy, hh:mm a').format(sale.dateTime)}'),
                            Text('Handled by: ${sale.sellerName}${sale.sellerRole != null ? ' - ${sale.sellerRole}' : ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              rupeeFormat.format(sale.finalAmount),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              sale.paymentStatus,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isPaid ? AppColors.primaryGreen : AppColors.lowStockAlert,
                              ),
                            ),
                            if (isDeliveryRole)
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrderDetailScreen(sale: sale),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        )
      ],
    );

    if (widget.isEmbedded) {
      return Scaffold(body: listBody);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions log')),
      body: listBody,
    );
  }
}

