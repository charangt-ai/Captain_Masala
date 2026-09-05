import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/services/database_service.dart';
import '../../core/theme.dart';
import '../../core/permissions.dart';
import '../products/product_list_screen.dart';
import '../customers/customer_list_screen.dart';
import '../sales/sales_entry_screen.dart';
import '../sales/sales_history_screen.dart';
import '../stock/stock_entry_screen.dart';
import '../reports/reports_screen.dart';
import '../auth/profile_screen.dart';
import '../shop/category_list_screen.dart';
import '../users/manage_users_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../seller/seller_main_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  final List<String> _titles = [
    'Seller Dashboard',
    'Product Catalog',
    'Customers',
    'Sales History',
    'Reports'
  ];

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);

    // Protection for Dashboard access
    if (db.currentUserProfile != null && Permissions.isSeller(db.currentUserProfile?.role)) {
      return const SellerMainScreen();
    }

    // Dynamic screens mapping
    final List<Widget> screens = [
      _buildDashboardHome(context, db),
      const ProductListScreen(isEmbedded: true),
      const CustomerListScreen(isEmbedded: true),
      const SalesHistoryScreen(isEmbedded: true),
      const ReportsScreen(isEmbedded: true),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            tooltip: 'Profile',
          ),
        ],
      ),
      body: Column(
        children: [
          if (db.isOfflineMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.orange.shade800,
              child: const Text(
                '⚠️ Offline Mode — Data may be outdated. Connect to server.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(child: screens[_currentIndex]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Products'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Customers'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Sales'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Reports'),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CategoryListScreen()),
                );
              },
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('New Sale'),
            )
          : null,
    );
  }

  Widget _buildDashboardHome(BuildContext context, DatabaseService db) {
    // Math stats
    final totalProducts = db.products.length;
    final totalCustomers = db.customers.length;
    final availableStock = db.products.fold<double>(0, (prev, element) => prev + element.remainingStock);

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);

    final todaySales = db.sales
        .where((s) => s.dateTime.isAfter(todayStart))
        .fold<double>(0, (prev, s) => prev + s.finalAmount);
    
    final monthlySales = db.sales
        .where((s) => s.dateTime.isAfter(monthStart))
        .fold<double>(0, (prev, s) => prev + s.finalAmount);

    final lowStockProducts = db.products.where((p) => p.remainingStock < 50.0).toList();

    final rupeeFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Welcome Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryRed, Color(0xFFE53935)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pure Spices... Perfect Taste!',
                        style: TextStyle(color: AppColors.goldAccent, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Welcome, ${db.currentUserProfile?.name?.isNotEmpty == true ? db.currentUserProfile!.name : (db.currentUserProfile?.username ?? 'Admin')} (${(db.currentUserProfile?.role ?? 'Admin').replaceAll('_', ' ').toUpperCase()})',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.restaurant_menu, color: Colors.white.withOpacity(0.3), size: 48),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stat Cards Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _buildStatCard(
                context,
                title: 'Total Products',
                value: '$totalProducts Items',
                icon: Icons.inventory_2,
                color: AppColors.primaryRed,
              ),
              _buildStatCard(
                context,
                title: 'Total Customers',
                value: '$totalCustomers Shops',
                icon: Icons.people,
                color: AppColors.primaryGreen,
              ),
              _buildStatCard(
                context,
                title: 'Stock Available',
                value: '${availableStock.toStringAsFixed(0)} kg',
                icon: Icons.storage,
                color: Colors.blue.shade700,
              ),
              _buildStatCard(
                context,
                title: "Today's Revenue",
                value: rupeeFormat.format(todaySales),
                icon: Icons.today,
                color: AppColors.darkGold,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Monthly Sales Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                    radius: 28,
                    child: const Icon(Icons.analytics, color: AppColors.primaryGreen, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Month Sales',
                          style: TextStyle(color: AppColors.textLight, fontSize: 13),
                        ),
                        Text(
                          rupeeFormat.format(monthlySales),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Low Stock Alerts Card
          if (lowStockProducts.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lowStockAlert.withOpacity(0.1),
                border: Border.all(color: AppColors.lowStockAlert.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.lowStockAlert),
                      const SizedBox(width: 8),
                      Text(
                        'Low Stock Alert (${lowStockProducts.length} items)',
                        style: const TextStyle(color: AppColors.lowStockAlert, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const StockEntryScreen()),
                          );
                        },
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                        child: const Text('Replenish', style: TextStyle(color: AppColors.primaryRed)),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...lowStockProducts.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                            Text(
                              '${p.remainingStock.toStringAsFixed(1)} kg left',
                              style: TextStyle(
                                color: p.remainingStock == 0 ? AppColors.outOfStockAlert : AppColors.lowStockAlert,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        // Seller Identity Section
        if (db.currentUserProfile != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primaryRed, Colors.redAccent]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, color: AppColors.primaryRed),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        db.currentUserProfile!.email,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Role: ${db.currentUserProfile!.role.toUpperCase()}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  tooltip: 'Edit Profile',
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                  },
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),

          // Quick Actions Row
          const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (Permissions.isSuperAdmin(db.currentUserProfile?.role))
                  _buildActionButton(context, Icons.security, 'Manage Sellers', () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManageUsersScreen()));
                  }),
                _buildActionButton(context, Icons.person_add, 'Add Shop', () {
                  setState(() {
                    _currentIndex = 2; // Route to Customer list
                  });
                }),
                _buildActionButton(context, Icons.shopping_basket, 'Replenish Stock', () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StockEntryScreen()));
                }),
                _buildActionButton(context, Icons.assessment, 'Monthly Reports', () {
                  setState(() {
                    _currentIndex = 4; // Route to Reports
                  });
                }),
                _buildActionButton(context, Icons.price_change, 'Adjust Prices', () {
                  setState(() {
                    _currentIndex = 1; // Route to Products
                  });
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Recent Transactions List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Sales', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentIndex = 3; // Route to Sales list
                  });
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          db.sales.isEmpty
              ? const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No transactions recorded yet')),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: db.sales.length > 5 ? 5 : db.sales.length,
                  itemBuilder: (ctx, idx) {
                    final sale = db.sales[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: sale.paymentStatus == 'Paid'
                              ? AppColors.primaryGreen.withOpacity(0.1)
                              : AppColors.lowStockAlert.withOpacity(0.1),
                          child: Icon(
                            sale.paymentStatus == 'Paid' ? Icons.check_circle : Icons.pending,
                            color: sale.paymentStatus == 'Paid' ? AppColors.primaryGreen : AppColors.lowStockAlert,
                          ),
                        ),
                        title: Text(sale.shopName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${sale.invoiceNumber} • ${DateFormat('dd MMM yy, hh:mm a').format(sale.dateTime)}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              rupeeFormat.format(sale.finalAmount),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark),
                            ),
                            Text(
                              sale.paymentStatus,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: sale.paymentStatus == 'Paid' ? AppColors.primaryGreen : AppColors.lowStockAlert,
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, {required String title, required String value, required IconData icon, required Color color}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.1),
                  radius: 18,
                  child: Icon(icon, color: color, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12, bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primaryRed, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
