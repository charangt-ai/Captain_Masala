import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/services/api_config.dart';
import '../../core/theme.dart';
import 'raw_material_entry_screen.dart';

class RawMaterialStockScreen extends StatefulWidget {
  const RawMaterialStockScreen({Key? key}) : super(key: key);

  @override
  State<RawMaterialStockScreen> createState() => _RawMaterialStockScreenState();
}

class _RawMaterialStockScreenState extends State<RawMaterialStockScreen> {
  List<dynamic> _inventory = [];
  bool _isLoading = true;
  String? _errorMessage;

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

        if (decoded is List) {
          // Backend returned a plain array
          materials = decoded;
        } else if (decoded is Map<String, dynamic>) {
          // Backend returned a wrapper object — extract 'data'
          final data = decoded['data'];
          if (data is List) {
            materials = data;
          } else if (data is Map) {
            // Single item returned instead of array — wrap it
            materials = [data];
          }
        }

        setState(() {
          _inventory = materials;
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
                        itemCount: _inventory.length,
                        itemBuilder: (context, index) {
                          final item = _inventory[index];
                          final name = item['name'] ?? 'Unknown';
                          final stock = item['currentStock']?.toDouble() ?? 0.0;
                          final unit = item['unit'] ?? 'kg';
                          
                          // Highlight if low stock (e.g. less than 5)
                          final isLowStock = stock < 5.0;

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
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
                              subtitle: Text('Unit: $unit'),
                              trailing: Column(
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
                                  if (isLowStock)
                                    const Text(
                                      'Low Stock',
                                      style: TextStyle(color: AppColors.outOfStockAlert, fontSize: 10),
                                    )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Navigate to add stock screen, and refresh when coming back
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
