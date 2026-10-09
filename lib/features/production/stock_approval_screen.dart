import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/services/api_config.dart';
import '../../core/theme.dart';

class StockApprovalScreen extends StatefulWidget {
  const StockApprovalScreen({Key? key}) : super(key: key);

  @override
  State<StockApprovalScreen> createState() => _StockApprovalScreenState();
}

class _StockApprovalScreenState extends State<StockApprovalScreen> {
  List<dynamic> _pendingAllocations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPendingAllocations();
  }

  Future<void> _fetchPendingAllocations() async {
    setState(() => _isLoading = true);
    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'jwt_token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/finished-goods/allocations/pending'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        setState(() {
          _pendingAllocations = decoded['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showError('Failed to load pending allocations');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
  }

  Future<void> _approveAllocation(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Stock'),
        content: const Text('Are you sure you want to approve this allocation? This will deduct bulk stock and add packet stock.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('APPROVE', style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'jwt_token');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/finished-goods/allocations/$id/approve'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock approved successfully!'), backgroundColor: Colors.green));
        _fetchPendingAllocations();
      } else {
        final decoded = json.decode(response.body);
        _showError(decoded['message'] ?? 'Failed to approve');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showError('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _returnAllocation(String id) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Return for Correction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for returning this allocation:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()),
              maxLines: 2,
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('RETURN', style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );

    if (confirm != true) return;
    if (reasonController.text.trim().isEmpty) {
      _showError('Reason is required to return an allocation.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'jwt_token');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/finished-goods/allocations/$id/return'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode({'reason': reasonController.text.trim()}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Allocation returned for correction.'), backgroundColor: Colors.orange));
        _fetchPendingAllocations();
      } else {
        final decoded = json.decode(response.body);
        _showError(decoded['message'] ?? 'Failed to return');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showError('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Approvals'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchPendingAllocations)
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _pendingAllocations.isEmpty
          ? const Center(child: Text('No pending stock approvals.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _pendingAllocations.length,
              itemBuilder: (context, index) {
                final alloc = _pendingAllocations[index];
                final batch = alloc['finishedGoodsBatchId'];
                final allocations = alloc['allocations'] as List;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(alloc['allocationNumber'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(12)),
                              child: const Text('PENDING', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                            )
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Batch: ${batch != null ? batch['batchNumber'] : 'N/A'}'),
                        const SizedBox(height: 8),
                        const Divider(),
                        const Text('Proposed Allocations:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...allocations.map((item) {
                          final p = item['productId'];
                          final pName = p != null ? p['name'] : 'Unknown';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('$pName (${item['packSize']})'),
                                Text('${item['calculatedPacketCount']} packets (${item['allocatedKg']} kg)', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        }).toList(),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Allocated:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('${alloc['totalAllocatedKg']} kg', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _returnAllocation(alloc['_id']), 
                              icon: const Icon(Icons.undo, color: Colors.orange), 
                              label: const Text('RETURN', style: TextStyle(color: Colors.orange))
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: () => _approveAllocation(alloc['_id']),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              icon: const Icon(Icons.check, color: Colors.white),
                              label: const Text('APPROVE', style: TextStyle(color: Colors.white)),
                            )
                          ],
                        )
                      ],
                    ),
                  )
                );
              },
            )
    );
  }
}
