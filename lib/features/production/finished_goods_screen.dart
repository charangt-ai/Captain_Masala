import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/services/database_service.dart';
import '../../core/models/inventory/finished_goods_batch.dart';
import 'packaging_allocation_screen.dart';

class FinishedGoodsScreen extends StatefulWidget {
  const FinishedGoodsScreen({super.key});

  @override
  State<FinishedGoodsScreen> createState() => _FinishedGoodsScreenState();
}

class _FinishedGoodsScreenState extends State<FinishedGoodsScreen> with SingleTickerProviderStateMixin {
  List<FinishedGoodsBatch> _batches = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBatches();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  double get _totalBulkAvailableKg {
    return _batches.fold(0.0, (sum, b) => sum + (b.currentQuantity > 0 ? b.currentQuantity : 0.0));
  }

  int get _batchesReadyToPackCount {
    return _batches.where((b) => b.currentQuantity > 0 && b.status != 'EXPIRED').length;
  }

  int get _depletedBatchesCount {
    return _batches.where((b) => b.currentQuantity <= 0 || b.status == 'DEPLETED').length;
  }

  Color _getStatusColor(FinishedGoodsBatch batch) {
    if (batch.status == 'EXPIRED' || batch.expiryDate.isBefore(DateTime.now())) {
      return Colors.red.shade700;
    }
    if (batch.currentQuantity <= 0 || batch.status == 'DEPLETED') {
      return Colors.blueGrey.shade600;
    }
    if (batch.currentQuantity < batch.initialQuantity) {
      return Colors.amber.shade800;
    }
    return Colors.green.shade700;
  }

  String _getStatusLabel(FinishedGoodsBatch batch) {
    if (batch.status == 'EXPIRED' || batch.expiryDate.isBefore(DateTime.now())) {
      return 'EXPIRED';
    }
    if (batch.currentQuantity <= 0 || batch.status == 'DEPLETED') {
      return 'FULLY PACKED';
    }
    if (batch.currentQuantity < batch.initialQuantity) {
      return 'PARTIALLY PACKED';
    }
    return 'READY TO PACK';
  }

  void _showPackagingHistoryModal(FinishedGoodsBatch batch) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          builder: (context, scrollController) {
            final db = Provider.of<DatabaseService>(context, listen: false);
            return FutureBuilder<List<dynamic>>(
              future: db.fetchAllocationsByFgBatch(batch.id ?? ''),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allocations = snapshot.data ?? [];

                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.inventory, color: Colors.indigo.shade700, size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  batch.masterProductName ?? 'Finished Good',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                Text(
                                  'Batch: ${batch.batchNumber}',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Chip(
                            label: Text(_getStatusLabel(batch), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            backgroundColor: _getStatusColor(batch),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMiniMetric('Total Bulk Yield', '${batch.initialQuantity.toStringAsFixed(1)} kg'),
                            _buildMiniMetric('Remaining Bulk', '${batch.currentQuantity.toStringAsFixed(1)} kg'),
                            _buildMiniMetric('Packed Out', '${(batch.initialQuantity - batch.currentQuantity).toStringAsFixed(1)} kg'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Packaging Allocations History',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      if (allocations.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text('No packaging allocations recorded yet.', style: TextStyle(color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                        )
                      else
                        ...allocations.map((alloc) {
                          final items = (alloc['allocations'] as List?) ?? [];
                          final dateStr = alloc['createdAt'] != null
                              ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(alloc['createdAt']).toLocal())
                              : '';
                          final status = alloc['status'] ?? 'APPROVED';
                          final isApproved = status == 'APPROVED';

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: isApproved ? Colors.green.shade200 : Colors.amber.shade200),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        alloc['allocationNumber'] ?? 'PKG-ALLOC',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Chip(
                                        label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                        backgroundColor: isApproved ? Colors.green.shade700 : Colors.amber.shade800,
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ],
                                  ),
                                  if (dateStr.isNotEmpty)
                                    Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                  const Divider(height: 16),
                                  ...items.map((item) {
                                    final pName = item['productId']?['name'] ?? 'Product';
                                    final pSize = item['packSize'] ?? item['productId']?['packSize'] ?? '';
                                    final count = item['calculatedPacketCount'] ?? 0;
                                    final kg = item['allocatedKg'] ?? 0;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('$pName ($pSize)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                          Text('$count pkts ($kg kg)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.indigo.shade800)),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMiniMetric(String title, String val) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo.shade900)),
        const SizedBox(height: 2),
        Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade800,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.scale_outlined,
                  value: '${_totalBulkAvailableKg.toStringAsFixed(1)} kg',
                  label: 'Bulk Available',
                  color: Colors.white,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.pending_actions,
                  value: '$_batchesReadyToPackCount',
                  label: 'To Package',
                  color: Colors.amberAccent,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.check_circle_outline,
                  value: '$_depletedBatchesCount',
                  label: 'Fully Packed',
                  color: Colors.lightGreenAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.indigo.shade100, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildBatchCard(FinishedGoodsBatch batch) {
    final hasBulkRemaining = batch.currentQuantity > 0;
    final isExpired = batch.expiryDate.isBefore(DateTime.now());
    final isFullyPacked = batch.currentQuantity <= 0 || batch.status == 'DEPLETED';

    final percentRemaining = batch.initialQuantity > 0 
        ? (batch.currentQuantity / batch.initialQuantity).clamp(0.0, 1.0)
        : 0.0;
    final percentPacked = (1.0 - percentRemaining) * 100;

    final dateFormat = DateFormat('dd MMM yyyy');
    final mfgStr = dateFormat.format(batch.manufacturingDate.toLocal());
    final expStr = dateFormat.format(batch.expiryDate.toLocal());

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: hasBulkRemaining ? Colors.indigo.shade100 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (hasBulkRemaining && !isExpired) {
            _navigateToAllocation(batch);
          } else {
            _showPackagingHistoryModal(batch);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Title + Chip
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          batch.masterProductName ?? 'Finished Good',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          batch.batchNumber,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(
                      _getStatusLabel(batch),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: _getStatusColor(batch),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentRemaining,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isFullyPacked ? Colors.blueGrey.shade400 : (percentRemaining < 0.3 ? Colors.orange : Colors.indigo.shade700),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Quantities
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.black87, fontSize: 13),
                      children: [
                        const TextSpan(text: 'Bulk Available: '),
                        TextSpan(
                          text: '${batch.currentQuantity.toStringAsFixed(1)} kg',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: hasBulkRemaining ? Colors.indigo.shade900 : Colors.grey.shade700,
                          ),
                        ),
                        TextSpan(
                          text: ' / ${batch.initialQuantity.toStringAsFixed(1)} kg',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${percentPacked.toStringAsFixed(0)}% Packed',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isFullyPacked ? Colors.green.shade700 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const Divider(height: 18),

              // Dates & Action Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text('Mfg: $mfgStr', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.event_busy, size: 12, color: isExpired ? Colors.red : Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'Exp: $expStr',
                            style: TextStyle(
                              fontSize: 11,
                              color: isExpired ? Colors.red : Colors.grey.shade700,
                              fontWeight: isExpired ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (hasBulkRemaining && !isExpired)
                    ElevatedButton.icon(
                      onPressed: () => _navigateToAllocation(batch),
                      icon: const Icon(Icons.shopping_bag_outlined, size: 14, color: Colors.white),
                      label: const Text('Pack to Pouches', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => _showPackagingHistoryModal(batch),
                      icon: Icon(Icons.history, size: 14, color: Colors.indigo.shade800),
                      label: Text('Pack History', style: TextStyle(fontSize: 12, color: Colors.indigo.shade800, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(color: Colors.indigo.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToAllocation(FinishedGoodsBatch batch) async {
    final shouldRefresh = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PackagingAllocationScreen(batch: batch),
      ),
    );
    if (shouldRefresh == true) {
      _loadBatches();
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableBatches = _batches.where((b) => b.currentQuantity > 0 && !b.expiryDate.isBefore(DateTime.now())).toList();
    final packedBatches = _batches.where((b) => b.currentQuantity <= 0 || b.status == 'DEPLETED').toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Finished Goods & Packaging'),
        backgroundColor: Colors.indigo.shade800,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBatches,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: 'Ready to Pack (${availableBatches.length})'),
            Tab(text: 'Fully Packed (${packedBatches.length})'),
            Tab(text: 'All Batches (${_batches.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryHeader(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Ready to Pack
                      _buildBatchList(
                        availableBatches,
                        emptyMessage: 'No bulk batches currently waiting for packaging.',
                        emptyIcon: Icons.check_circle_outline,
                      ),
                      // Tab 2: Fully Packed
                      _buildBatchList(
                        packedBatches,
                        emptyMessage: 'No fully packaged batches yet.',
                        emptyIcon: Icons.inventory_2_outlined,
                      ),
                      // Tab 3: All
                      _buildBatchList(
                        _batches,
                        emptyMessage: 'No finished goods batches found in the database.',
                        emptyIcon: Icons.inbox_outlined,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBatchList(List<FinishedGoodsBatch> list, {required String emptyMessage, required IconData emptyIcon}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBatches,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: list.length,
        itemBuilder: (context, index) {
          return _buildBatchCard(list[index]);
        },
      ),
    );
  }
}
