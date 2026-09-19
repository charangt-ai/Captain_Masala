import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/models/manufacturing_batch.dart';
import '../../core/services/database_service.dart';
import '../../core/theme.dart';
import '../../core/permissions.dart';
import 'batch_detail_screen.dart';

class ManufacturingProcessScreen extends StatefulWidget {
  const ManufacturingProcessScreen({Key? key}) : super(key: key);

  @override
  State<ManufacturingProcessScreen> createState() => _ManufacturingProcessScreenState();
}

class _ManufacturingProcessScreenState extends State<ManufacturingProcessScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  final ManufacturingBatch _batch = ManufacturingBatch();

  // Controllers for Step 2
  final _rawMaterialNameController = TextEditingController();
  final _rawMaterialQtyController = TextEditingController();
  final _rawMaterialAmountController = TextEditingController();
  final _gstController = TextEditingController();

  // Controllers for Step 3
  final _beforeDryingController = TextEditingController();
  final _afterDryingController = TextEditingController();

  // Controllers for Step 4
  final _beforeGrindingController = TextEditingController();
  final _afterGrindingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Listeners for auto calculations
    _beforeDryingController.addListener(_updateBatch);
    _afterDryingController.addListener(_updateBatch);
    _beforeGrindingController.addListener(_updateBatch);
    _afterGrindingController.addListener(_updateBatch);
    _rawMaterialAmountController.addListener(_updateBatchCost);
    _gstController.addListener(_updateBatchCost);
  }

  void _updateBatchCost() {
    setState(() {
      _batch.rawMaterialAmount = double.tryParse(_rawMaterialAmountController.text);
      _batch.gstPercentage = double.tryParse(_gstController.text);
    });
  }

  void _updateBatch() {
    setState(() {
      _batch.weightBeforeDrying = double.tryParse(_beforeDryingController.text);
      _batch.weightAfterDrying = double.tryParse(_afterDryingController.text);
      _batch.weightBeforeGrinding = double.tryParse(_beforeGrindingController.text);
      _batch.weightAfterGrinding = double.tryParse(_afterGrindingController.text);
    });
  }

  @override
  void dispose() {
    _rawMaterialNameController.dispose();
    _rawMaterialQtyController.dispose();
    _rawMaterialAmountController.dispose();
    _gstController.dispose();
    _beforeDryingController.dispose();
    _afterDryingController.dispose();
    _beforeGrindingController.dispose();
    _afterGrindingController.dispose();
    super.dispose();
  }

  void _submitBatch() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    
    // Validate final checks
    if (_batch.targetProductId == null || _batch.finalOutputWeight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Batch Data')));
      return;
    }

    setState(() => _isLoading = true);

    // Set creator details
    _batch.createdById = db.currentUserProfile?.id;
    _batch.createdByName = db.currentUserProfile?.name ?? db.currentUserProfile?.username;

    // Submit to database
    final success = await db.submitManufacturingBatch(_batch);
    
    if (mounted) {
      setState(() => _isLoading = false);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Batch Process Saved. Awaiting Inventory Approval.'))
        );
        
        // Reset form
        setState(() {
          _currentStep = 0;
          _rawMaterialNameController.clear();
          _rawMaterialQtyController.clear();
          _rawMaterialAmountController.clear();
          _gstController.clear();
          _beforeDryingController.clear();
          _afterDryingController.clear();
          _beforeGrindingController.clear();
          _afterGrindingController.clear();
          _batch.targetProductId = null;
          _batch.targetProductName = null;
        });

        // Switch to the second tab
        DefaultTabController.of(context).animateTo(1);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit batch process'))
        );
      }
    }
  }

  Widget _buildStepCard({required Widget child}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manufacturing Process'),
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'New Batch', icon: Icon(Icons.add_circle_outline)),
              Tab(text: 'Stock Approval', icon: Icon(Icons.check_circle_outline)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildNewBatchTab(db),
            const _MonthlyBatchList(),
          ],
        ),
      ),
    );
  }

  Widget _buildNewBatchTab(DatabaseService db) {
    return Stack(
      children: [
          Stepper(
            type: StepperType.vertical,
            currentStep: _currentStep,
            controlsBuilder: (context, details) {
              final isLastStep = _currentStep == 4;
              return Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: details.onStepContinue,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(isLastStep ? 'Confirm & Process' : 'Continue'),
                      ),
                    ),
                    if (_currentStep > 0) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: details.onStepCancel,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Previous'),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
            onStepContinue: () {
              if (_currentStep == 0) {
                 if (_batch.targetProductId == null) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a product to make')));
                   return;
                 }
              }
              if (_currentStep == 1) {
                final qty = double.tryParse(_rawMaterialQtyController.text) ?? 0;
                if (qty <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid raw material quantity.')));
                  return;
                }
                _batch.rawMaterialName = _rawMaterialNameController.text;
                _batch.rawMaterialQuantity = qty;
                _batch.rawMaterialAmount = double.tryParse(_rawMaterialAmountController.text);
                _batch.gstPercentage = double.tryParse(_gstController.text);
                _beforeDryingController.text = _batch.rawMaterialQuantity.toString();
              }
              if (_currentStep == 2) {
                 final before = double.tryParse(_beforeDryingController.text) ?? 0;
                 final after = double.tryParse(_afterDryingController.text) ?? 0;
                 if (after > before || after <= 0) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid drying weight. After weight must be > 0 and <= Before weight.')));
                   return;
                 }
                 _beforeGrindingController.text = _afterDryingController.text;
              }
              if (_currentStep == 3) {
                 final before = double.tryParse(_beforeGrindingController.text) ?? 0;
                 final after = double.tryParse(_afterGrindingController.text) ?? 0;
                 if (after > before || after <= 0) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid grinding weight. After weight must be > 0 and <= Before weight.')));
                   return;
                 }
              }

              if (_currentStep < 4) {
                setState(() {
                  _currentStep += 1;
                });
              } else {
                _submitBatch();
              }
            },
            onStepCancel: () {
              if (_currentStep > 0) {
                setState(() {
                  _currentStep -= 1;
                });
              }
            },
            steps: [
              // Step 1: Choose Product
              Step(
                title: const Text('1. Choose Product', style: TextStyle(fontWeight: FontWeight.bold)),
                isActive: _currentStep >= 0,
                state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                content: _buildStepCard(
                  child: DropdownButtonFormField<String>(
                    value: _batch.targetProductId,
                    decoration: const InputDecoration(
                      labelText: 'Target Product', 
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    items: db.masterProducts.map((p) {
                      return DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _batch.targetProductId = val;
                        _batch.targetProductName = db.masterProducts.firstWhere((p) => p.id == val).name;
                      });
                    },
                  ),
                ),
              ),

              // Step 2: Enter Raw Material
              Step(
                title: const Text('2. Enter Raw Material', style: TextStyle(fontWeight: FontWeight.bold)),
                isActive: _currentStep >= 1,
                state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                content: _buildStepCard(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _rawMaterialNameController,
                        decoration: const InputDecoration(
                          labelText: 'Material Name', 
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.eco_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _rawMaterialQtyController,
                        decoration: const InputDecoration(
                          labelText: 'Quantity (kg)', 
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.scale_outlined),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _rawMaterialAmountController,
                              decoration: const InputDecoration(
                                labelText: 'Total Amount (₹)', 
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.currency_rupee),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _gstController,
                              decoration: const InputDecoration(
                                labelText: 'GST %', 
                                border: OutlineInputBorder(),
                                suffixText: '%',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      if ((_batch.rawMaterialAmount ?? 0) > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Cost (incl. GST):', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('₹${_batch.totalCost.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Step 3: Drying Process
              Step(
                title: const Text('3. Drying Process', style: TextStyle(fontWeight: FontWeight.bold)),
                isActive: _currentStep >= 2,
                state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                content: _buildStepCard(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _beforeDryingController,
                        decoration: const InputDecoration(
                          labelText: 'Weight Before Drying (kg)', 
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.monitor_weight_outlined),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _afterDryingController,
                        decoration: const InputDecoration(
                          labelText: 'Weight After Drying (kg)', 
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.monitor_weight_outlined),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        width: double.infinity,
                        child: Row(
                          children: [
                            const Icon(Icons.water_drop_outlined, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text('Drying Loss: ${_batch.dryingLoss.toStringAsFixed(2)} kg', 
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Step 4: Grinding Process
              Step(
                title: const Text('4. Grinding Process', style: TextStyle(fontWeight: FontWeight.bold)),
                isActive: _currentStep >= 3,
                state: _currentStep > 3 ? StepState.complete : StepState.indexed,
                content: _buildStepCard(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _beforeGrindingController,
                        decoration: const InputDecoration(
                          labelText: 'Weight Before Grinding (kg)', 
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.monitor_weight_outlined),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _afterGrindingController,
                        decoration: const InputDecoration(
                          labelText: 'Weight After Grinding (kg)', 
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.monitor_weight_outlined),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        width: double.infinity,
                        child: Row(
                          children: [
                            const Icon(Icons.recycling, color: Colors.green),
                            const SizedBox(width: 8),
                            Text('Grinding Loss: ${_batch.grindingLoss.toStringAsFixed(2)} kg', 
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Step 5: Complete Report
              Step(
                title: const Text('5. Complete Report', style: TextStyle(fontWeight: FontWeight.bold)),
                isActive: _currentStep >= 4,
                content: Card(
                  color: Colors.purple.shade50,
                  elevation: 4,
                  shadowColor: Colors.purple.shade100,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.purple.shade300, width: 1.5),
                    borderRadius: BorderRadius.circular(12)
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.summarize, color: Colors.purple.shade700),
                            const SizedBox(width: 8),
                            Text('Manufacturing Summary', 
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.purple.shade800)
                            ),
                          ],
                        ),
                        const Divider(height: 32),
                        _buildReportRow('Target Product', _batch.targetProductName ?? 'N/A', isBold: true),
                        const SizedBox(height: 12),
                        
                        const Text('Financials & Input', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 8),
                        _buildReportRow('Raw Material', '${_batch.rawMaterialName} (${_batch.rawMaterialQuantity} kg)'),
                        _buildReportRow('Amount', '₹${_batch.rawMaterialAmount?.toStringAsFixed(2) ?? '0.00'}'),
                        _buildReportRow('GST (${_batch.gstPercentage ?? 0}%)', '₹${_batch.totalGstAmount.toStringAsFixed(2)}'),
                        _buildReportRow('Total Cost', '₹${_batch.totalCost.toStringAsFixed(2)}', isBold: true),
                        
                        const SizedBox(height: 16),
                        const Text('Processing Metrics', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 8),
                        _buildReportRow('Drying Loss', '${_batch.dryingLoss.toStringAsFixed(2)} kg', color: Colors.orange.shade800),
                        _buildReportRow('Grinding Loss', '${_batch.grindingLoss.toStringAsFixed(2)} kg', color: Colors.green.shade800),
                        _buildReportRow('Total Loss', '${_batch.totalLoss.toStringAsFixed(2)} kg', color: Colors.red.shade700, isBold: true),
                        
                        const Divider(height: 32),
                        
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.purple.shade100)
                          ),
                          child: Column(
                            children: [
                              Text('Final Yield: ${_batch.finalOutputWeight} kg', 
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.purple.shade700)),
                              const SizedBox(height: 4),
                              Text('Yield Percentage: ${_batch.yieldPercentage.toStringAsFixed(2)}%', 
                                style: const TextStyle(fontSize: 16, color: Colors.black87)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('(Confirm to update inventory)', 
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      );
  }

  Widget _buildReportRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          Text(value, style: TextStyle(
            fontSize: 15, 
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? Colors.black87
          )),
        ],
      ),
    );
  }
}

class _MonthlyBatchList extends StatefulWidget {
  const _MonthlyBatchList({Key? key}) : super(key: key);

  @override
  State<_MonthlyBatchList> createState() => _MonthlyBatchListState();
}

class _MonthlyBatchListState extends State<_MonthlyBatchList> {
  bool _isLoading = true;
  List<ManufacturingBatch> _batches = [];
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() => _isLoading = true);
    final db = Provider.of<DatabaseService>(context, listen: false);
    final batches = await db.fetchMonthlyBatches(month: _selectedDate.month, year: _selectedDate.year);
    if (mounted) {
      setState(() {
        _batches = batches;
        _isLoading = false;
      });
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + offset, 1);
    });
    _loadBatches();
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final rupeeFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Column(
      children: [
        // Month Selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeMonth(-1),
              ),
              Text(
                DateFormat('MMMM yyyy').format(_selectedDate),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _selectedDate.month == DateTime.now().month && _selectedDate.year == DateTime.now().year
                    ? null
                    : () => _changeMonth(1),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _batches.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text('No batches found for ${DateFormat('MMMM yyyy').format(_selectedDate)}',
                              style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _batches.length,
                      itemBuilder: (context, index) {
                        final batch = _batches[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BatchDetailScreen(batch: batch, dbService: db),
                                ),
                              ).then((_) => _loadBatches()); // Reload when coming back in case of delete
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          batch.targetProductName ?? 'Unknown Product',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryGreen.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          batch.status ?? 'COMPLETED',
                                          style: const TextStyle(color: AppColors.primaryGreen, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Raw Material: ${batch.rawMaterialName} (${batch.rawMaterialQuantity} kg)',
                                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  if (batch.timestamp != null)
                                    Text(
                                      'Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(batch.timestamp!)}',
                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                    ),
                                  const Divider(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Final Yield', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                          Text('${batch.finalOutputWeight} kg', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple.shade700)),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Yield %', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                          Text('${batch.yieldPercentage.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          const Text('Total Cost', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                          Text(rupeeFormat.format(batch.totalCost), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryRed)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
