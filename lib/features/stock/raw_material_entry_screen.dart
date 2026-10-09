import 'package:flutter/material.dart';
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
      _gstController.text = (widget.initialData!['gst']?.toString() ?? '0');
      _supplierController.text = widget.initialData!['supplierName'] ?? '';
      _selectedUnit = widget.initialData!['unit'] ?? 'kg';
    }
  }

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

      final request = isEdit 
          ? http.put(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                if (token != null) 'Authorization': 'Bearer $token',
              },
              body: json.encode({
                'name': _nameController.text.trim(),
                'currentStock': double.parse(_stockController.text),
                'unit': _selectedUnit,
                'gst': _gstController.text.isNotEmpty ? double.parse(_gstController.text) : 0,
                'supplierName': _supplierController.text.trim(),
              }),
            )
          : http.post(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                if (token != null) 'Authorization': 'Bearer $token',
              },
              body: json.encode({
                'name': _nameController.text.trim(),
                'currentStock': double.parse(_stockController.text),
                'unit': _selectedUnit,
                'gst': _gstController.text.isNotEmpty ? double.parse(_gstController.text) : 0,
                'supplierName': _supplierController.text.trim(),
              }),
            );

      final response = await request;

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEdit ? 'Raw Material updated successfully!' : 'Raw Material stock saved successfully!')),
        );
        if (isEdit) {
          Navigator.pop(context);
        } else {
          _formKey.currentState!.reset();
          setState(() {
            _selectedUnit = 'kg';
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save stock: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stockController.dispose();
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
                        value == null || value.isEmpty ? 'Please enter a name' : null,
                  ),
                  const SizedBox(height: 16),

                  // Stock & Unit Row
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _stockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Initial Stock',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => 
                              value == null || value.isEmpty ? 'Required' : null,
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

                  // GST
                  TextFormField(
                    controller: _gstController,
                    keyboardType: TextInputType.number,
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
                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitStock,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green, // Match the design "Save Initial Stock"
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : const Text('Save Initial Stock', style: TextStyle(fontSize: 16)),
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
