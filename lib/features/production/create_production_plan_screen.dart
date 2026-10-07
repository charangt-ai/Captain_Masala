import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/database_service.dart';
import '../../core/models/master_product.dart';

import '../../core/models/production_plan.dart';

class CreateProductionPlanScreen extends StatefulWidget {
  final ProductionPlan? editPlan;

  const CreateProductionPlanScreen({Key? key, this.editPlan}) : super(key: key);

  @override
  State<CreateProductionPlanScreen> createState() => _CreateProductionPlanScreenState();
}

class _CreateProductionPlanScreenState extends State<CreateProductionPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedProductId;
  final TextEditingController _batchSizeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _priority = 'MEDIUM';
  DateTime _plannedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.editPlan != null) {
      _selectedProductId = widget.editPlan!.masterProductId;
      _batchSizeController.text = widget.editPlan!.plannedBatchSize.toString();
      _notesController.text = widget.editPlan!.notes ?? '';
      _priority = widget.editPlan!.priority;
      _plannedDate = widget.editPlan!.plannedDate;
    }
  }

  @override
  void dispose() {
    _batchSizeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _plannedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _plannedDate) {
      setState(() {
        _plannedDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Master Product')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final db = Provider.of<DatabaseService>(context, listen: false);
    final planData = {
      'masterProductId': _selectedProductId,
      'plannedBatchSize': double.parse(_batchSizeController.text),
      'plannedDate': _plannedDate.toIso8601String(),
      'priority': _priority,
      'notes': _notesController.text,
    };

    String? errorMessage;
    if (widget.editPlan == null) {
      errorMessage = await db.createProductionPlan(planData);
    } else {
      errorMessage = await db.updateProductionPlan(widget.editPlan!.id!, planData);
    }
    
    setState(() => _isLoading = false);

    if (errorMessage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.editPlan == null ? 'Production Plan created successfully' : 'Production Plan updated successfully')),
      );
      Navigator.pop(context, true); // Return true to signal refresh
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $errorMessage'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final masterProducts = db.masterProducts;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editPlan == null ? 'Create Production Plan' : 'Edit Production Plan'),
        backgroundColor: Colors.red[800],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Select Master Product',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedProductId,
                      items: masterProducts.map((p) {
                        return DropdownMenuItem<String>(
                          value: p.id,
                          child: Text(p.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedProductId = val;
                        });
                      },
                      validator: (val) => val == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _batchSizeController,
                      decoration: const InputDecoration(
                        labelText: 'Planned Batch Size (kg)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Required';
                        if (double.tryParse(val) == null) return 'Must be a valid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Planned Date'),
                      subtitle: Text('${_plannedDate.toLocal()}'.split(' ')[0]),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _selectDate(context),
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(),
                      ),
                      value: _priority,
                      items: ['LOW', 'MEDIUM', 'HIGH', 'URGENT'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setState(() {
                            _priority = newValue;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[800],
                        ),
                        child: Text(
                          widget.editPlan == null ? 'Create Plan' : 'Update Plan',
                          style: const TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
