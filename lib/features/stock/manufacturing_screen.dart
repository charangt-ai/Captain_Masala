import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants.dart';

class ManufacturingScreen extends StatefulWidget {
  const ManufacturingScreen({Key? key}) : super(key: key);

  @override
  _ManufacturingScreenState createState() => _ManufacturingScreenState();
}

class _ManufacturingScreenState extends State<ManufacturingScreen> {
  final _batchSizeController = TextEditingController();
  
  List<dynamic> _masterProducts = [];
  String? _selectedProductId;
  
  bool _isValidating = false;
  bool _isStockSufficient = false;
  List<dynamic> _validationResults = [];

  @override
  void initState() {
    super.initState();
    _fetchMasterProducts();
  }

  Future<void> _fetchMasterProducts() async {
    try {
      final response = await http.get(
        Uri.parse('${Constants.apiBaseUrl}/master-products'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _masterProducts = data['data'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching master products: $e');
    }
  }

  Future<void> _validateStock() async {
    if (_selectedProductId == null || _batchSizeController.text.isEmpty) return;

    setState(() {
      _isValidating = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${Constants.apiBaseUrl}/manufacturing/validate-stock'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'productId': _selectedProductId,
          'batchSize': double.parse(_batchSizeController.text),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _isStockSufficient = data['isStockSufficient'];
          _validationResults = data['ingredients'];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to validate stock: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isValidating = false;
      });
    }
  }

  void _startManufacturing() {
    // Navigate to the next step: Multi-stage stepper (Drying, Grinding, Blending)
    // We would pass the validated batch details here.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Proceeding to manufacturing stages...')),
    );
  }

  @override
  void dispose() {
    _batchSizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manufacturing Module'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Pre-process selection card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Select Product & Batch Size',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Select Product',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedProductId,
                      items: _masterProducts.map((product) {
                        return DropdownMenuItem<String>(
                          value: product['_id'],
                          child: Text(product['name']),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedProductId = value;
                          // Optional: Clear previous validation results on product change
                          _validationResults.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _batchSizeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Batch Size (kg)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    ElevatedButton(
                      onPressed: _isValidating ? null : _validateStock,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isValidating 
                          ? const CircularProgressIndicator()
                          : const Text('Validate Stock / Show Requirements'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Stock Validation Results
            if (_validationResults.isNotEmpty)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Required Ingredients',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Icon(
                            _isStockSufficient ? Icons.check_circle : Icons.warning,
                            color: _isStockSufficient ? Colors.green : Colors.red,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Ingredient')),
                            DataColumn(label: Text('Required (kg)')),
                            DataColumn(label: Text('Available (kg)')),
                          ],
                          rows: _validationResults.map((item) {
                            final bool isSufficient = item['isSufficient'];
                            return DataRow(
                              cells: [
                                DataCell(Text(item['rawMaterialName'])),
                                DataCell(Text(item['requiredQty'].toStringAsFixed(2))),
                                DataCell(
                                  Text(
                                    item['availableQty'].toStringAsFixed(2),
                                    style: TextStyle(
                                      color: isSufficient ? Colors.black : Colors.red,
                                      fontWeight: isSufficient ? FontWeight.normal : FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      if (_isStockSufficient)
                        ElevatedButton(
                          onPressed: _startManufacturing,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Allow to Proceed to Manufacturing', style: TextStyle(fontSize: 16)),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            'Insufficient stock for some ingredients. Please reduce batch size or update raw material inventory.',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
