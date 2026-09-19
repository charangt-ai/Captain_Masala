import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/manufacturing_batch.dart';
import '../../core/services/database_service.dart';
import '../../core/theme.dart';
import '../../core/permissions.dart';
import '../reports/batch_report_pdf_generator.dart';

class BatchDetailScreen extends StatelessWidget {
  final ManufacturingBatch batch;
  final DatabaseService dbService;

  const BatchDetailScreen({Key? key, required this.batch, required this.dbService}) : super(key: key);

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
              Navigator.pop(ctx); // close dialog
              final success = await dbService.deleteManufacturingBatch(batch.id!);
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Batch deleted successfully')));
                  Navigator.pop(context); // back to list
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
              Navigator.pop(ctx); // close dialog
              final success = await dbService.approveManufacturingBatch(batch.id!);
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Batch approved and added to inventory!')));
                  Navigator.pop(context); // back to list
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

  @override
  Widget build(BuildContext context) {
    final rupeeFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final isSuperAdmin = Permissions.isSuperAdmin(dbService.currentUserProfile?.role);

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
                    color: batch.addedToInventory ? AppColors.primaryGreen.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    batch.status ?? 'PENDING',
                    style: TextStyle(
                      color: batch.addedToInventory ? AppColors.primaryGreen : Colors.orange.shade800, 
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
                    _buildRow('Material Name', batch.rawMaterialName ?? 'N/A'),
                    const Divider(height: 24),
                    _buildRow('Quantity', '${batch.rawMaterialQuantity} kg'),
                    const Divider(height: 24),
                    _buildRow('Amount', rupeeFormat.format(batch.rawMaterialAmount ?? 0)),
                    const Divider(height: 24),
                    _buildRow('GST (${batch.gstPercentage}%)', rupeeFormat.format(batch.totalGstAmount)),
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

            // Actions
            const Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => BatchReportPdfGenerator.generateAndSharePdf(batch),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Download PDF Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            if (isSuperAdmin && !batch.addedToInventory) ...[
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
}
