import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart' show debugPrint;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/models/manufacturing_batch.dart';

class BatchReportPdfGenerator {
  static Future<void> generateAndSharePdf(ManufacturingBatch batch) async {
    final pdf = pw.Document();

    // Theme colors
    final primaryOrange = PdfColor.fromHex('#E65100');
    final tableHeaderDark = PdfColor.fromHex('#1A233A');
    final tagYellow = PdfColor.fromHex('#FFF59D');
    final dividerColor = PdfColor.fromHex('#EEEEEE');
    
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 2);

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
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
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'MANUFACTURING REPORT',
                        style: pw.TextStyle(
                          color: tableHeaderDark,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Batch ID: ${batch.id != null ? batch.id!.substring(0, 8).toUpperCase() : 'N/A'}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 2),
                      pw.Text('Date: ${batch.timestamp != null ? dateFormat.format(batch.timestamp!) : 'N/A'}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 2),
                      pw.Text('Created by: ${batch.createdByName ?? 'N/A'}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 6),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: tagYellow,
                          borderRadius: pw.BorderRadius.circular(12),
                        ),
                        child: pw.Text(
                          batch.status ?? 'COMPLETED',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.brown900),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              pw.SizedBox(height: 16),
              pw.Divider(color: primaryOrange, thickness: 2),
              pw.SizedBox(height: 16),

              // Product and Raw Material Info
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: dividerColor),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('TARGET PRODUCT', style: pw.TextStyle(fontSize: 9, color: primaryOrange, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 4),
                          pw.Text(batch.targetProductName ?? 'Unknown', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: tableHeaderDark)),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: dividerColor),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('RAW MATERIAL', style: pw.TextStyle(fontSize: 9, color: primaryOrange, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 4),
                          pw.Text('${batch.rawMaterialName} (${batch.rawMaterialQuantity} kg)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: tableHeaderDark)),
                        ],
                      ),
                    ),
                  ),
                ]
              ),

              pw.SizedBox(height: 24),

              // Processing Table
              pw.Table(
                border: null,
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),   // #
                  1: const pw.FlexColumnWidth(3),     // STAGE
                  2: const pw.FlexColumnWidth(2),     // BEFORE
                  3: const pw.FlexColumnWidth(2),     // AFTER
                  4: const pw.FlexColumnWidth(2),     // LOSS
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: tableHeaderDark,
                      borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(6)),
                    ),
                    children: [
                      _buildHeaderCell('#'),
                      _buildHeaderCell('PROCESS STAGE'),
                      _buildHeaderCell('BEFORE (kg)', alignRight: true),
                      _buildHeaderCell('AFTER (kg)', alignRight: true),
                      _buildHeaderCell('LOSS (kg)', alignRight: true),
                    ],
                  ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200)),
                    ),
                    children: [
                      _buildDataCell('1'),
                      _buildDataCell('Drying'),
                      _buildDataCell(batch.weightBeforeDrying?.toStringAsFixed(2) ?? '-', alignRight: true),
                      _buildDataCell(batch.weightAfterDrying?.toStringAsFixed(2) ?? '-', alignRight: true),
                      _buildDataCell(batch.dryingLoss.toStringAsFixed(2), alignRight: true),
                    ],
                  ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200)),
                    ),
                    children: [
                      _buildDataCell('2'),
                      _buildDataCell('Grinding'),
                      _buildDataCell(batch.weightBeforeGrinding?.toStringAsFixed(2) ?? '-', alignRight: true),
                      _buildDataCell(batch.weightAfterGrinding?.toStringAsFixed(2) ?? '-', alignRight: true),
                      _buildDataCell(batch.grindingLoss.toStringAsFixed(2), alignRight: true),
                    ],
                  ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200)),
                    ),
                    children: [
                      _buildDataCell(''),
                      _buildDataCell('TOTAL LOSS', isTotal: true),
                      _buildDataCell(''),
                      _buildDataCell(''),
                      _buildDataCell(batch.totalLoss.toStringAsFixed(2), alignRight: true, isTotal: true, color: PdfColors.red800),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 24),

              // Summary Boxes
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  // Final Yield
                  pw.Container(
                    width: 200,
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#E8F5E9'), // Light Green
                      border: pw.Border.all(color: PdfColor.fromHex('#81C784')),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('FINAL YIELD', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#2E7D32'), fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('${batch.finalOutputWeight} kg', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1B5E20'))),
                        pw.SizedBox(height: 8),
                        pw.Text('Yield Percentage: ${batch.yieldPercentage.toStringAsFixed(2)}%', style: const pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),

                  // Cost Box
                  pw.Container(
                    width: 250,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: tableHeaderDark),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            color: tableHeaderDark,
                            borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(5)),
                          ),
                          child: pw.Text('COST SUMMARY', style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ),
                        
                        _buildSummaryRow('Raw Material Amount', currencyFormat.format(batch.rawMaterialAmount ?? 0)),
                        pw.Divider(height: 0, color: dividerColor),
                        _buildSummaryRow('GST (${batch.gstPercentage}%)', currencyFormat.format(batch.totalGstAmount)),
                        
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
                              pw.Text('TOTAL COST', style: pw.TextStyle(color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                              pw.Text('Rs. ${currencyFormat.format(batch.totalCost)}', 
                                style: pw.TextStyle(color: PdfColor.fromHex('#EF5350'), fontSize: 14, fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Footer
              pw.Center(
                child: pw.Column(
                  children: [
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

    try {
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/manufacturing_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());
      
      await Share.shareXFiles([XFile(file.path)], text: 'Manufacturing Batch Report - ${batch.targetProductName}');
    } catch (e) {
      debugPrint('Error generating PDF: $e');
    }
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

  static pw.Widget _buildDataCell(String text, {bool alignRight = false, bool isTotal = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          color: color ?? (isTotal ? PdfColor.fromHex('#00796B') : PdfColors.black),
          fontSize: 9,
          fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _buildSummaryRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 10)),
          pw.Text('Rs. $value', style: pw.TextStyle(color: PdfColors.black, fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
