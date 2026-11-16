import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/services/api_config.dart';
import '../../core/theme.dart';
import 'raw_material_entry_screen.dart';
import 'raw_material_history_screen.dart';

class RawMaterialStockScreen extends StatefulWidget {
  const RawMaterialStockScreen({Key? key}) : super(key: key);

  @override
  State<RawMaterialStockScreen> createState() => _RawMaterialStockScreenState();
}

class _RawMaterialStockScreenState extends State<RawMaterialStockScreen> {
  List<dynamic> _inventory = [];
  bool _isLoading = true;
  String? _errorMessage;
  double _totalInventoryValuation = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'jwt_token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/inventory/raw-materials'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        List<dynamic> materials = [];
        double valuation = 0.0;

        if (decoded is List) {
          materials = decoded;
          for (var item in materials) {
            final stock = (item['currentStock'] ?? 0.0).toDouble();
            final price = (item['costPerUnit'] ?? item['unitPrice'] ?? 0.0).toDouble();
            valuation += (stock * price);
          }
        } else if (decoded is Map<String, dynamic>) {
          if (decoded['totalValuation'] != null) {
            valuation = (decoded['totalValuation'] as num).toDouble();
          }
          final data = decoded['data'];
          if (data is List) {
            materials = data;
          } else if (data is Map) {
            materials = [data];
          }

          if (decoded['totalValuation'] == null) {
            for (var item in materials) {
              final stock = (item['currentStock'] ?? 0.0).toDouble();
              final price = (item['costPerUnit'] ?? item['unitPrice'] ?? 0.0).toDouble();
              valuation += (stock * price);
            }
          }
        }

        setState(() {
          _inventory = materials;
          _totalInventoryValuation = valuation;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load stock: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raw Material Stock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchInventory,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchInventory,
                        child: const Text('Retry'),
                      )
                    ],
                  ),
                )
              : _inventory.isEmpty
                  ? const Center(child: Text('No raw materials in stock.'))
                  : RefreshIndicator(
                      onRefresh: _fetchInventory,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _inventory.length + 1, // +1 for the Dashboard Valuation Header
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            // Dashboard valuation summary header
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.grey.shade900, Colors.blueGrey.shade800],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  )
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'TOTAL STOCK VALUATION',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '₹ ${_totalInventoryValuation.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          '${_inventory.length}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        const Text(
                                          'Materials',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final item = _inventory[index - 1];
                          final name = item['name'] ?? 'Unknown';
                          final stock = (item['currentStock'] ?? 0.0).toDouble();
                          final unit = item['unit'] ?? 'kg';
                          final unitPrice = (item['costPerUnit'] ?? item['unitPrice'] ?? 0.0).toDouble();
                          final totalItemValuation = stock * unitPrice;
                          
                          // Highlight if low stock (e.g. less than 5)
                          final isLowStock = stock < 5.0;

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RawMaterialHistoryScreen(
                                      materialId: item['_id'],
                                      materialName: name,
                                    ),
                                  ),
                                );
                              },
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundColor: isLowStock ? Colors.red.shade100 : Colors.green.shade100,
                                child: Icon(
                                  Icons.inventory_2,
                                  color: isLowStock ? Colors.red : Colors.green,
                                ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Unit: $unit', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                                    const SizedBox(height: 2),
                                    Text(
                                      unitPrice > 0 ? 'Price: ₹${unitPrice.toStringAsFixed(2)}/$unit' : 'Price: Not Set',
                                      style: TextStyle(
                                        color: unitPrice > 0 ? Colors.blueGrey.shade800 : Colors.grey.shade500,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${stock.toStringAsFixed(1)} $unit left',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isLowStock ? AppColors.outOfStockAlert : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Val: ₹${totalItemValuation.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: Colors.green.shade800,
                                        ),
                                      ),
                                      if (isLowStock)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 2.0),
                                          child: Text(
                                            'Low Stock',
                                            style: TextStyle(color: AppColors.outOfStockAlert, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) async {
                                      if (value == 'edit') {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => RawMaterialEntryScreen(initialData: item),
                                          ),
                                        );
                                        _fetchInventory();
                                      } else if (value == 'delete') {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Delete Material'),
                                            content: Text('Are you sure you want to delete $name?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(ctx, true),
                                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          final storage = const FlutterSecureStorage();
                                          final token = await storage.read(key: 'jwt_token');
                                          await http.delete(
                                            Uri.parse('${ApiConfig.baseUrl}/inventory/raw-materials/${item['_id']}'),
                                            headers: {
                                              if (token != null) 'Authorization': 'Bearer $token',
                                            },
                                          );
                                          _fetchInventory();
                                        }
                                      }
                                    },
                                    itemBuilder: (BuildContext context) => [
                                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RawMaterialEntryScreen()),
          );
          _fetchInventory();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Stock'),
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
      ),
    );
  }
}
