import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/database_service.dart';
import '../../core/models/production_plan.dart';
import '../../core/models/batch_costing.dart';

class BatchCostingScreen extends StatefulWidget {
  const BatchCostingScreen({Key? key}) : super(key: key);

  @override
  State<BatchCostingScreen> createState() => _BatchCostingScreenState();
}

class _BatchCostingScreenState extends State<BatchCostingScreen> {
  List<BatchCosting> _costings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCostings();
  }

  Future<void> _loadCostings() async {
    setState(() => _isLoading = true);
    final db = Provider.of<DatabaseService>(context, listen: false);
    final costings = await db.fetchBatchCostings();
    setState(() {
      _costings = costings;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Costing Ledger'),
        backgroundColor: Colors.brown[800],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _costings.isEmpty
              ? const Center(child: Text('No batch costings found.'))
              : ListView.builder(
                  itemCount: _costings.length,
                  itemBuilder: (context, index) {
                    final costing = _costings[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ExpansionTile(
                        title: Text(costing.costingNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${costing.masterProductName} - Cost: ₹${costing.costPerKg.toStringAsFixed(2)}/kg'),
                        trailing: Chip(
                          label: Text('${costing.processLossPercentage.toStringAsFixed(1)}% Loss', style: const TextStyle(color: Colors.white, fontSize: 10)),
                          backgroundColor: costing.processLossPercentage > 5 ? Colors.red : Colors.green,
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildCostRow('Total Raw Material Cost', costing.totalCost - costing.overheadCost.subtotal),
                                _buildCostRow('Total Overhead Cost', costing.overheadCost.subtotal),
                                const Divider(),
                                _buildCostRow('Total Production Cost', costing.totalCost, isBold: true),
                                _buildCostRow('Total Output Quantity', '${costing.outputQuantity} kg'),
                                _buildCostRow('Final Cost Per Kg', '₹${costing.costPerKg.toStringAsFixed(2)}', isBold: true, color: Colors.blue[900]),
                                const SizedBox(height: 16),
                                const Text('Overhead Breakdown:', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('Labor: ₹${costing.overheadCost.labor}'),
                                Text('Electricity: ₹${costing.overheadCost.electricity}'),
                                Text('Fuel: ₹${costing.overheadCost.fuel}'),
                                Text('Depreciation: ₹${costing.overheadCost.depreciation}'),
                                Text('Miscellaneous: ₹${costing.overheadCost.miscellaneous}'),
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
            MaterialPageRoute(builder: (_) => const CreateBatchCostingScreen()),
          );
          if (result == true) {
            _loadCostings();
          }
        },
        backgroundColor: Colors.brown[800],
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCostRow(String label, dynamic value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            value is num ? '₹${value.toStringAsFixed(2)}' : value.toString(),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class CreateBatchCostingScreen extends StatefulWidget {
  const CreateBatchCostingScreen({Key? key}) : super(key: key);

  @override
  State<CreateBatchCostingScreen> createState() => _CreateBatchCostingScreenState();
}

class _CreateBatchCostingScreenState extends State<CreateBatchCostingScreen> {
  List<ProductionPlan> _completedPlans = [];
  ProductionPlan? _selectedPlan;
  bool _isLoading = true;
  bool _isSubmitting = false;

  final TextEditingController _laborController = TextEditingController(text: '0');
  final TextEditingController _electricityController = TextEditingController(text: '0');
  final TextEditingController _fuelController = TextEditingController(text: '0');
  final TextEditingController _depreciationController = TextEditingController(text: '0');
  final TextEditingController _miscController = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _loadCompletedPlans();
  }

  Future<void> _loadCompletedPlans() async {
    setState(() => _isLoading = true);
    final db = Provider.of<DatabaseService>(context, listen: false);
    final allPlans = await db.fetchProductionPlans();
    setState(() {
      _completedPlans = allPlans.where((p) => p.status == 'COMPLETED').toList();
      _isLoading = false;
    });
  }

  Future<void> _submitCosting() async {
    if (_selectedPlan == null) return;
    
    setState(() => _isSubmitting = true);
    final db = Provider.of<DatabaseService>(context, listen: false);

    final data = {
      'productionPlanId': _selectedPlan!.id,
      'overheadCost': {
        'labor': double.tryParse(_laborController.text) ?? 0,
        'electricity': double.tryParse(_electricityController.text) ?? 0,
        'fuel': double.tryParse(_fuelController.text) ?? 0,
        'depreciation': double.tryParse(_depreciationController.text) ?? 0,
        'miscellaneous': double.tryParse(_miscController.text) ?? 0,
      }
    };

    final success = await db.createBatchCosting(data);
    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Batch costing generated!')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate costing. Note: You must generate FG for this plan first.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculate Batch Cost'),
        backgroundColor: Colors.brown[800],
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
                      labelText: 'Select Completed Batch',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedPlan,
                    items: _completedPlans.map((p) {
                      return DropdownMenuItem<ProductionPlan>(
                        value: p,
                        child: Text('${p.planNumber} - ${p.masterProductName}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedPlan = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  if (_selectedPlan != null) ...[
                    const Text('Enter Overhead Costs (₹)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildCostInput('Labor Cost', _laborController),
                            const SizedBox(height: 12),
                            _buildCostInput('Electricity Cost', _electricityController),
                            const SizedBox(height: 12),
                            _buildCostInput('Fuel / Gas Cost', _fuelController),
                            const SizedBox(height: 12),
                            _buildCostInput('Machinery Depreciation', _depreciationController),
                            const SizedBox(height: 12),
                            _buildCostInput('Miscellaneous', _miscController),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitCosting,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.brown[800]),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Calculate Cost', style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                  ] else if (_completedPlans.isEmpty) ...[
                    const Expanded(
                      child: Center(
                        child: Text('No completed plans awaiting costing.'),
                      ),
                    ),
                  ]
                ],
              ),
            ),
    );
  }

  Widget _buildCostInput(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixText: '₹ ',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
  }
}
