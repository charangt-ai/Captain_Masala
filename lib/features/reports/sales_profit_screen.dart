import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/models/product.dart';
import '../../core/models/sale.dart';
import '../../core/services/database_service.dart';
import '../../core/theme.dart';

class SalesProfitScreen extends StatefulWidget {
  const SalesProfitScreen({Key? key}) : super(key: key);

  @override
  State<SalesProfitScreen> createState() => _SalesProfitScreenState();
}

class _SalesProfitScreenState extends State<SalesProfitScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'All Time';
  final List<String> _periods = ['Today', 'This Week', 'This Month', 'All Time'];
  
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final currencyFormatPrecise = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Sale> _getFilteredSales(List<Sale> sales) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return sales.where((sale) {
      if (sale.status == 'Cancelled') return false;

      if (_selectedPeriod == 'Today') {
        return sale.dateTime.isAfter(today);
      } else if (_selectedPeriod == 'This Week') {
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        return sale.dateTime.isAfter(startOfWeek);
      } else if (_selectedPeriod == 'This Month') {
        final startOfMonth = DateTime(now.year, now.month, 1);
        return sale.dateTime.isAfter(startOfMonth);
      }
      return true; // All Time
    }).toList();
  }

  /// Resolve product cost price: returns product.costPrice if set, or estimates based on pack size or 0
  double _getProductCostPrice(String productId, List<Product> products) {
    final prod = products.cast<Product?>().firstWhere(
      (p) => p?.id == productId,
      orElse: () => null,
    );
    if (prod != null) {
      return prod.costPrice;
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final filteredSales = _getFilteredSales(db.sales);

    // Compute Aggregates
    double totalRevenue = 0.0;
    double totalCost = 0.0;
    int totalUnitsSold = 0;

    // Per-product map: productId -> Aggregated info
    final Map<String, _ProductProfitStats> productStats = {};

    for (var sale in filteredSales) {
      for (var item in sale.items) {
        final costPerUnit = _getProductCostPrice(item.productId, db.products);
        final itemRevenue = item.totalAmount;
        final itemCost = costPerUnit * item.quantity;
        final itemProfit = itemRevenue - itemCost;

        totalRevenue += itemRevenue;
        totalCost += itemCost;
        totalUnitsSold += item.quantity.toInt();

        if (!productStats.containsKey(item.productId)) {
          productStats[item.productId] = _ProductProfitStats(
            productId: item.productId,
            productName: item.productName,
            packSize: item.packSize,
            costPrice: costPerUnit,
            sellingPrice: item.rate,
          );
        }

        final stat = productStats[item.productId]!;
        stat.unitsSold += item.quantity;
        stat.totalRevenue += itemRevenue;
        stat.totalCost += itemCost;
        stat.totalProfit += itemProfit;
        // Keep selling price up-to-date
        stat.sellingPrice = item.rate;
        if (stat.costPrice == 0 && costPerUnit > 0) {
          stat.costPrice = costPerUnit;
        }
      }
    }

    final netProfit = totalRevenue - totalCost;
    final marginPercent = totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0.0;

    final sortedProductList = productStats.values.toList()
      ..sort((a, b) => b.totalProfit.compareTo(a.totalProfit));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Sales & Profit Analysis'),
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'By Product'),
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'By Invoices'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: AppColors.textLight),
                const SizedBox(width: 8),
                const Text('Period: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark)),
                const SizedBox(width: 4),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _periods.map((period) {
                        final isSelected = _selectedPeriod == period;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(period),
                            selected: isSelected,
                            selectedColor: AppColors.primaryRed,
                            backgroundColor: Colors.grey.shade100,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textDark,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedPeriod = period;
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Overview KPI Card
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        title: 'Total Sales Revenue',
                        value: currencyFormat.format(totalRevenue),
                        subtitle: '$totalUnitsSold units in ${filteredSales.length} bills',
                        icon: Icons.payments_outlined,
                        color: Colors.blue.shade700,
                        bgColor: Colors.blue.shade50,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricTile(
                        title: 'Cost of Goods (COGS)',
                        value: currencyFormat.format(totalCost),
                        subtitle: 'Product production cost',
                        icon: Icons.shopping_bag_outlined,
                        color: Colors.orange.shade800,
                        bgColor: Colors.orange.shade50,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: netProfit >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: netProfit >= 0 ? Colors.green.shade200 : Colors.red.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            netProfit >= 0 ? Icons.trending_up : Icons.trending_down,
                            color: netProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NET SALES PROFIT',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                  color: netProfit >= 0 ? Colors.green.shade900 : Colors.red.shade900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currencyFormat.format(netProfit),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: netProfit >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: netProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${marginPercent.toStringAsFixed(1)}% Margin',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Product Breakdown
                _buildProductProfitTab(sortedProductList, db),

                // Tab 2: Invoices Breakdown
                _buildInvoicesProfitTab(filteredSales, db),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildProductProfitTab(List<_ProductProfitStats> stats, DatabaseService db) {
    if (stats.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('No product sales recorded in this period.', style: TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: stats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = stats[index];
        final unitProfit = item.sellingPrice - item.costPrice;
        final unitMargin = item.sellingPrice > 0 ? (unitProfit / item.sellingPrice) * 100 : 0.0;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Product Name & Pack Size
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Pack Size: ${item.packSize}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currencyFormat.format(item.totalProfit),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: item.totalProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                        Text(
                          '${unitMargin.toStringAsFixed(1)}% profit',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: item.totalProfit >= 0 ? Colors.green.shade600 : Colors.red.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const Divider(height: 20),

                // Per-unit breakdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoColumn('Cost Price', currencyFormatPrecise.format(item.costPrice)),
                    _buildInfoColumn('Selling Price', currencyFormatPrecise.format(item.sellingPrice)),
                    _buildInfoColumn('Unit Profit', currencyFormatPrecise.format(unitProfit), isHighlight: true),
                    _buildInfoColumn('Units Sold', '${item.unitsSold.toInt()} pkts'),
                  ],
                ),

                const SizedBox(height: 12),

                // Aggregates bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Cost: ${currencyFormat.format(item.totalCost)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      ),
                      Text(
                        'Total Sales: ${currencyFormat.format(item.totalRevenue)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInvoicesProfitTab(List<Sale> sales, DatabaseService db) {
    if (sales.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('No invoice sales recorded in this period.', style: TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sales.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final sale = sales[index];
        final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

        double billCost = 0.0;
        for (var itm in sale.items) {
          final cp = _getProductCostPrice(itm.productId, db.products);
          billCost += cp * itm.quantity;
        }

        final billRevenue = sale.finalAmount;
        final billProfit = billRevenue - billCost;
        final billMargin = billRevenue > 0 ? (billProfit / billRevenue) * 100 : 0.0;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ExpansionTile(
            shape: const Border(),
            leading: CircleAvatar(
              backgroundColor: billProfit >= 0 ? Colors.green.shade50 : Colors.red.shade50,
              child: Icon(
                billProfit >= 0 ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                color: billProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                size: 20,
              ),
            ),
            title: Text(
              sale.shopName.isNotEmpty ? sale.shopName : sale.customerName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              '${sale.invoiceNumber} • ${dateFormat.format(sale.dateTime)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currencyFormat.format(billProfit),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: billProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
                Text(
                  '${billMargin.toStringAsFixed(1)}% profit',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: billProfit >= 0 ? Colors.green.shade600 : Colors.red.shade600,
                  ),
                ),
              ],
            ),
            children: [
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Sale Total: ${currencyFormat.format(billRevenue)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('Total Cost: ${currencyFormat.format(billCost)}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Item Breakdown:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textLight)),
                    const SizedBox(height: 6),
                    ...sale.items.map((item) {
                      final cp = _getProductCostPrice(item.productId, db.products);
                      final itmCost = cp * item.quantity;
                      final itmProfit = item.totalAmount - itmCost;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${item.productName} (${item.packSize}) x ${item.quantity.toInt()}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Sold: ${currencyFormat.format(item.totalAmount)}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'Cost: ${currencyFormat.format(itmCost)} | Profit: ${currencyFormat.format(itmProfit)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: itmProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoColumn(String label, String value, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isHighlight ? AppColors.primaryGreen : AppColors.textDark,
          ),
        ),
      ],
    );
  }
}

class _ProductProfitStats {
  final String productId;
  final String productName;
  final String packSize;
  double costPrice;
  double sellingPrice;
  double unitsSold;
  double totalRevenue;
  double totalCost;
  double totalProfit;

  _ProductProfitStats({
    required this.productId,
    required this.productName,
    required this.packSize,
    required this.costPrice,
    required this.sellingPrice,
    this.unitsSold = 0.0,
    this.totalRevenue = 0.0,
    this.totalCost = 0.0,
    this.totalProfit = 0.0,
  });
}
