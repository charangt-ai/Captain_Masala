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

        if (!mounted) return;
        setState(() {
          _products = filteredProducts;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Failed to load products: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
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
    final lower = packSizeStr.toLowerCase().trim();

    // 1. Compound master bags like "50g-1kg", "50g - 1 kg bag", "50 gram - 1 kg bag"
    if (lower.contains('50') && (lower.contains('1kg') || lower.contains('1 kg') || lower.contains('bag'))) {
      return 1.0;
    }

    // 2. Explicit KG patterns (e.g. "1kg", "1 kg", "2.5 kg")
    final kgMatch = RegExp(r'([0-9.]+)\s*kg').firstMatch(lower);
    if (kgMatch != null) {
      return double.tryParse(kgMatch.group(1) ?? '') ?? 1.0;
    }

    // 3. Gram patterns (e.g. "500 g", "500g", "50 grams", "250gm")
    final gMatch = RegExp(r'([0-9.]+)\s*(?:grams|gram|gm|g)').firstMatch(lower);
    if (gMatch != null) {
      final grams = double.tryParse(gMatch.group(1) ?? '') ?? 0.0;
      return grams / 1000.0;
    }

    return 0.0;
  }

  void _onReviewPressed() {
    if (_totalAllocated > widget.batch.currentQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot allocate more than available bulk quantity (${widget.batch.currentQuantity} kg).')),
      );
      return;
    }

    if (_totalAllocated <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please allocate some quantity before proceeding.')),
      );
      return;
    }

    final List<Map<String, dynamic>> activeItems = [];
    int totalPackets = 0;
    for (var p in _products) {
      final id = p['_id'] ?? p['id'];
      final controller = _controllers[id];
      if (controller == null) continue;
      final val = double.tryParse(controller.text) ?? 0.0;
      if (val > 0) {
        final packSizeStr = p['packSize'] ?? '0g';
        final sizeInKg = _getSizeInKg(packSizeStr);
        final count = sizeInKg > 0 ? (val / sizeInKg).floor() : 0;
        totalPackets += count;
        activeItems.add({
          'productId': id,
          'productName': p['name'] ?? packSizeStr,
          'packSize': packSizeStr,
          'allocatedKg': val,
          'packetCount': count,
        });
      }
    }

    _showApprovalReviewSheet(activeItems, totalPackets);
  }

  void _showApprovalReviewSheet(List<Map<String, dynamic>> activeItems, int totalPackets) {
    final double remaining = widget.batch.currentQuantity - _totalAllocated;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 16,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.verified_outlined, color: Colors.green.shade700, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Stock Approval & Review',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${widget.batch.masterProductName ?? 'Product'} | Batch ${widget.batch.batchNumber}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Summary Stats Row
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildModalStat('Available Bulk', '${widget.batch.currentQuantity.toStringAsFixed(2)} KG', Colors.black87),
                    Container(height: 30, width: 1, color: Colors.grey.shade300),
                    _buildModalStat('Allocated', '${_totalAllocated.toStringAsFixed(2)} KG', AppColors.primaryRed),
                    Container(height: 30, width: 1, color: Colors.grey.shade300),
                    _buildModalStat('Remaining', '${remaining.toStringAsFixed(2)} KG', Colors.green.shade700),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Breakdown Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('PACKAGE BREAKDOWN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.grey)),
                  Text('Total: $totalPackets Packets', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                ],
              ),
              const SizedBox(height: 8),

              // Items List
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: activeItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = activeItems[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item['packSize'],
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item['allocatedKg'].toStringAsFixed(2)} KG Powder', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                                Text('Yield: ${item['packetCount']} units', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Text(
                              '${item['packetCount']} Pkts',
                              style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Information callout
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50.withAlpha(128),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Approving will immediately credit packets into retail stock and deduct bulk powder.',
                        style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Primary Action: APPROVE STOCK NOW
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _submitAllocation(activeItems, autoApprove: true);
                },
                icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                label: const Text(
                  'APPROVE STOCK NOW',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
              const SizedBox(height: 8),

              // Secondary Action: SAVE AS PENDING
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _submitAllocation(activeItems, autoApprove: false);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(color: Colors.grey.shade400),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save as Pending (Approve Later)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Future<void> _submitAllocation(List<Map<String, dynamic>> items, {required bool autoApprove}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'jwt_token');

      // 1. Submit allocation
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/finished-goods/${widget.batch.id}/allocate'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'allocations': items.map((i) => {
            'productId': i['productId'],
            'allocatedKg': i['allocatedKg'],
          }).toList(),
        }),
      );

      if (response.statusCode != 201) {
        final decoded = json.decode(response.body);
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Allocation failed: ${decoded['message'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final decoded = json.decode(response.body);
      final allocData = decoded['data'];
      final allocId = allocData != null ? (allocData['_id'] ?? allocData['id']) : null;

      if (autoApprove && allocId != null) {
        // 2. Automatically approve allocation immediately
        final approveResponse = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/finished-goods/allocations/$allocId/approve'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        );

        if (approveResponse.statusCode == 200) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text('Stock Approved! Retail inventory updated successfully.')),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.pop(context, true); // Return true to signal refresh
          return;
        } else {
          final approveDecoded = json.decode(approveResponse.body);
          if (!mounted) return;
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Allocation saved, but approval failed: ${approveDecoded['message'] ?? 'Error'}'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context, true);
          return;
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Packaging allocation saved and pending stock approval.'),
            backgroundColor: Colors.blue,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
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
                                      child: Text(
                                        packSizeStr.toLowerCase().replaceAll(' ', '') == '50g-1kg' ? '50g (1kg Bag)' : packSizeStr,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
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
                      ElevatedButton.icon(
                        onPressed: isError ? null : _onReviewPressed,
                        icon: const Icon(Icons.assignment_turned_in_outlined, color: Colors.white),
                        label: const Text(
                          'REVIEW & APPROVE PACKAGING',
                          style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
