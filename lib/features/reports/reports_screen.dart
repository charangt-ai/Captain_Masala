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
  DateTime _selectedDate = DateTime.now();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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

  Future<void> _generateReport(String period, String format) async {
    setState(() => _isGenerating = true);
    try {
      final db = Provider.of<DatabaseService>(context, listen: false);
      DateTime filterStartDate;
      DateTime filterEndDate;
      
      if (period == 'Daily') {
        filterStartDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        filterEndDate = filterStartDate.add(const Duration(days: 1));
      } else if (period == 'Weekly') {
        final int daysToSubtract = _selectedDate.weekday == 7 ? 0 : _selectedDate.weekday;
        filterStartDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day).subtract(Duration(days: daysToSubtract));
        filterEndDate = filterStartDate.add(const Duration(days: 7));
      } else if (period == 'Monthly') {
        filterStartDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
        filterEndDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
      } else {
        filterStartDate = DateTime(_selectedDate.year, 1, 1);
        filterEndDate = DateTime(_selectedDate.year + 1, 1, 1);
      }

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
        path = '${directory.path}/captain_masala_${period.toLowerCase()}_report.csv';
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

  Widget _buildReportCard(String title, String subtitle, IconData icon, String period) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.primaryRed, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(color: AppColors.textLight, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : () => _generateReport(period, 'pdf'),
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('Download PDF'),
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
                    onPressed: _isGenerating ? null : () => _generateReport(period, 'csv'),
                    icon: const Icon(Icons.table_chart, size: 18),
                    label: const Text('Download CSV'),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Export Documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textDark)),
                  OutlinedButton.icon(
                    onPressed: () => _selectDate(context),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(DateFormat('MMM d, yyyy').format(_selectedDate)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryRed,
                      side: const BorderSide(color: AppColors.primaryRed),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildReportCard('Daily Report', "Today's transactions", Icons.today, 'Daily'),
              const SizedBox(height: 16),
              _buildReportCard('Weekly Report', 'Transactions from the last 7 days', Icons.date_range, 'Weekly'),
              const SizedBox(height: 16),
              _buildReportCard('Monthly Report', 'All transactions for the current month', Icons.calendar_month, 'Monthly'),
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
