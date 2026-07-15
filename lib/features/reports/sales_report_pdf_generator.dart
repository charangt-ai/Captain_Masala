import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/models/sale.dart';

class SalesReportPdfGenerator {
  static Future<File> generateReport(
    String period,
    List<Sale> filteredSales,
    double totalRevenue,
    double pendingAmount,
  ) async {
    final pdf = pw.Document();
    
    // Theme colors
    final primaryRed = PdfColor.fromHex('#C8102E');
    final greenColor = PdfColor.fromHex('#388E3C');
    final blueColor = PdfColor.fromHex('#1976D2');
    
    final now = DateTime.now();
    DateTime startDate;
    if (period == 'Daily') {
      startDate = DateTime(now.year, now.month, now.day);
    } else if (period == 'Weekly') {
      startDate = now.subtract(const Duration(days: 7));
    } else if (period == 'Monthly') {
      startDate = DateTime(now.year, now.month, 1);
    } else {
      startDate = DateTime(now.year, 1, 1);
    }
    
    final dateRange = '${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d, yyyy').format(now)}';
    final reportTitle = '${period.toUpperCase()} SALES REPORT';
    final billCount = filteredSales.length;
    
    // Create the page
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        // Header
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left Side Logo and Title
                  pw.Row(
                    children: [
                      // Circular Logo Placeholder
                      pw.Container(
                        width: 50,
                        height: 50,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          border: pw.Border.all(color: primaryRed, width: 2),
                        ),
                        child: pw.Center(
                          child: pw.Text('C', style: pw.TextStyle(color: primaryRed, fontWeight: pw.FontWeight.bold, fontSize: 24))
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('CAPTAIN MASALA', style: pw.TextStyle(color: primaryRed, fontWeight: pw.FontWeight.bold, fontSize: 24)),
                          pw.Text('Premium Spice Inventory System', style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  // Right Side Container
                  pw.Container(
                    width: 180,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: pw.BoxDecoration(
                      color: primaryRed,
                      borderRadius: const pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(24),
                        bottomLeft: pw.Radius.circular(24),
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(reportTitle, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12)),
                        pw.SizedBox(height: 4),
                        pw.Text(dateRange, style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                        pw.SizedBox(height: 8),
                        pw.Container(width: double.infinity, height: 1, color: PdfColors.white),
                        pw.SizedBox(height: 8),
                        pw.Text('Report Date: ${DateFormat('MMM d, yyyy HH:mm').format(now)}', style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColors.grey400),
            ],
          );
        },
        
        // Body
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 16),
            // Metrics Overview (3 Cards)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricCard('TOTAL PAID REVENUE', 'Rs. ${totalRevenue.toStringAsFixed(2)}', greenColor, 'R'),
                _buildMetricCard('TOTAL PENDING', 'Rs. ${pendingAmount.toStringAsFixed(2)}', primaryRed, 'P'),
                _buildMetricCard('TOTAL BILL COUNT', '$billCount', blueColor, 'B'),
              ],
            ),
            pw.SizedBox(height: 32),
            
            // Transaction Details Title
            pw.Row(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(color: primaryRed, shape: pw.BoxShape.circle),
                  child: pw.Text(' T ', style: pw.TextStyle(color: PdfColors.white, fontSize: 8)),
                ),
                pw.SizedBox(width: 8),
                pw.Text('TRANSACTION DETAILS', style: pw.TextStyle(color: primaryRed, fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.SizedBox(width: 8),
                pw.Expanded(child: pw.Divider(color: PdfColors.grey400)),
              ],
            ),
            pw.SizedBox(height: 16),
            
            // Transaction Details Table
            pw.TableHelper.fromTextArray(
              context: context,
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
              headerDecoration: pw.BoxDecoration(color: primaryRed),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              columnWidths: const {
                0: pw.FlexColumnWidth(0.8),
                1: pw.FlexColumnWidth(1.3),
                2: pw.FlexColumnWidth(1.1),
                3: pw.FlexColumnWidth(1.4),
                4: pw.FlexColumnWidth(1.8),
                5: pw.FlexColumnWidth(1.1),
                6: pw.FlexColumnWidth(1.1),
                7: pw.FlexColumnWidth(1.3),
              },
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerLeft,
                5: pw.Alignment.center,
                6: pw.Alignment.center,
                7: pw.Alignment.centerRight,
              },
              headers: ['Date', 'Bill No', 'Seller', 'Shop Name', 'Product', 'Qty', 'Status', 'Amount (Rs)'],
              data: filteredSales.map((sale) {
                final shopName = sale.shopName.isNotEmpty ? sale.shopName : sale.customerName;
                final dateStr = DateFormat('MMM\nd').format(sale.dateTime);
                
                final productNames = sale.items.map((item) => item.productName).join('\n');
                final quantities = sale.items.map((item) => '${item.packSize} x ${item.quantity.toInt()}').join('\n');
                var amounts = 'Total: Rs. ${sale.totalAmount.toStringAsFixed(2)}';
                if (sale.paymentStatus == 'Prepaid') {
                  amounts += '\nPrepaid: Rs. ${sale.prepaidAmount.toStringAsFixed(2)}\nDue: Rs. ${(sale.totalAmount - sale.prepaidAmount).toStringAsFixed(2)}';
                }
                
                return [
                  dateStr,
                  sale.invoiceNumber,
                  sale.sellerName,
                  shopName,
                  productNames,
                  quantities,
                  _buildStatusBadge(sale.paymentStatus),
                  amounts,
                ];
              }).toList(),
            ),
            
            pw.SizedBox(height: 32),
            
            // Summary Footer Block
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: primaryRed, width: 1.5),
                borderRadius: pw.BorderRadius.circular(8),
                color: PdfColors.grey100,
              ),
              padding: const pw.EdgeInsets.all(16),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: primaryRed,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Text('SUMMARY', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Total Paid Revenue', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                      pw.Text('Rs. ${totalRevenue.toStringAsFixed(2)}', style: pw.TextStyle(color: greenColor, fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Total Pending', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                      pw.Text('Rs. ${pendingAmount.toStringAsFixed(2)}', style: pw.TextStyle(color: primaryRed, fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Total Bill Count', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                      pw.Text('$billCount', style: pw.TextStyle(color: blueColor, fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
        
        // Footer
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Thank you for choosing Captain Masala!', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text('Quality Spices, Trusted Service.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Report Generated By', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.Text('Captain Masala Inventory System', style: pw.TextStyle(color: primaryRed, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ],
                  ),
                  pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ]
          );
        },
      )
    );
    
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/captain_masala_${period.toLowerCase()}_report.pdf';
    final file = File(path);
    await file.writeAsBytes(await pdf.save());
    return file;
  }
  
  static pw.Widget _buildMetricCard(String title, String amount, PdfColor color, String iconInitial) {
    return pw.Container(
      width: 140,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColors.white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 40,
            height: 40,
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              shape: pw.BoxShape.circle,
            ),
            child: pw.Center(
              child: pw.Text(iconInitial, style: pw.TextStyle(color: color, fontWeight: pw.FontWeight.bold, fontSize: 18))
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(title, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 8),
          pw.Text(amount, style: pw.TextStyle(color: color, fontWeight: pw.FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  static pw.Widget _buildStatusBadge(String status) {
    PdfColor bgColor;
    PdfColor textColor = PdfColors.white;
    
    switch (status.toLowerCase()) {
      case 'paid':
        bgColor = PdfColor.fromHex('#4CAF50'); // Green
        break;
      case 'prepaid':
        bgColor = PdfColor.fromHex('#FF9800'); // Orange
        break;
      case 'pending':
      case 'unpaid':
        bgColor = PdfColor.fromHex('#F44336'); // Red
        break;
      default:
        bgColor = PdfColors.grey;
    }
    
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        status,
        style: pw.TextStyle(
          color: textColor,
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }
}
