import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/services/database_service.dart';
import '../../core/theme.dart';
import '../../core/permissions.dart';
import '../../core/models/master_product.dart';

class VariantDeduction {
  final String packSize;
  final DateTime? date;
  double quantitySold = 0;
  double totalKg = 0;
  
  VariantDeduction(this.packSize, {this.date});
}

class MasterProductDeduction {
  final MasterProduct masterProduct;
  final Map<String, VariantDeduction> variantDeductions = {};
  
  MasterProductDeduction(this.masterProduct);
  
  double get totalKg => variantDeductions.values.fold(0.0, (sum, v) => sum + v.totalKg);
}

class InventoryDeductionReportScreen extends StatefulWidget {
  const InventoryDeductionReportScreen({Key? key}) : super(key: key);

  @override
  State<InventoryDeductionReportScreen> createState() => _InventoryDeductionReportScreenState();
}

class _InventoryDeductionReportScreenState extends State<InventoryDeductionReportScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedPeriod = 'Daily';
  bool _isGenerating = false;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryRed,
              onPrimary: Colors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  List<MasterProductDeduction> _calculateDeductions(DatabaseService db) {
    // Filter sales for the selected date
    final targetDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    
    var filteredSales = db.sales.where((s) {
      final saleDate = DateTime(s.dateTime.year, s.dateTime.month, s.dateTime.day);
      if (_selectedPeriod == 'Daily') {
        return saleDate.isAtSameMomentAs(targetDate);
      } else if (_selectedPeriod == 'Weekly') {
        final startOfWeek = targetDate.subtract(const Duration(days: 7));
        return saleDate.isAfter(startOfWeek) && (saleDate.isBefore(targetDate) || saleDate.isAtSameMomentAs(targetDate));
      } else if (_selectedPeriod == 'Monthly') {
        return saleDate.year == targetDate.year && saleDate.month == targetDate.month;
      }
      return false;
    }).toList();

    // If seller, only show their sales
    if (Permissions.isSeller(db.currentUserProfile?.role)) {
      filteredSales = filteredSales.where((s) => s.sellerId == db.currentUserProfile!.id).toList();
    }

    final Map<String, MasterProductDeduction> deductionsMap = {};

    for (var sale in filteredSales) {
      // Only count active/paid/pending sales, not cancelled
      if (sale.status == 'Cancelled') continue;

      for (var item in sale.items) {
        try {
          final product = db.products.firstWhere((p) => p.id == item.productId);
          final masterId = product.masterProductId;
          
          if (masterId.isEmpty) continue;

          final masterProduct = db.masterProducts.firstWhere((mp) => mp.id == masterId);
          
          deductionsMap.putIfAbsent(masterId, () => MasterProductDeduction(masterProduct));
          final mpDeduction = deductionsMap[masterId]!;
          
          final saleDate = DateTime(sale.dateTime.year, sale.dateTime.month, sale.dateTime.day);
          final key = '${item.packSize}_${saleDate.millisecondsSinceEpoch}';
          
          mpDeduction.variantDeductions.putIfAbsent(key, () => VariantDeduction(item.packSize, date: saleDate));
          final variantDeduction = mpDeduction.variantDeductions[key]!;
          
          variantDeduction.quantitySold += item.quantity;
          
          // Calculate weight in kg using the centralized helper
          double weightInKg = db.getPackSizeInKg(item.packSize);
          
          variantDeduction.totalKg += (item.quantity * weightInKg);
        } catch (e) {
          // Ignore if product or master product is not found
        }
      }
    }

    final list = deductionsMap.values.toList();
    // Sort by name
    list.sort((a, b) => a.masterProduct.name.compareTo(b.masterProduct.name));
    return list;
  }

  Future<void> _exportToPdf(List<MasterProductDeduction> deductions) async {
    setState(() => _isGenerating = true);
    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      
      double grandTotalKg = deductions.fold(0.0, (sum, d) => sum + d.totalKg);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('CAPTAIN MASALA', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                pw.SizedBox(height: 4),
                pw.Text('Inventory Deduction Report', style: const pw.TextStyle(fontSize: 16, color: PdfColors.grey700)),
                pw.SizedBox(height: 12),
                pw.Divider(color: PdfColors.grey400),
                pw.SizedBox(height: 16),
              ],
            );
          },
          build: (pw.Context context) {
            final List<pw.Widget> content = [];
            
            content.add(
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Period: $_selectedPeriod', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date: ${DateFormat('MMM d, yyyy').format(_selectedDate)}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: pw.BoxDecoration(color: PdfColors.red50, borderRadius: pw.BorderRadius.circular(8)),
                    child: pw.Column(
                      children: [
                        pw.Text('Total Weight Deducted', style: const pw.TextStyle(fontSize: 10, color: PdfColors.red900)),
                        pw.Text('${grandTotalKg.toStringAsFixed(2)} kg', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                      ],
                    ),
                  ),
                ],
              )
            );
            
            content.add(pw.SizedBox(height: 24));

            if (deductions.isEmpty) {
              content.add(pw.Center(child: pw.Text('No deductions found for this period.', style: const pw.TextStyle(color: PdfColors.grey))));
            } else {
              for (var item in deductions) {
                content.add(
                  pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 16),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          color: PdfColors.grey200,
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(item.masterProduct.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.end,
                                children: [
                                  pw.Text('Deducted: ${item.totalKg.toStringAsFixed(2)} kg', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red800, fontSize: 12)),
                                  pw.Text('Remaining: ${item.masterProduct.totalStockKg.toStringAsFixed(2)} kg', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green700, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        pw.TableHelper.fromTextArray(
                          context: context,
                          border: pw.TableBorder.all(color: PdfColors.grey300),
                          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                          cellAlignment: pw.Alignment.centerLeft,
                          headers: ['Date', 'Variant (Pack Size)', 'Packs Sold', 'Equivalent Weight (kg)'],
                          data: () {
                            final sorted = item.variantDeductions.values.toList();
                            sorted.sort((a, b) {
                              final dateCompare = (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0));
                              if (dateCompare != 0) return dateCompare;
                              return b.totalKg.compareTo(a.totalKg);
                            });
                            return sorted.map((v) => [
                              v.date != null ? DateFormat('MMM d, yyyy').format(v.date!) : '-',
                              v.packSize,
                              '${v.quantitySold.toInt()}',
                              v.totalKg.toStringAsFixed(2),
                            ]).toList();
                          }(),
                        ),
                      ],
                    ),
                  )
                );
              }
            }

            return content;
          },
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 16),
              child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
            );
          },
        ),
      );

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/captain_masala_inventory_${_selectedPeriod.toLowerCase()}.pdf';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        final box = context.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          [XFile(path)],
          subject: 'Captain Masala $_selectedPeriod Inventory Report',
          sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: AppColors.outOfStockAlert));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final deductions = _calculateDeductions(db);
    final dateFormat = DateFormat('EEEE, MMM d, yyyy');

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Inventory Deductions'),
        elevation: 0,
        actions: [
          IconButton(
            icon: _isGenerating 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf),
            onPressed: _isGenerating ? null : () => _exportToPdf(deductions),
            tooltip: 'Download PDF',
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Selector Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: AppColors.primaryRed,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Report Date',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateFormat.format(_selectedDate),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _selectDate(context),
                  icon: const Icon(Icons.calendar_month, size: 20),
                  label: const Text('Change'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          
          // Period Toggle
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: ToggleButtons(
                isSelected: ['Daily', 'Weekly', 'Monthly'].map((e) => e == _selectedPeriod).toList(),
                onPressed: (index) {
                  setState(() {
                    _selectedPeriod = ['Daily', 'Weekly', 'Monthly'][index];
                  });
                },
                color: AppColors.textLight,
                selectedColor: AppColors.primaryRed,
                fillColor: AppColors.primaryRed.withOpacity(0.1),
                borderColor: Colors.grey.shade300,
                selectedBorderColor: AppColors.primaryRed,
                borderRadius: BorderRadius.circular(8),
                constraints: const BoxConstraints(minHeight: 36, minWidth: 90),
                children: const [
                  Text('Daily'),
                  Text('Weekly'),
                  Text('Monthly'),
                ],
              ),
            ),
          ),
          
          // List of Deductions
          Expanded(
            child: deductions.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.black26),
                        SizedBox(height: 16),
                        Text('No inventory deductions for this date.', style: TextStyle(color: Colors.black54, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: deductions.length,
                    itemBuilder: (context, index) {
                      final item = deductions[index];
                      final variants = item.variantDeductions.values.toList();
                      variants.sort((a, b) {
                        final dateCompare = (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0));
                        if (dateCompare != 0) return dateCompare;
                        return b.totalKg.compareTo(a.totalKg);
                      });

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        clipBehavior: Clip.antiAlias,
                        child: ExpansionTile(
                          collapsedBackgroundColor: Colors.white,
                          backgroundColor: Colors.grey.shade50,
                          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryRed.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.category, color: AppColors.primaryRed),
                          ),
                          title: Text(
                            item.masterProduct.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.arrow_downward, size: 14, color: AppColors.primaryRed),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Deducted: ${item.totalKg.toStringAsFixed(2)} kg',
                                      style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.inventory, size: 14, color: Colors.green),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Remaining Stock: ${item.masterProduct.totalStockKg.toStringAsFixed(2)} kg',
                                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          children: [
                            Container(
                              color: Colors.white,
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: const [
                                      Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textLight))),
                                      Expanded(flex: 2, child: Text('Variant (Pack)', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textLight))),
                                      Expanded(flex: 1, child: Text('Sold', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textLight))),
                                      Expanded(flex: 1, child: Text('Weight', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textLight))),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  ...variants.map((v) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            v.date != null ? DateFormat('MMM d').format(v.date!) : '-',
                                            style: const TextStyle(fontSize: 14, color: AppColors.textLight),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Row(
                                            children: [
                                              const Icon(Icons.inventory, size: 16, color: Colors.black38),
                                              const SizedBox(width: 4),
                                              Text(v.packSize, style: const TextStyle(fontSize: 14)),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            '${v.quantitySold.toInt()} packs',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            '${v.totalKg.toStringAsFixed(2)} kg',
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )).toList(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
