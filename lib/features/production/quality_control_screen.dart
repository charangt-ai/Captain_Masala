import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/database_service.dart';
import '../../core/models/production_plan.dart';
import '../../core/models/master_product.dart';
import 'finished_goods_screen.dart';

class QualityControlScreen extends StatefulWidget {
  final String? initialPlanId;

  const QualityControlScreen({super.key, this.initialPlanId});

  @override
  State<QualityControlScreen> createState() => _QualityControlScreenState();
}

class _QualityControlScreenState extends State<QualityControlScreen> {
  List<ProductionPlan> _pendingQCPlans = [];
  String? _selectedPlanId;
  ProductionPlan? _selectedPlan;
  bool _isLoading = true;
  bool _isSubmitting = false;

  final TextEditingController _batchWeightController = TextEditingController();
  final TextEditingController _sampleSizeController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _rejectionController = TextEditingController();
  
  String _overallResult = 'PASSED';
  
  // Dynamic parameters based on master product
  List<Map<String, dynamic>> _qcParameters = [];
  final Map<String, TextEditingController> _actualValueControllers = {};

  @override
  void initState() {
    super.initState();
    _loadPendingQCPlans();
  }

  @override
  void dispose() {
    _batchWeightController.dispose();
    _sampleSizeController.dispose();
    _remarksController.dispose();
    _rejectionController.dispose();
    for (var controller in _actualValueControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPendingQCPlans() async {
    setState(() => _isLoading = true);
    final db = Provider.of<DatabaseService>(context, listen: false);
    final allPlans = await db.fetchProductionPlans();
    
    // Plans that have materials issued, are in production, or are specifically awaiting QC
    final pending = allPlans.where((p) {
      return p.status == 'QC_PENDING' || 
             p.status == 'IN_PRODUCTION' || 
             p.status == 'MATERIALS_ISSUED';
    }).toList();

    setState(() {
      _pendingQCPlans = pending;
      _isLoading = false;
    });

    if (widget.initialPlanId != null) {
      final matching = pending.where((p) => p.id == widget.initialPlanId).firstOrNull;
      if (matching != null) {
        _onPlanIdSelected(matching.id);
      }
    } else if (pending.isNotEmpty && _selectedPlanId == null) {
      _onPlanIdSelected(pending.first.id);
    }
  }

  void _onPlanIdSelected(String? planId) {
    if (planId == null) {
      setState(() {
        _selectedPlanId = null;
        _selectedPlan = null;
        _qcParameters.clear();
        for (var c in _actualValueControllers.values) {
          c.dispose();
        }
        _actualValueControllers.clear();
      });
      return;
    }

    final plan = _pendingQCPlans.firstWhere(
      (p) => p.id == planId,
      orElse: () => _pendingQCPlans.first,
    );

    setState(() {
      _selectedPlanId = plan.id;
      _selectedPlan = plan;
      
      // Auto-prefill final batch weight with planned size if empty
      _batchWeightController.text = plan.plannedBatchSize > 0 
          ? plan.plannedBatchSize.toStringAsFixed(1) 
          : '100.0';
      if (_sampleSizeController.text.isEmpty) {
        _sampleSizeController.text = '500'; // Standard 500g QC sample
      }

      for (var c in _actualValueControllers.values) {
        c.dispose();
      }
      _actualValueControllers.clear();
    });

    setState(() {
      // Standard comprehensive QC parameters for spice processing
      _qcParameters = [
        {'name': 'Moisture Content', 'expected': '< 10%', 'unit': '%', 'actual': '7.5%', 'isPassed': true},
        {'name': 'Color & Visual Appearance', 'expected': 'Standard Uniform', 'unit': null, 'actual': 'Standard Red/Brown', 'isPassed': true},
        {'name': 'Aroma & Pungency', 'expected': 'Strong Authentic', 'unit': null, 'actual': 'Pass - Characteristic', 'isPassed': true},
        {'name': 'Granule Mesh Size', 'expected': 'Standard Ground Powder', 'unit': null, 'actual': 'Fine uniform mesh', 'isPassed': true},
        {'name': 'Foreign Matter / Admixture', 'expected': 'Nil / Absent', 'unit': null, 'actual': 'Nil', 'isPassed': true},
      ];

      for (var param in _qcParameters) {
        _actualValueControllers[param['name']] = TextEditingController(text: param['actual'] ?? '');
      }
    });
  }

  Future<void> _submitQC() async {
    if (_selectedPlan == null || _selectedPlan!.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a production plan first')),
      );
      return;
    }

    final weight = double.tryParse(_batchWeightController.text.trim()) ?? 0.0;
    if (weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid Final Batch Weight (> 0 kg)')),
      );
      return;
    }

    if (_overallResult == 'FAILED' && _rejectionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reason for rejection')),
      );
      return;
    }
    
    setState(() => _isSubmitting = true);
    final db = Provider.of<DatabaseService>(context, listen: false);
    
    final parameters = _qcParameters.map((param) {
      return {
        'name': param['name'],
        'expectedValue': param['expected'],
        'actualValue': _actualValueControllers[param['name']]?.text.trim() ?? '',
        'unit': param['unit'],
        'isPassed': param['isPassed'] ?? false,
      };
    }).toList();

    final qcData = {
      'productionPlanId': _selectedPlan!.id,
      'manufacturingBatchId': _selectedPlan!.manufacturingBatchId ?? _selectedPlan!.id,
      'parameters': parameters,
      'overallResult': _overallResult,
      'batchWeight': weight,
      'sampleSize': double.tryParse(_sampleSizeController.text.trim()) ?? 0.0,
      'remarks': _remarksController.text.trim(),
      'rejectionReason': _overallResult == 'FAILED' ? _rejectionController.text.trim() : '',
    };

    final result = await db.submitQualityControl(qcData);
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_overallResult == 'PASSED' 
            ? 'QC Passed! Finished Goods batch created and stock updated.' 
            : 'QC Report Submitted (${_overallResult}).'),
          backgroundColor: _overallResult == 'PASSED' ? Colors.green[800] : Colors.orange[800],
        ),
      );
      
      if (_overallResult == 'PASSED' || _overallResult == 'CONDITIONAL_PASS') {
        // Navigate to Finished Goods bulk inventory & packaging allocation
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FinishedGoodsScreen()),
        );
      } else {
        _selectedPlanId = null;
        _selectedPlan = null;
        _loadPendingQCPlans();
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to submit QC report.'),
          backgroundColor: Colors.red[800],
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quality Control (QC)'),
        backgroundColor: Colors.amber[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPendingQCPlans,
            tooltip: 'Refresh Plans',
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_pendingQCPlans.isEmpty) ...[
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, size: 64, color: Colors.green[300]),
                            const SizedBox(height: 16),
                            const Text(
                              'No batches currently awaiting QC inspection.',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Create a production plan or start manufacturing to send batches to QC.',
                              style: TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Select Production Plan for QC',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.inventory_2),
                      ),
                      value: _selectedPlanId,
                      items: _pendingQCPlans.map((p) {
                        return DropdownMenuItem<String>(
                          value: p.id,
                          child: Text(
                            '${p.planNumber} - ${p.masterProductName} (${p.status})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: _onPlanIdSelected,
                    ),
                    const SizedBox(height: 16),

                    if (_selectedPlan != null)
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Card(
                                color: Colors.amber.shade50,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedPlan!.masterProductName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          Text('Plan Size: ${_selectedPlan!.plannedBatchSize} kg'),
                                        ],
                                      ),
                                      Chip(
                                        label: Text(
                                          _selectedPlan!.status,
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                        backgroundColor: Colors.amber[900],
                                      )
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _batchWeightController,
                                      decoration: const InputDecoration(
                                        labelText: 'Final Batch Weight (kg)',
                                        border: OutlineInputBorder(),
                                        suffixText: 'kg',
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _sampleSizeController,
                                      decoration: const InputDecoration(
                                        labelText: 'Sample Size (g)',
                                        border: OutlineInputBorder(),
                                        suffixText: 'g',
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'QC Laboratory Parameters',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${_qcParameters.where((p) => p['isPassed'] == true).length}/${_qcParameters.length} Passed',
                                    style: TextStyle(
                                      color: _qcParameters.every((p) => p['isPassed'] == true) ? Colors.green[800] : Colors.orange[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),

                              ..._qcParameters.map((param) {
                                final isPassed = param['isPassed'] == true;
                                return Card(
                                  elevation: 1,
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  shape: RoundedRectangleBorder(
                                    side: BorderSide(color: isPassed ? Colors.green.shade200 : Colors.red.shade200),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                param['name'],
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                              Text(
                                                'Standard: ${param['expected']}',
                                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: TextFormField(
                                            controller: _actualValueControllers[param['name']],
                                            decoration: const InputDecoration(
                                              labelText: 'Actual Result',
                                              isDense: true,
                                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                              border: OutlineInputBorder(),
                                            ),
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          children: [
                                            Checkbox(
                                              value: param['isPassed'],
                                              activeColor: Colors.green[800],
                                              onChanged: (val) {
                                                setState(() {
                                                  param['isPassed'] = val ?? false;
                                                });
                                              },
                                            ),
                                            Text(
                                              isPassed ? 'Pass' : 'Fail',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isPassed ? Colors.green[800] : Colors.red[800],
                                              ),
                                            )
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),

                              const SizedBox(height: 24),
                              DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Overall Result Decision',
                                  border: OutlineInputBorder(),
                                ),
                                value: _overallResult,
                                items: const [
                                  DropdownMenuItem(value: 'PASSED', child: Text('PASSED (Approve for Packaging)')),
                                  DropdownMenuItem(value: 'CONDITIONAL_PASS', child: Text('CONDITIONAL PASS')),
                                  DropdownMenuItem(value: 'FAILED', child: Text('FAILED (Reject Batch)')),
                                  DropdownMenuItem(value: 'PENDING', child: Text('PENDING INSPECTION')),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _overallResult = val!;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),

                              if (_overallResult == 'FAILED') ...[
                                TextFormField(
                                  controller: _rejectionController,
                                  decoration: const InputDecoration(
                                    labelText: 'Reason for Rejection *',
                                    border: OutlineInputBorder(),
                                    hintText: 'Describe failure or non-compliance observed',
                                  ),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 16),
                              ],

                              TextFormField(
                                controller: _remarksController,
                                decoration: const InputDecoration(
                                  labelText: 'Inspector Remarks & Notes',
                                  border: OutlineInputBorder(),
                                  hintText: 'Additional observations, moisture meter readings, etc.',
                                ),
                                maxLines: 2,
                              ),
                              const SizedBox(height: 24),

                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: _isSubmitting ? null : _submitQC,
                                  icon: _isSubmitting 
                                      ? const SizedBox.shrink() 
                                      : const Icon(Icons.verified, color: Colors.white),
                                  label: _isSubmitting
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : Text(
                                          _overallResult == 'PASSED'
                                              ? 'Approve & Create Finished Goods'
                                              : 'Submit QC Decision',
                                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _overallResult == 'PASSED' ? Colors.green[800] : Colors.amber[900],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                  ]
                ],
              ),
            ),
    );
  }
}
