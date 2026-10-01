import 'package:flutter/material.dart';
import 'raw_material_stock_screen.dart';

class InventoryDashboardScreen extends StatelessWidget {
  const InventoryDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raw Material Inventory'),
        backgroundColor: Colors.red[800], // Captain Masala theme color
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _buildDashboardCard(
            context,
            'Raw Material Master',
            Icons.category,
            Colors.orange,
            () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RawMaterialStockScreen()));
            },
          ),
          _buildDashboardCard(
            context,
            'Supplier Management',
            Icons.local_shipping,
            Colors.blue,
            () {
              // Navigate to Suppliers
            },
          ),
          _buildDashboardCard(
            context,
            'Purchase Entry (Inward)',
            Icons.add_shopping_cart,
            Colors.green,
            () {
              // Navigate to Purchases
            },
          ),
          _buildDashboardCard(
            context,
            'Stock Ledger',
            Icons.inventory,
            Colors.teal,
            () {
              // Navigate to Stock Ledger
            },
          ),
          _buildDashboardCard(
            context,
            'Material Issue (Outward)',
            Icons.outbox,
            Colors.deepPurple,
            () {
              // Navigate to Material Issue
            },
          ),
          _buildDashboardCard(
            context,
            'Manufacturing Yield',
            Icons.factory,
            Colors.brown,
            () {
              // Navigate to Manufacturing process
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(
      BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
