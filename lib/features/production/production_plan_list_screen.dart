import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/database_service.dart';
import '../../core/models/production_plan.dart';
import 'create_production_plan_screen.dart';

class ProductionPlanListScreen extends StatefulWidget {
  const ProductionPlanListScreen({Key? key}) : super(key: key);

  @override
  State<ProductionPlanListScreen> createState() => _ProductionPlanListScreenState();
}

class _ProductionPlanListScreenState extends State<ProductionPlanListScreen> {
  List<ProductionPlan> _plans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    final db = Provider.of<DatabaseService>(context, listen: false);
    final plans = await db.fetchProductionPlans();
    setState(() {
      _plans = plans;
      _isLoading = false;
    });
  }

  Future<void> _approvePlan(ProductionPlan plan) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final success = await db.approveProductionPlan(plan.id!);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan approved successfully')),
      );
      _loadPlans();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to approve plan')),
      );
    }
  }

  Future<void> _generateFG(ProductionPlan plan) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    // In a real flow, you'd prompt for initialQuantity (e.g. from the QC report) 
    // and manufacturing/expiry dates. For simplicity, we use the planned batch size and default dates.
    final data = {
      'productionPlanId': plan.id,
      'qcId': plan.qualityControlId,
      'manufacturingBatchId': plan.manufacturingBatchId,
      'initialQuantity': plan.plannedBatchSize,
      'manufacturingDate': DateTime.now().toIso8601String(),
      'expiryDate': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
    };

    final success = await db.generateFinishedGoods(data);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finished Goods batch generated!')),
      );
      _loadPlans();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate FG batch')),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'DRAFT': return Colors.grey;
      case 'AWAITING_APPROVAL': return Colors.orange;
      case 'APPROVED': return Colors.blue;
      case 'MATERIALS_ISSUED': return Colors.purple;
      case 'IN_PRODUCTION': return Colors.teal;
      case 'QC_PENDING': return Colors.amber;
      case 'QC_PASSED': return Colors.green;
      case 'QC_FAILED': return Colors.red;
      case 'COMPLETED': return Colors.green[800]!;
      default: return Colors.grey;
    }
  }

  Future<void> _deletePlan(String planId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Plan'),
        content: const Text('Are you sure you want to delete this production plan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      final db = Provider.of<DatabaseService>(context, listen: false);
      final error = await db.deleteProductionPlan(planId);
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan deleted successfully')));
        _loadPlans();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Production Plans'),
        backgroundColor: Colors.red[800],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _plans.isEmpty
              ? const Center(child: Text('No production plans found.'))
              : ListView.builder(
                  itemCount: _plans.length,
                  itemBuilder: (context, index) {
                    final plan = _plans[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ExpansionTile(
                        title: Text(plan.planNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${plan.masterProductName} - ${plan.plannedBatchSize} kg'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (plan.status == 'DRAFT') ...[
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => CreateProductionPlanScreen(editPlan: plan)),
                                  );
                                  if (result == true) _loadPlans();
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                onPressed: () => _deletePlan(plan.id),
                              ),
                            ],
                            Chip(
                              label: Text(plan.status, style: const TextStyle(color: Colors.white, fontSize: 10)),
                              backgroundColor: _getStatusColor(plan.status),
                            ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Priority: ${plan.priority}'),
                                Text('Planned Date: ${plan.plannedDate.toLocal()}'.split(' ')[0]),
                                const SizedBox(height: 10),
                                const Text('Ingredients:', style: TextStyle(fontWeight: FontWeight.bold)),
                                ...plan.plannedIngredients.map((i) {
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(i.rawMaterialName),
                                      Text(
                                        '${i.requiredQuantity.toStringAsFixed(2)} kg (Available: ${i.availableStock.toStringAsFixed(2)} kg)',
                                        style: TextStyle(color: i.isSufficient ? Colors.green : Colors.red),
                                      ),
                                    ],
                                  );
                                }).toList(),
                                if (plan.status == 'DRAFT') ...[
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () => _approvePlan(plan),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                    child: const Text('Approve Plan', style: TextStyle(color: Colors.white)),
                                  ),
                                ] else if (plan.status == 'QC_PASSED') ...[
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () => _generateFG(plan),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                                    child: const Text('Move to Finished Goods', style: TextStyle(color: Colors.white)),
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateProductionPlanScreen()),
          );
          if (result == true) {
            _loadPlans();
          }
        },
        backgroundColor: Colors.red[800],
        child: const Icon(Icons.add),
      ),
    );
  }
}
