import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/database_service.dart';
import '../../core/models/inventory/finished_goods_batch.dart';

class FinishedGoodsScreen extends StatefulWidget {
  const FinishedGoodsScreen({Key? key}) : super(key: key);

  @override
  State<FinishedGoodsScreen> createState() => _FinishedGoodsScreenState();
}

class _FinishedGoodsScreenState extends State<FinishedGoodsScreen> {
  List<FinishedGoodsBatch> _batches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() => _isLoading = true);
    final db = Provider.of<DatabaseService>(context, listen: false);
    final batches = await db.fetchFinishedGoodsBatches();
    setState(() {
      _batches = batches;
      _isLoading = false;
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ACTIVE': return Colors.green;
      case 'DEPLETED': return Colors.grey;
      case 'EXPIRED': return Colors.red;
      case 'RECALLED': return Colors.orange;
      default: return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finished Goods Inventory'),
        backgroundColor: Colors.indigo,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _batches.isEmpty
              ? const Center(child: Text('No finished goods batches found.'))
              : ListView.builder(
                  itemCount: _batches.length,
                  itemBuilder: (context, index) {
                    final batch = _batches[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text('${batch.masterProductName} - ${batch.batchNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Stock: ${batch.currentQuantity} / ${batch.initialQuantity} ${batch.unit}'),
                            Text('Mfg Date: ${batch.manufacturingDate.toLocal()}'.split(' ')[0]),
                            Text('Expiry Date: ${batch.expiryDate.toLocal()}'.split(' ')[0], 
                              style: TextStyle(
                                color: batch.expiryDate.isBefore(DateTime.now()) ? Colors.red : null,
                                fontWeight: batch.expiryDate.isBefore(DateTime.now()) ? FontWeight.bold : null,
                              )
                            ),
                          ],
                        ),
                        trailing: Chip(
                          label: Text(batch.status, style: const TextStyle(color: Colors.white, fontSize: 10)),
                          backgroundColor: _getStatusColor(batch.status),
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
    );
  }
}
