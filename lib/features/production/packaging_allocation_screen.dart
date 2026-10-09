import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/services/api_config.dart';
import '../../core/theme.dart';
import '../../core/models/inventory/finished_goods_batch.dart';

class PackagingAllocationScreen extends StatefulWidget {
  final FinishedGoodsBatch batch;

  const PackagingAllocationScreen({Key? key, required this.batch}) : super(key: key);

  @override
  State<PackagingAllocationScreen> createState() => _PackagingAllocationScreenState();
}

class _PackagingAllocationScreenState extends State<PackagingAllocationScreen> {
  List<dynamic> _products = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Map to hold controllers for each product ID
  final Map<String, TextEditingController> _controllers = {};
  
  // Track allocated amounts
  double _totalAllocated = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'jwt_token');

      // Fetch products that belong to this master product
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/products'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final allProducts = json.decode(response.body) as List;
        
        final filteredProducts = allProducts.where((p) => p['masterProductId'] == widget.batch.masterProductId).toList();

        for (var p in filteredProducts) {
          final controller = TextEditingController(text: '');
          controller.addListener(_calculateTotal);
          _controllers[p['_id'] ?? p['id']] = controller;
        }

        setState(() {
          _products = filteredProducts;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load products: ${response.statusCode}';
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

  void _calculateTotal() {
    double total = 0;
    for (var controller in _controllers.values) {
      final val = double.tryParse(controller.text) ?? 0.0;
      total += val;
    }
    setState(() {
      _totalAllocated = total;
    });
  }

  double _getSizeInKg(String packSizeStr) {
    final ps = packSizeStr.toLowerCase().trim();
    
    // Extract only the numbers/decimals from the string
    final numberString = ps.replaceAll(RegExp(r'[^0-9.]'), '');
    final number = double.tryParse(numberString) ?? 0.0;
    
    if (ps.contains('kg')) {
      return number;
    } else if (ps.contains('g') || ps.contains('gram')) {
      return number / 1000.0;
    }
    return 0.0;
  }

  Future<void> _savePackaging() async {
    if (_totalAllocated > widget.batch.currentQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot allocate more than available bulk quantity (${widget.batch.currentQuantity} kg).')),
      );
      return;
    }

    if (_totalAllocated <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please allocate some quantity before saving.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'jwt_token');

      final List<Map<String, dynamic>> allocations = [];
      for (var entry in _controllers.entries) {
        final val = double.tryParse(entry.value.text) ?? 0.0;
        if (val > 0) {
          allocations.add({
            'productId': entry.key,
            'allocatedKg': val,
          });
        }
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/finished-goods/${widget.batch.id}/allocate'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'allocations': allocations,
        }),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Packaging allocation submitted for stock approval!')),
        );
        Navigator.pop(context, true); // Return true to signal refresh
      } else {
        final decoded = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${decoded['message']}')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double remaining = widget.batch.currentQuantity - _totalAllocated;
    final bool isError = remaining < 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Packaging Allocation'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Batch Info Card
                      Card(
                        elevation: 3,
                        color: Colors.blue.shade50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.batch.masterProductName ?? 'Unknown Product', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text('Batch No: ${widget.batch.batchNumber}', style: const TextStyle(fontSize: 14)),
                              Text('Manufactured Qty: ${widget.batch.initialQuantity.toStringAsFixed(2)} KG', style: const TextStyle(fontSize: 14)),
                              const Divider(),
                              Text('Available for Packing: ${widget.batch.currentQuantity.toStringAsFixed(2)} KG', 
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Products List
                      const Text('Allocate Packaging:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      
                      if (_products.isEmpty)
                        const Center(child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('No retail products mapped to this Master Product. Create them in Products first.'),
                        ))
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final p = _products[index];
                            final id = p['_id'] ?? p['id'];
                            final packSizeStr = p['packSize'] ?? '0g';
                            final sizeInKg = _getSizeInKg(packSizeStr);
                            
                            final controller = _controllers[id]!;
                            final allocatedVal = double.tryParse(controller.text) ?? 0.0;
                            final packetCount = sizeInKg > 0 ? (allocatedVal / sizeInKg).floor() : 0;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(packSizeStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: TextField(
                                        controller: controller,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                          labelText: 'Allocate (KG)',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          const Text('Packets', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                          Text('$packetCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                      const SizedBox(height: 24),
                      
                      // Summary Section
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total Allocated:', style: TextStyle(fontSize: 16)),
                                  Text('${_totalAllocated.toStringAsFixed(2)} KG', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Remaining Bulk:', style: TextStyle(fontSize: 16)),
                                  Text('${remaining.toStringAsFixed(2)} KG', 
                                    style: TextStyle(
                                      fontSize: 18, 
                                      fontWeight: FontWeight.bold, 
                                      color: isError ? Colors.red : Colors.green,
                                    )
                                  ),
                                ],
                              ),
                              if (isError)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: Text('❌ INSUFFICIENT QUANTITY. Please reduce allocated quantity.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                )
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: isError ? null : _savePackaging,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('SAVE & SUBMIT FOR APPROVAL', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
    );
  }
}
