import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/models/manufacturing_batch.dart';
import '../../core/services/database_service.dart';
import '../../core/theme.dart';
import '../../core/permissions.dart';
import '../reports/batch_report_pdf_generator.dart';
import '../../core/services/api_config.dart';

class BatchDetailScreen extends StatefulWidget {
  final ManufacturingBatch batch;
  final DatabaseService dbService;

  const BatchDetailScreen({Key? key, required this.batch, required this.dbService}) : super(key: key);

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> {
  late ManufacturingBatch batch;
  bool _isLoadingAllocations = true;
  List<dynamic> _allocations = [];

  @override
  void initState() {
    super.initState();
    batch = widget.batch;
    _fetchAllocations();
  }

  Future<void> _fetchAllocations() async {
    setState(() => _isLoadingAllocations = true);
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/finished-goods/allocations/by-manufacturing-batch/${batch.id}'),
        headers: await widget.dbService.getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          setState(() {
            _allocations = decoded['data'] ?? [];
            _isLoadingAllocations = false;
          });
        } else {
          setState(() => _isLoadingAllocations = false);
        }
      } else {
        setState(() => _isLoadingAllocations = false);
      }
    } catch (e) {
      print('Error fetching allocations: $e');
      setState(() => _isLoadingAllocations = false);
    }
  }

  Future<void> _approveStock(String allocationId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/finished-goods/allocations/$allocationId/approve'),
        headers: await widget.dbService.getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock Approved & Added to Inventory!')));
        setState(() {
          batch.status = 'INVENTORY ADDED';
        });
        _fetchAllocations();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to approve stock')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _returnStock(String allocationId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/finished-goods/allocations/$allocationId/return'),
        headers: await widget.dbService.getAuthHeaders(),
        body: json.encode({'reason': 'Returned from Batch Details screen'}),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Returned for correction')));
        _fetchAllocations();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to return stock')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Batch'),
        content: Text(
          batch.addedToInventory
            ? 'Are you sure you want to delete this manufacturing batch? '
              'This will also revert the inventory additions (subtract the final yield from the stock). '
              'This action cannot be undone.'
            : 'Are you sure you want to delete this manufacturing log? '
              'It has not been added to inventory yet. This action cannot be undone.'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await widget.dbService.deleteManufacturingBatch(batch.id!);
              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Batch deleted successfully')));
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete batch')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showApproveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add to Inventory'),
        content: Text(
          'Are you sure you want to approve this batch?\n\n'
          'This will add ${batch.finalOutputWeight} kg of ${batch.targetProductName} to the Master Product stock.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await widget.dbService.approveManufacturingBatch(batch.id!);
              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Batch approved and added to inventory!')));
                  setState(() {
                    batch.status = 'INVENTORY ADDED';
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to approve batch')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
            child: const Text('Approve & Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false, double size = 14, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: size, color: Colors.grey.shade700)),
        Text(
          value,
          style: TextStyle(
            fontSize: size,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildAllocationsSection() {
    if (_isLoadingAllocations) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_allocations.isEmpty) {
      return const SizedBox.shrink();
    }

    final canApprove = Permissions.isAdmin(widget.dbService.currentUserProfile?.role) ||
        Permissions.isSuperAdmin(widget.dbService.currentUserProfile?.role);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Packaging & Stock Allocation Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ..._allocations.map((alloc) {
          final items = alloc['allocations'] as List;
          final status = alloc['status'] ?? 'PENDING_STOCK_APPROVAL';
          final isPending = status == 'PENDING_STOCK_APPROVAL';
          final isApproved = status == 'APPROVED';
          
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isApproved
                    ? AppColors.primaryGreen.withValues(alpha: 0.5)
                    : isPending
                        ? Colors.orange.shade300
                        : Colors.grey.shade300,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Allocation: ${alloc['allocationNumber'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isApproved
                              ? AppColors.primaryGreen.withValues(alpha: 0.1)
                              : isPending
                                  ? Colors.orange.shade50
                                  : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 10,
                            color: isApproved
                                ? AppColors.primaryGreen
                                : isPending
                                    ? Colors.orange.shade800
                                    : Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  ...items.map((item) {
                    final product = item['productId'];
                    final pName = product != null ? product['name'] : 'Unknown Product';
                    final packSize = product != null ? product['packSize'] : 'N/A';
                    final packets = item['calculatedPacketCount'] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text('$pName ($packSize)')),
                          Text('$packets packets', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }).toList(),
                  const Divider(height: 24),
                  _buildRow('Total Allocated Weight', '${alloc['totalAllocatedKg']} kg', isBold: true),
                  
                  if (isPending && canApprove) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _returnStock(alloc['_id'] ?? alloc['id'] ?? ''),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryRed,
                              side: const BorderSide(color: AppColors.primaryRed),
                            ),
                            child: const Text('Return for Correction', textAlign: TextAlign.center),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _approveStock(alloc['_id'] ?? alloc['id'] ?? ''),
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: const Text('APPROVE STOCK', textAlign: TextAlign.center),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ]
                ],
              ),
            ),
          );
        }).toList(),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final rupeeFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final isSuperAdmin = Permissions.isSuperAdmin(widget.dbService.currentUserProfile?.role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        batch.targetProductName ?? 'Unknown Product',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Date: ${batch.timestamp != null ? DateFormat('dd MMM yyyy, hh:mm a').format(batch.timestamp!) : 'N/A'}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Created by: ${batch.createdByName ?? 'N/A'}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: batch.addedToInventory || batch.status == 'INVENTORY ADDED' ? AppColors.primaryGreen.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    batch.status ?? 'PENDING',
                    style: TextStyle(
                      color: batch.addedToInventory || batch.status == 'INVENTORY ADDED' ? AppColors.primaryGreen : Colors.orange.shade800, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 12
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),

            // Raw Material Section
            const Text('Raw Material', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildRow(
                      'Total Raw Material Cost',
                      rupeeFormat.format(batch.rawMaterials.isNotEmpty
                          ? batch.rawMaterials.fold(0.0, (s, i) => s + (i.amount ?? 0))
                          : (batch.rawMaterialAmount ?? 0)),
                      isBold: true,
                    ),
                    const Divider(height: 24),
                    _buildRow('Total GST', rupeeFormat.format(batch.totalGstAmount)),
                    if (batch.dryingCost > 0) ...[
                      const Divider(height: 24),
                      _buildRow('Drying Process Cost', rupeeFormat.format(batch.dryingCost)),
                    ],
                    if (batch.grindingCost > 0) ...[
                      const Divider(height: 24),
                      _buildRow('Grinding Process Cost', rupeeFormat.format(batch.grindingCost)),
                    ],
                    if (batch.otherCosts.isNotEmpty)
                      ...batch.otherCosts.map((c) {
                        final name = c['name']?.toString() ?? 'Other Cost';
                        final amt = (c['amount'] as num?)?.toDouble() ?? 0.0;
                        return Column(
                          children: [
                            const Divider(height: 24),
                            _buildRow(name, rupeeFormat.format(amt)),
                          ],
                        );
                      }),
                    const Divider(height: 24),
                    _buildRow('Total Cost', rupeeFormat.format(batch.totalCost), isBold: true, color: AppColors.primaryRed),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Processing Metrics
            const Text('Processing Metrics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildRow('Drying Loss', '${batch.dryingLoss.toStringAsFixed(2)} kg'),
                    const Divider(height: 24),
                    _buildRow('Grinding Loss', '${batch.grindingLoss.toStringAsFixed(2)} kg'),
                    const Divider(height: 24),
                    _buildRow('Total Loss', '${batch.totalLoss.toStringAsFixed(2)} kg', isBold: true, color: AppColors.outOfStockAlert),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Final Yield Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                children: [
                  _buildRow('Final Yield', '${batch.finalOutputWeight} kg', isBold: true, size: 18, color: Colors.purple.shade700),
                  const SizedBox(height: 8),
                  _buildRow('Yield Percentage', '${batch.yieldPercentage.toStringAsFixed(2)}%', isBold: true, size: 16, color: Colors.black87),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Render the fetched Allocations section
            _buildAllocationsSection(),

            // Actions
            const Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => BatchReportPdfGenerator.generateAndSharePdf(batch, allocations: _allocations),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Download PDF Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            if (isSuperAdmin && !batch.addedToInventory && batch.status == 'QC_PASSED') ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _showApproveDialog(context),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Approve & Add to Inventory'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ] else if (isSuperAdmin && !batch.addedToInventory && batch.status == 'QC_PENDING') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.hourglass_empty, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(child: Text('⏳ Awaiting Quality Control testing. Cannot approve to inventory.', style: TextStyle(color: Colors.amber))),
                  ],
                ),
              ),
            ] else if (isSuperAdmin && !batch.addedToInventory && batch.status == 'QC_FAILED') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(child: Text('❌ Failed Quality Control. Cannot approve to inventory.', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            ],
            if (isSuperAdmin) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _showDeleteDialog(context),
                icon: const Icon(Icons.delete_outline),
                label: Text(batch.addedToInventory ? 'Delete Batch & Revert Stock' : 'Delete Log'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryRed,
                  side: const BorderSide(color: AppColors.primaryRed),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
