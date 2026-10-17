import 'package:flutter/material.dart';
import '../shop/category_list_screen.dart';
import '../sales/sales_history_screen.dart';
import '../reports/reports_screen.dart';
import '../auth/profile_screen.dart';
import '../customers/customer_list_screen.dart';
import 'package:provider/provider.dart';
import '../../core/services/database_service.dart';

class SellerMainScreen extends StatefulWidget {
  const SellerMainScreen({Key? key}) : super(key: key);

  @override
  State<SellerMainScreen> createState() => _SellerMainScreenState();
}

class _SellerMainScreenState extends State<SellerMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const CategoryListScreen(isEmbedded: true),
    const SalesHistoryScreen(isEmbedded: true),
    const CustomerListScreen(isEmbedded: true),
    const ReportsScreen(isEmbedded: true),
  ];

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final userName = db.currentUserProfile?.name?.isNotEmpty == true 
        ? db.currentUserProfile!.name 
        : (db.currentUserProfile?.username ?? 'Seller');
    
    // Format the role to display nicely (e.g. "SELLER" or "DELIVERY")
    final roleDisplay = (db.currentUserProfile?.role ?? 'Seller').toUpperCase();

    final List<String> currentTitles = [
      'Welcome, $userName ($roleDisplay)',
      'Sales',
      'Customers',
      'Reports'
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(currentTitles[_currentIndex]),
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
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              color: Colors.amber.shade900,
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Offline Mode — Working with local data',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (db.isReconnecting)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  else
                    TextButton.icon(
                      onPressed: () => db.retryConnection(),
                      icon: const Icon(Icons.refresh, size: 14, color: Colors.white),
                      label: const Text(
                        'Reconnect',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ),
          Expanded(child: _screens[_currentIndex]),
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
          NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Shop'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Sales'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Customers'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Reports'),
        ],
      ),
    );
  }
}
