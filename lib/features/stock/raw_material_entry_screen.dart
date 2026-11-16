import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/services/api_config.dart';

class RawMaterialEntryScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const RawMaterialEntryScreen({Key? key, this.initialData}) : super(key: key);

  @override
  _RawMaterialEntryScreenState createState() => _RawMaterialEntryScreenState();
}

class _RawMaterialEntryScreenState extends State<RawMaterialEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _stockController = TextEditingController();
  final _priceController = TextEditingController();
  final _gstController = TextEditingController();
  final _supplierController = TextEditingController();
  
  String _selectedUnit = 'kg';
  bool _isLoading = false;

  final List<String> _units = ['kg', 'g', 'liters', 'pieces'];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _nameController.text = widget.initialData!['name'] ?? '';
      _stockController.text = (widget.initialData!['currentStock']?.toString() ?? '0');
      _priceController.text = (widget.initialData!['costPerUnit']?.toString() ?? widget.initialData!['unitPrice']?.toString() ?? '');
      _gstController.text = (widget.initialData!['gst']?.toString() ?? '0');
      _supplierController.text = widget.initialData!['supplierName'] ?? '';
      _selectedUnit = widget.initialData!['unit'] ?? 'kg';
    }

    _stockController.addListener(_onFieldChanged);
    _priceController.addListener(_onFieldChanged);
    _gstController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {});
  }

  double get _quantity => double.tryParse(_stockController.text.trim()) ?? 0.0;
  double get _unitPrice => double.tryParse(_priceController.text.trim()) ?? 0.0;
  double get _gstRate => double.tryParse(_gstController.text.trim()) ?? 0.0;

  double get _subtotal => _quantity * _unitPrice;
  double get _taxAmount => _subtotal * (_gstRate / 100);
  double get _totalEstimatedCost => _subtotal + _taxAmount;

  Future<void> _submitStock() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'jwt_token');

      final isEdit = widget.initialData != null;
      final url = isEdit 
          ? '${ApiConfig.baseUrl}/inventory/raw-materials/${widget.initialData!['_id']}'
          : '${ApiConfig.baseUrl}/inventory/raw-materials';

      final requestBody = {
        'name': _nameController.text.trim(),
        'currentStock': _quantity,
        'unit': _selectedUnit,
        'costPerUnit': _unitPrice,
        'totalCost': _subtotal,
        'gst': _gstRate,
        'supplierName': _supplierController.text.trim(),
      };

      final request = isEdit 
          ? http.put(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                if (token != null) 'Authorization': 'Bearer $token',
              },
              body: json.encode(requestBody),
            )
          : http.post(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                if (token != null) 'Authorization': 'Bearer $token',
              },
              body: json.encode(requestBody),
            );

      final response = await request;

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEdit ? 'Raw Material updated successfully!' : 'Raw Material stock saved successfully!')),
        );
        if (isEdit) {
          Navigator.pop(context);
        } else {
          _formKey.currentState!.reset();
          _nameController.clear();
          _stockController.clear();
          _priceController.clear();
          _gstController.clear();
          _supplierController.clear();
          setState(() {
            _selectedUnit = 'kg';
          });
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save stock: ${response.body}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _stockController.removeListener(_onFieldChanged);
    _priceController.removeListener(_onFieldChanged);
    _gstController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _stockController.dispose();
    _priceController.dispose();
    _gstController.dispose();
    _supplierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raw Material Inventory'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Initial Stock Management',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // Raw Material Name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Raw Material Name (e.g. Black Pepper)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => 
                        value == null || value.trim().isEmpty ? 'Please enter a name' : null,
                  ),
                  const SizedBox(height: 16),

                  // Stock & Unit Row
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _stockController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Initial Stock',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => 
                              value == null || value.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          value: _selectedUnit,
                          decoration: const InputDecoration(
                            labelText: 'Unit',
                            border: OutlineInputBorder(),
                          ),
                          items: _units.map((unit) {
                            return DropdownMenuItem(
                              value: unit,
                              child: Text(unit),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedUnit = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Purchase Price / Unit Cost
                  TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Price per Unit (₹/$_selectedUnit)',
                      prefixText: '₹ ',
                      border: const OutlineInputBorder(),
                      helperText: 'Purchase price per $_selectedUnit (Optional/Default ₹0)',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // GST
                  TextFormField(
                    controller: _gstController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'GST % (Optional)',
                      border: OutlineInputBorder(),
                      suffixText: '%',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Supplier
                  TextFormField(
                    controller: _supplierController,
                    decoration: const InputDecoration(
                      labelText: 'Supplier (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Live calculation preview card
                  if (_unitPrice > 0 || _quantity > 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blueGrey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cost Preview',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey),
                          ),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Subtotal (${_quantity.toStringAsFixed(1)} $_selectedUnit × ₹${_unitPrice.toStringAsFixed(2)}):'),
                              Text('₹${_subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          if (_gstRate > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Tax (GST ${_gstRate.toStringAsFixed(1)}%):'),
                                Text('+ ₹${_taxAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.black87)),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Value:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(
                                '₹${_totalEstimatedCost.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitStock,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green, // Match design
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : const Text('Save Initial Stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
