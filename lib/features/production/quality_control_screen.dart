import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/database_service.dart';
import '../../core/models/production_plan.dart';
import '../../core/models/master_product.dart';

class QualityControlScreen extends StatefulWidget {
  const QualityControlScreen({Key? key}) : super(key: key);

  @override
  State<QualityControlScreen> createState() => _QualityControlScreenState();
}

class _QualityControlScreenState extends State<QualityControlScreen> {
  List<ProductionPlan> _pendingQCPlans = [];
  ProductionPlan? _selectedPlan;
  MasterProduct? _masterProduct;
  bool _isLoading = true;
  bool _isSubmitting = false;

  final TextEditingController _batchWeightController = TextEditingController();
  final TextEditingController _sampleSizeController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _rejectionController = TextEditingController();
  
  String _overallResult = 'PENDING';
  
  // Dynamic parameters based on master product
  List<Map<String, dynamic>> _qcParameters = [];
  final Map<String, TextEditingController> _actualValueControllers = {};

  @override
  void initState() {
    super.initState();
    _loadPendingQCPlans();
  }

  Future<void> _loadPendingQCPlans() async {
    setState(() => _isLoading = true);
    final db = Provider.of<DatabaseService>(context, listen: false);
    final allPlans = await db.fetchProductionPlans();
    
    setState(() {
      // Anything that is finished in production or awaiting QC
      _pendingQCPlans = allPlans.where((p) => p.status == 'QC_PENDING' || p.status == 'IN_PRODUCTION' || p.status == 'MATERIALS_ISSUED').toList();
      _isLoading = false;
    });
  }

  void _onPlanSelected(ProductionPlan? plan) async {
    setState(() {
      _selectedPlan = plan;
      _qcParameters.clear();
      _actualValueControllers.clear();
    });

    if (plan != null) {
      final db = Provider.of<DatabaseService>(context, listen: false);
      final masterProducts = db.masterProducts;
      final mp = masterProducts.firstWhere(
        (p) => p.id == plan.masterProductId, 
        orElse: () => MasterProduct(id: '', name: '', totalStockKg: 0)
      );
      
      setState(() {
        _masterProduct = mp;
        // Mock default parameters if master product doesn't have them defined yet
        _qcParameters = [
          {'name': 'Moisture Content', 'expected': '< 10%', 'unit': '%', 'isPassed': false},
          {'name': 'Color', 'expected': 'Standard Brown', 'unit': null, 'isPassed': false},
          {'name': 'Aroma', 'expected': 'Strong', 'unit': null, 'isPassed': false},
        ];

        for (var param in _qcParameters) {
          _actualValueControllers[param['name']] = TextEditingController();
        }
      });
    }
  }

  Future<void> _submitQC() async {
    if (_selectedPlan == null) return;
    
    setState(() => _isSubmitting = true);
    final db = Provider.of<DatabaseService>(context, listen: false);
    
    final parameters = _qcParameters.map((param) {
      return {
        'name': param['name'],
        'expectedValue': param['expected'],
        'actualValue': _actualValueControllers[param['name']]?.text ?? '',
        'unit': param['unit'],
        'isPassed': param['isPassed'],
      };
    }).toList();

    // Note: manufacturingBatchId is mocked here if not fully tracked in step-by-step
    // In a full implementation, you'd select the manufacturing batch associated with the plan.
    final qcData = {
      'productionPlanId': _selectedPlan!.id,
      'manufacturingBatchId': _selectedPlan!.id, // Fallback mapping for now
      'parameters': parameters,
      'overallResult': _overallResult,
      'batchWeight': double.tryParse(_batchWeightController.text) ?? 0.0,
      'sampleSize': double.tryParse(_sampleSizeController.text) ?? 0.0,
      'remarks': _remarksController.text,
      'rejectionReason': _overallResult == 'FAILED' ? _rejectionController.text : '',
    };

    final success = await db.submitQualityControl(qcData);
    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quality Control submitted successfully!')),
      );
      _selectedPlan = null;
      _loadPendingQCPlans();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit QC.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quality Control (QC)'),
        backgroundColor: Colors.amber[800],
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
                      labelText: 'Select Batch for QC',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedPlan,
                    items: _pendingQCPlans.map((p) {
                      return DropdownMenuItem<ProductionPlan>(
                        value: p,
                        child: Text('${p.planNumber} - ${p.masterProductName}'),
                      );
                    }).toList(),
                    onChanged: _onPlanSelected,
                  ),
                  const SizedBox(height: 16),
                  
                  if (_selectedPlan != null) ...[
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _batchWeightController,
                                    decoration: const InputDecoration(labelText: 'Final Batch Weight (kg)', border: OutlineInputBorder()),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _sampleSizeController,
                                    decoration: const InputDecoration(labelText: 'Sample Size tested (g)', border: OutlineInputBorder()),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const Text('QC Parameters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            
                            ..._qcParameters.map((param) {
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
                                            Text(param['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                            Text('Expected: ${param['expected']} ${param['unit'] ?? ''}'),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          controller: _actualValueControllers[param['name']],
                                          decoration: const InputDecoration(labelText: 'Actual Value', isDense: true),
                                        ),
                                      ),
                                      Checkbox(
                                        value: param['isPassed'],
                                        onChanged: (val) {
                                          setState(() {
                                            param['isPassed'] = val ?? false;
                                          });
                                        },
                                      )
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                            
                            const SizedBox(height: 24),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(labelText: 'Overall Result', border: OutlineInputBorder()),
                              value: _overallResult,
                              items: ['PENDING', 'PASSED', 'CONDITIONAL_PASS', 'FAILED'].map((String val) {
                                return DropdownMenuItem(value: val, child: Text(val));
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _overallResult = val!;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            if (_overallResult == 'FAILED')
                              TextFormField(
                                controller: _rejectionController,
                                decoration: const InputDecoration(labelText: 'Reason for Rejection', border: OutlineInputBorder()),
                                maxLines: 2,
                              ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _remarksController,
                              decoration: const InputDecoration(labelText: 'Inspector Remarks', border: OutlineInputBorder()),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitQC,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[900]),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Submit QC Report', style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                  ] else if (_pendingQCPlans.isEmpty) ...[
                    const Expanded(
                      child: Center(
                        child: Text('No batches awaiting QC.'),
                      ),
                    ),
                  ]
                ],
              ),
            ),
    );
  }
}
