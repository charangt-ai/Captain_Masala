import 'package:flutter/material.dart';

// --- Data Models ---

class BOMItem {
  final String rawMaterialId;
  final String rawMaterialName;
  final double quantityPerUnit;
  final double unitCost;

  BOMItem({
    required this.rawMaterialId,
    required this.rawMaterialName,
    required this.quantityPerUnit,
    required this.unitCost,
  });
}

class ManufacturingReportItem {
  final String rawMaterialId;
  final String rawMaterialName;
  final double totalQuantityConsumed;
  final double totalAmount;

  ManufacturingReportItem({
    required this.rawMaterialId,
    required this.rawMaterialName,
    required this.totalQuantityConsumed,
    required this.totalAmount,
  });
}

// --- Flutter UI Screen ---

class ManufacturingReportCalculator extends StatefulWidget {
  // Pass the BOM of the selected product to this screen
  final List<BOMItem> productBOM;

  const ManufacturingReportCalculator({
    Key? key,
    required this.productBOM,
  }) : super(key: key);

  @override
  State<ManufacturingReportCalculator> createState() => _ManufacturingReportCalculatorState();
}

class _ManufacturingReportCalculatorState extends State<ManufacturingReportCalculator> {
  final TextEditingController _productionQtyController = TextEditingController();
  List<ManufacturingReportItem> _calculatedMaterials = [];
  double _totalProductionCost = 0.0;

  @override
  void initState() {
    super.initState();
    // Listen for changes in the text field to calculate in real-time
    _productionQtyController.addListener(_calculateRequirements);
  }

  @override
  void dispose() {
    _productionQtyController.dispose();
    super.dispose();
  }

  // --- Calculation Logic ---
  void _calculateRequirements() {
    final String qtyText = _productionQtyController.text;
    final double totalProduced = double.tryParse(qtyText) ?? 0.0;

    List<ManufacturingReportItem> newReportItems = [];
    double newTotalCost = 0.0;

    for (var item in widget.productBOM) {
      double totalConsumed = item.quantityPerUnit * totalProduced;
      double totalCost = totalConsumed * item.unitCost;

      newReportItems.add(ManufacturingReportItem(
        rawMaterialId: item.rawMaterialId,
        rawMaterialName: item.rawMaterialName,
        totalQuantityConsumed: totalConsumed,
        totalAmount: totalCost,
      ));

      newTotalCost += totalCost;
    }

    setState(() {
      _calculatedMaterials = newReportItems;
      _totalProductionCost = newTotalCost;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manufacturing Calculator'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Production Input
            TextField(
              controller: _productionQtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Total Produced Quantity',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory),
                suffixText: 'units',
              ),
            ),
            const SizedBox(height: 24),
            
            // Results Title
            const Text(
              'Required Raw Materials:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Real-time Data Table
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                    columns: const [
                      DataColumn(label: Text('Material')),
                      DataColumn(label: Text('Req. Qty')),
                      DataColumn(label: Text('Est. Cost (₹)')),
                    ],
                    rows: _calculatedMaterials.map((item) {
                      return DataRow(cells: [
                        DataCell(Text(item.rawMaterialName)),
                        DataCell(Text('${item.totalQuantityConsumed.toStringAsFixed(2)}')),
                        DataCell(Text('₹${item.totalAmount.toStringAsFixed(2)}')),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),

            const Divider(),
            
            // Total Cost Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Estimated Cost:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                    '₹${_totalProductionCost.toStringAsFixed(2)}', 
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green.shade700)
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _totalProductionCost > 0 ? () {
                // Submit to backend logic goes here
                // e.g. Provider.of<DatabaseService>(context, listen: false).submitManufacturingBatch(...);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report ready for submission!'))
                );
              } : null,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              child: const Text('Submit Report'),
            )
          ],
        ),
      ),
    );
  }
}
