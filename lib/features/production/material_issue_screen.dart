import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/database_service.dart';
import '../../core/models/production_plan.dart';

class MaterialIssueScreen extends StatefulWidget {
  const MaterialIssueScreen({Key? key}) : super(key: key);

  @override
  State<MaterialIssueScreen> createState() => _MaterialIssueScreenState();
}

class _MaterialIssueScreenState extends State<MaterialIssueScreen> {
  List<ProductionPlan> _approvedPlans = [];
  ProductionPlan? _selectedPlan;
  bool _isLoading = true;
  bool _isIssuing = false;

  final Map<String, TextEditingController> _issuedQtyControllers = {};

  @override
  void initState() {
    super.initState();
    _loadApprovedPlans();
  }

  @override
  void dispose() {
    for (var controller in _issuedQtyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadApprovedPlans() async {
    setState(() => _isLoading = true);
    final db = Provider.of<DatabaseService>(context, listen: false);
    final allPlans = await db.fetchProductionPlans();
    setState(() {
      _approvedPlans = allPlans.where((p) => p.status == 'APPROVED').toList();
      _isLoading = false;
    });
  }

  void _onPlanSelected(ProductionPlan? plan) {
    setState(() {
      _selectedPlan = plan;
      _issuedQtyControllers.clear();
      if (plan != null) {
        for (var ingredient in plan.plannedIngredients) {
          _issuedQtyControllers[ingredient.rawMaterialId ?? ''] = 
              TextEditingController(text: ingredient.requiredQuantity.toStringAsFixed(2));
        }
      }
    });
  }

  Future<void> _issueMaterials() async {
    if (_selectedPlan == null) return;
    
    setState(() => _isIssuing = true);
    final db = Provider.of<DatabaseService>(context, listen: false);
    
    final items = _selectedPlan!.plannedIngredients.map((ingredient) {
      final id = ingredient.rawMaterialId ?? '';
      final issuedQtyStr = _issuedQtyControllers[id]?.text ?? '0';
      return {
        'rawMaterialId': id,
        'requestedQuantity': ingredient.requiredQuantity,
        'issuedQuantity': double.tryParse(issuedQtyStr) ?? 0.0,
      };
    }).toList();

    final issueData = {
      'productionPlanId': _selectedPlan!.id,
      'items': items,
      'notes': 'Issued from mobile app',
    };

    final success = await db.issueMaterials(issueData);
    setState(() => _isIssuing = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Materials issued successfully!')),
      );
      _selectedPlan = null;
      _loadApprovedPlans();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to issue materials. Check stock levels.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Issue Materials'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<ProductionPlan>(
                    decoration: const InputDecoration(
                      labelText: 'Select Approved Production Plan',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedPlan,
                    items: _approvedPlans.map((p) {
                      return DropdownMenuItem<ProductionPlan>(
                        value: p,
                        child: Text('${p.planNumber} - ${p.masterProductName}'),
                      );
                    }).toList(),
                    onChanged: _onPlanSelected,
                  ),
                  const SizedBox(height: 16),
                  if (_selectedPlan != null) ...[
                    const Text(
                      'Materials to Issue:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _selectedPlan!.plannedIngredients.length,
                        itemBuilder: (context, index) {
                          final ingredient = _selectedPlan!.plannedIngredients[index];
                          final id = ingredient.rawMaterialId ?? '';
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(ingredient.rawMaterialName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text('Req: ${ingredient.requiredQuantity.toStringAsFixed(2)} kg'),
                                        Text('Stock: ${ingredient.availableStock.toStringAsFixed(2)} kg'),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: TextFormField(
                                      controller: _issuedQtyControllers[id],
                                      decoration: const InputDecoration(
                                        labelText: 'Issue Qty',
                                        isDense: true,
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isIssuing ? null : _issueMaterials,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                        child: _isIssuing
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Confirm Material Issue', style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                  ] else if (_approvedPlans.isEmpty) ...[
                    const Expanded(
                      child: Center(
                        child: Text('No approved production plans available for material issue.'),
                      ),
                    ),
                  ]
                ],
              ),
            ),
    );
  }
}
