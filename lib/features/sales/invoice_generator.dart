import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../core/models/sale.dart';

class InvoiceGenerator {
  static Future<File> generateInvoice(Sale sale, {String customerPhone = '', String customerAddress = '', bool showDeliveryStatus = false}) async {
    final pdf = pw.Document();
    final billedShopName = sale.shopName.isNotEmpty ? sale.shopName : sale.customerName;

    // Define colors matching the reference image
    final primaryOrange = PdfColor.fromHex('#E65100');
    final tableHeaderDark = PdfColor.fromHex('#1A233A');
    final tagYellow = PdfColor.fromHex('#FFF59D');
    final netAmountGreen = PdfColor.fromHex('#004D40');
    final dividerColor = PdfColor.fromHex('#EEEEEE');
    
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 2);

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          double totalTaxableAmount = 0.0;
          double totalSgst = 0.0;
          double totalCgst = 0.0;

          for (var item in sale.items) {
            final totalIncl = item.totalAmount;
            final taxable = totalIncl / 1.05;
            final sgst = (totalIncl - taxable) / 2;
            final cgst = (totalIncl - taxable) / 2;
            totalTaxableAmount += taxable;
            totalSgst += sgst;
            totalCgst += cgst;
          }
          final calculatedNetAmount = totalTaxableAmount + totalSgst + totalCgst;

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left side company details
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CAPTAIN MASALA AND SPICES',
                        style: pw.TextStyle(
                          color: primaryOrange,
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text('GSTIN: 33AAVFC7408B1ZK', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
                      pw.SizedBox(height: 2),
                      pw.Text('3/238-B , PUTHUR ITTERI ROAD, NETHIMEDU, SALEM-636002, TAMILNADU', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
                      pw.SizedBox(height: 2),
                      pw.Text('Ph: 9345636001 | feedback@captainmasala.com', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
                    ],
                  ),
                  // Right side invoice details
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'SALES ORDER',
                        style: pw.TextStyle(
                          color: tableHeaderDark,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Bill No: ${sale.invoiceNumber}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 2),
                      pw.Text('Date: ${dateFormat.format(sale.dateTime)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 2),
                      pw.Text('Handled by: ${sale.sellerName}${sale.sellerRole != null ? ' - ${sale.sellerRole}' : ''}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 6),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: tagYellow,
                          borderRadius: pw.BorderRadius.circular(12),
                        ),
                        child: pw.Text(
                          sale.paymentStatus.toUpperCase(),
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.brown900),
                        ),
                      ),
                      if (showDeliveryStatus) ...[
                        pw.SizedBox(height: 6),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: sale.deliveryStatus == 'Delivered' ? PdfColor.fromHex('#C8E6C9') : PdfColor.fromHex('#FFE0B2'),
                            borderRadius: pw.BorderRadius.circular(12),
                          ),
                          child: pw.Text(
                            sale.deliveryStatus.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 10, 
                              fontWeight: pw.FontWeight.bold, 
                              color: sale.deliveryStatus == 'Delivered' ? PdfColor.fromHex('#1B5E20') : PdfColor.fromHex('#E65100')
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              
              pw.SizedBox(height: 16),
              pw.Divider(color: primaryOrange, thickness: 2),
              pw.SizedBox(height: 16),

              // Billed To Section
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: dividerColor),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('BILLED TO', style: pw.TextStyle(fontSize: 9, color: primaryOrange, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      billedShopName,
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: tableHeaderDark),
                    ),
                    if (customerPhone.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text('Ph: $customerPhone', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                    if (customerAddress.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(customerAddress, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ],
                ),
              ),

              pw.SizedBox(height: 24),

              // Items Table
              pw.Table(
                border: null,
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),   // #
                  1: const pw.FlexColumnWidth(3),     // DESCRIPTION
                  2: const pw.FlexColumnWidth(1),     // RATE
                  3: const pw.FixedColumnWidth(40),   // QTY
                  4: const pw.FlexColumnWidth(1),     // TAXABLE VALUE
                  5: const pw.FlexColumnWidth(1),     // SGST
                  6: const pw.FlexColumnWidth(1),     // CGST
                  7: const pw.FlexColumnWidth(1.2),   // TOTAL
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: tableHeaderDark,
                      borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(6)),
                    ),
                    children: [
                      _buildHeaderCell('#'),
                      _buildHeaderCell('DESCRIPTION'),
                      _buildHeaderCell('RATE\n(EXCL.)', alignRight: true),
                      _buildHeaderCell('QTY', alignRight: true),
                      _buildHeaderCell('TAXABLE\nVALUE', alignRight: true),
                      _buildHeaderCell('SGST\n(Rs.)', alignRight: true),
                      _buildHeaderCell('CGST\n(Rs.)', alignRight: true),
                      _buildHeaderCell('TOTAL\n(INCL.)', alignRight: true),
                    ],
                  ),
                  
                  // Items
                  ...sale.items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    
                    // Simple logic for GST math based on the provided reference (reverse calculating from total)
                    // Assuming GST is included in the rate for simple display, or we calculate a mock 5% if not provided
                    // Based on reference image: 15.01 total -> 14.29 taxable -> 0.36 SGST + 0.36 CGST.
                    // We will just do a standard 5% tax deduction if we assume the rate in app is total incl tax.
                    final totalIncl = item.totalAmount;
                    final taxable = totalIncl / 1.05;
                    final sgst = (totalIncl - taxable) / 2;
                    final cgst = (totalIncl - taxable) / 2;
                    final rateExcl = taxable / item.quantity;

                    return pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200)),
                      ),
                      children: [
                        _buildDataCell('${index + 1}'),
                        _buildDescriptionCell(item.productName, item.packSize),
                        _buildDataCell(currencyFormat.format(rateExcl), alignRight: true),
                        _buildDataCell(item.quantity.toStringAsFixed(0), alignRight: true),
                        _buildDataCell(currencyFormat.format(taxable), alignRight: true),
                        _buildDataCell(currencyFormat.format(sgst), alignRight: true),
                        _buildDataCell(currencyFormat.format(cgst), alignRight: true),
                        _buildDataCell(currencyFormat.format(totalIncl), alignRight: true, isTotal: true),
                      ],
                    );
                  }).toList(),
                ],
              ),

              pw.SizedBox(height: 24),

              // Summary Box
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 250,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: tableHeaderDark),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      children: [
                        // Header
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            color: tableHeaderDark,
                            borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(5)),
                          ),
                          child: pw.Text('GST SUMMARY', style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ),
                        
                        // Body calculations
                        _buildSummaryRow('Taxable Amount', currencyFormat.format(totalTaxableAmount)),
                        pw.Divider(height: 0, color: dividerColor),
                        _buildSummaryRow('SGST', currencyFormat.format(totalSgst)),
                        pw.Divider(height: 0, color: dividerColor),
                        _buildSummaryRow('CGST', currencyFormat.format(totalCgst)),
                        
                        if (sale.discount > 0) ...[
                          pw.Divider(height: 0, color: dividerColor),
                          _buildSummaryRow('Discount', '- ${currencyFormat.format(sale.discount)}', color: PdfColors.red),
                        ],
                        
                        if (sale.prepaidAmount > 0) ...[
                          pw.Divider(height: 0, color: dividerColor),
                          _buildSummaryRow('Prepaid Amount', '- ${currencyFormat.format(sale.prepaidAmount)}', color: PdfColors.green),
                        ],

                        // Net Amount Footer
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: pw.BoxDecoration(
                            color: tableHeaderDark,
                            borderRadius: const pw.BorderRadius.vertical(bottom: pw.Radius.circular(5)),
                          ),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('NET AMOUNT', style: pw.TextStyle(color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                              pw.Text('Rs. ${currencyFormat.format(calculatedNetAmount - sale.discount - sale.prepaidAmount)}', 
                                style: pw.TextStyle(color: PdfColors.green400, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Footer message
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('Thank you for your business!', style: pw.TextStyle(color: primaryOrange, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('This is a computer-generated document. No signature required.', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 9)),
                    pw.SizedBox(height: 2),
                    pw.Text('Generated on ${DateFormat('M/d/yyyy').format(DateTime.now())}', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // Save PDF to file
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/invoice_${sale.invoiceNumber}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _buildHeaderCell(String text, {bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _buildDataCell(String text, {bool alignRight = false, bool isTotal = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          color: isTotal ? PdfColor.fromHex('#00796B') : PdfColors.black,
          fontSize: 9,
          fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _buildDescriptionCell(String name, String packSize) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(name, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(packSize, style: const pw.TextStyle(fontSize: 8, color: PdfColors.red700)),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryRow(String label, String value, {PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 10)),
          pw.Text('Rs. $value', style: pw.TextStyle(color: color ?? PdfColors.black, fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
