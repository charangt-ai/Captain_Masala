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
import '../../core/models/sale.dart';
import 'inventory_deduction_report.dart';
import 'sales_report_pdf_generator.dart';

class ReportsScreen extends StatefulWidget {
  final bool isEmbedded;

  const ReportsScreen({Key? key, this.isEmbedded = false}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isGenerating = false;
  String _selectedFilter = 'Daily';
  DateTime? _startDate;
  DateTime? _endDate;
  final List<String> _filters = ['Daily', 'Weekly', 'Monthly', 'Custom'];

  @override
  void initState() {
    super.initState();
    _calculateDatesForFilter(_selectedFilter);
  }

  void _calculateDatesForFilter(String filter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day); 

    setState(() {
      _selectedFilter = filter;
      switch (filter) {
        case 'Daily':
          _startDate = today;
          _endDate = today;
          break;
        case 'Weekly':
          final int daysToSubtract = today.weekday == 7 ? 6 : today.weekday - 1; // Start of week (Monday)
          _startDate = today.subtract(Duration(days: daysToSubtract));
          _endDate = today;
          break;
        case 'Monthly':
          _startDate = DateTime(today.year, today.month, 1);
          _endDate = today;
          break;
        case 'Custom':
          break;
      }
    });
  }

  Future<void> _selectCustomDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: (_startDate != null && _endDate != null)
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
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

    if (picked != null) {
      setState(() {
        _selectedFilter = 'Custom';
        _startDate = picked.start;
        _endDate = picked.end;
      });
    } else {
      if (_startDate == null || _endDate == null) {
        _calculateDatesForFilter('Daily');
      }
    }
  }

  String get _formattedDateRange {
    if (_startDate == null || _endDate == null) return 'Select a date range';
    final formatter = DateFormat('MMM dd, yyyy');
    if (_startDate == _endDate) {
      return formatter.format(_startDate!);
    }
    return '${formatter.format(_startDate!)} - ${formatter.format(_endDate!)}';
  }

  bool get _isDownloadReady {
    return _startDate != null && _endDate != null;
  }

  Future<void> _generateReport(String format) async {
    if (!_isDownloadReady) return;
    setState(() => _isGenerating = true);
    try {
      final db = Provider.of<DatabaseService>(context, listen: false);
      DateTime filterStartDate = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      DateTime filterEndDate = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59, 999);
      String period = _selectedFilter == 'Custom' ? _formattedDateRange : _selectedFilter;

      var filteredSales = db.sales.where((s) => s.dateTime.isAfter(filterStartDate) && s.dateTime.isBefore(filterEndDate)).toList();

      if (db.currentUserProfile?.role == 'seller') {
        filteredSales = filteredSales.where((s) => s.sellerId == db.currentUserProfile!.id).toList();
      }

      if (filteredSales.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No data found for $period period.'), backgroundColor: AppColors.outOfStockAlert),
          );
        }
        return;
      }

      String path;
      if (format == 'pdf') {
        double totalRevenue = 0;
        double pendingAmount = 0;

        for (var sale in filteredSales) {
          if (sale.paymentStatus == 'Paid') {
            totalRevenue += sale.totalAmount;
          } else {
            pendingAmount += sale.totalAmount;
          }
        }

        final file = await SalesReportPdfGenerator.generateReport(
          period,
          filteredSales,
          totalRevenue,
          pendingAmount,
        );
        path = file.path;
      } else {
        final buffer = StringBuffer();
        buffer.writeln('Date,Bill No,Seller,Shop Name,Product Name,Quantity,Payment Status,Amount (Rs)');
        for (var sale in filteredSales) {
          final shopName = sale.shopName.isNotEmpty ? sale.shopName : sale.customerName;
          final dateStr = DateFormat('yyyy-MM-dd').format(sale.dateTime);
          for (var item in sale.items) {
            final formattedQty = '${item.packSize} x ${item.quantity.toInt()}';
            buffer.writeln('$dateStr,"${sale.invoiceNumber}","${sale.sellerName}","$shopName","${item.productName}","$formattedQty",${sale.paymentStatus},${item.totalAmount}');
          }
        }
        final directory = await getTemporaryDirectory();
        final safePeriod = period.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
        path = '${directory.path}/captain_masala_${safePeriod}_report.csv';
        final file = File(path);
        await file.writeAsString(buffer.toString());
      }

      if (mounted) {
        final box = context.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          [XFile(path)],
          subject: 'Captain Masala $period Report',
          sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate report: $e'), backgroundColor: AppColors.outOfStockAlert),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Widget _buildInteractiveReportCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryDeductionReportScreen()));
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.inventory_2, color: AppColors.primaryRed, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Inventory Deduction Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark)),
                    SizedBox(height: 4),
                    Text('Daily summary of stock sold by variant', style: TextStyle(color: AppColors.textLight, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: AppColors.textLight, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    
    Widget body = Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Data Export',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppColors.textDark),
              ),
              const SizedBox(height: 8),
              const Text(
                "Select a time period below to generate a detailed report of all sales transactions. You can download it as a branded PDF or a raw CSV for Excel.",
                style: TextStyle(color: AppColors.textLight, fontSize: 14),
              ),
              if (db.currentUserProfile?.role != 'seller') ...[
                const SizedBox(height: 32),
                const Text('Interactive Reports', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textDark)),
                const SizedBox(height: 16),
                _buildInteractiveReportCard(context),
              ],
              const SizedBox(height: 32),
              const Text('Export Documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textDark)),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: _filters.map((filter) {
                          final isSelected = _selectedFilter == filter;
                          return ChoiceChip(
                            label: Text(filter),
                            selected: isSelected,
                            selectedColor: AppColors.primaryRed.withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.primaryRed : AppColors.textDark,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                if (filter == 'Custom') {
                                  _selectCustomDateRange(context);
                                } else {
                                  _calculateDatesForFilter(filter);
                                }
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () => _selectCustomDateRange(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.shade50,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _formattedDateRange,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                              if (_selectedFilter == 'Custom')
                                const Icon(Icons.edit, size: 18, color: AppColors.primaryRed),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (!_isGenerating && _isDownloadReady) ? () => _generateReport('pdf') : null,
                              icon: const Icon(Icons.picture_as_pdf, size: 18),
                              label: const Text('PDF'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryRed,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (!_isGenerating && _isDownloadReady) ? () => _generateReport('csv') : null,
                              icon: const Icon(Icons.table_chart, size: 18),
                              label: const Text('CSV'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isGenerating)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Generating Report...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    if (widget.isEmbedded) {
      return Scaffold(backgroundColor: Colors.grey.shade50, body: body);
    }
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(title: const Text('Sales Reports')),
      body: body,
    );
  }
}
