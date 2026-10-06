import 'package:flutter/material.dart';
import '../../../core/models/inventory/raw_material.dart';
import 'package:provider/provider.dart';

class LoadStockDialog extends StatefulWidget {
  final List<RawMaterial> availableMaterials;
  final Function(String materialId, String batchNumber, double quantity, String location) onSubmit;

  const LoadStockDialog({
    Key? key, 
    required this.availableMaterials,
    required this.onSubmit,
  }) : super(key: key);

  @override
  State<LoadStockDialog> createState() => _LoadStockDialogState();
}

class _LoadStockDialogState extends State<LoadStockDialog> {
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedMaterialId;
  final _batchNumberController = TextEditingController();
  final _quantityController = TextEditingController();
  final _locationController = TextEditingController();

  @override
  void dispose() {
    _batchNumberController.dispose();
    _quantityController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (_selectedMaterialId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a material')),
        );
        return;
      }
      
      widget.onSubmit(
        _selectedMaterialId!,
        _batchNumberController.text.trim(),
        double.tryParse(_quantityController.text) ?? 0.0,
        _locationController.text.trim(),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Load Stock'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Raw Material'),
                value: _selectedMaterialId,
                items: widget.availableMaterials.map((rm) {
                  return DropdownMenuItem(
                    value: rm.id,
                    child: Text(rm.name),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedMaterialId = val;
                  });
                },
                validator: (val) => val == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _batchNumberController,
                decoration: const InputDecoration(labelText: 'Batch Number'),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: 'Quantity (kg/g)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  if (double.tryParse(val) == null) return 'Must be a number';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Storage Location'),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Load Stock'),
        ),
      ],
    );
  }
}
