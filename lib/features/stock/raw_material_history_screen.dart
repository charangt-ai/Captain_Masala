import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_config.dart';
import '../../core/theme.dart';

class RawMaterialHistoryScreen extends StatefulWidget {
  final String materialId;
  final String materialName;

  const RawMaterialHistoryScreen({
    Key? key,
    required this.materialId,
    required this.materialName,
  }) : super(key: key);

  @override
  State<RawMaterialHistoryScreen> createState() => _RawMaterialHistoryScreenState();
}

class _RawMaterialHistoryScreenState extends State<RawMaterialHistoryScreen> {
  List<dynamic> _historyLogs = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'jwt_token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/inventory/raw-materials/${widget.materialId}/history'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        setState(() {
          _historyLogs = decoded['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load history: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.materialName} History'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                      ElevatedButton(
                        onPressed: _fetchHistory,
                        child: const Text('Retry'),
                      )
                    ],
                  ),
                )
              : _historyLogs.isEmpty
                  ? const Center(child: Text('No history logs found for this material.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _historyLogs.length,
                      itemBuilder: (context, index) {
                        final log = _historyLogs[index];
                        final changeQty = (log['changeQuantity'] as num?)?.toDouble() ?? 0.0;
                        final type = log['type'] ?? 'Unknown';
                        final notes = log['notes'] ?? '';
                        final dateTimeStr = log['dateTime'];
                        final dateTime = dateTimeStr != null ? DateTime.tryParse(dateTimeStr) : null;
                        
                        final isDeduction = changeQty < 0;

                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDeduction ? Colors.orange.shade50 : Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: isDeduction ? Colors.orange.shade200 : Colors.green.shade200),
                                      ),
                                      child: Text(
                                        type,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isDeduction ? Colors.orange.shade800 : Colors.green.shade800,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${isDeduction ? "" : "+"}${changeQty.toStringAsFixed(2)} kg',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isDeduction ? Colors.red : Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (notes.isNotEmpty) ...[
                                  Text(
                                    notes,
                                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                if (dateTime != null)
                                  Text(
                                    DateFormat('dd MMM yyyy, hh:mm a').format(dateTime.toLocal()),
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
