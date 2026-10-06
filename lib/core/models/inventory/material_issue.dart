import 'dart:convert';

class MaterialIssueItem {
  final String rawMaterialId;
  final String rawMaterialName;
  final double requestedQuantity;
  final double issuedQuantity;
  final String unit;
  final String? batchNumber;

  MaterialIssueItem({
    required this.rawMaterialId,
    required this.rawMaterialName,
    required this.requestedQuantity,
    required this.issuedQuantity,
    required this.unit,
    this.batchNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'rawMaterialId': rawMaterialId,
      'rawMaterialName': rawMaterialName,
      'requestedQuantity': requestedQuantity,
      'issuedQuantity': issuedQuantity,
      'unit': unit,
      'batchNumber': batchNumber,
    };
  }

  factory MaterialIssueItem.fromMap(Map<String, dynamic> map) {
    return MaterialIssueItem(
      rawMaterialId: map['rawMaterialId'] ?? '',
      rawMaterialName: map['rawMaterialName'] ?? '',
      requestedQuantity: (map['requestedQuantity'] as num?)?.toDouble() ?? 0.0,
      issuedQuantity: (map['issuedQuantity'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] ?? 'kg',
      batchNumber: map['batchNumber'],
    );
  }
}

class MaterialIssue {
  final String? id;
  final String issueNumber;
  final String productionPlanId;
  final List<MaterialIssueItem> items;
  final String status;
  final String? issuedById;
  final String? issuedByName;
  final DateTime? issuedAt;
  final String? notes;

  MaterialIssue({
    this.id,
    required this.issueNumber,
    required this.productionPlanId,
    required this.items,
    this.status = 'PENDING',
    this.issuedById,
    this.issuedByName,
    this.issuedAt,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'issueNumber': issueNumber,
      'productionPlanId': productionPlanId,
      'items': items.map((x) => x.toMap()).toList(),
      'status': status,
      'issuedById': issuedById,
      'issuedByName': issuedByName,
      'issuedAt': issuedAt?.toIso8601String(),
      'notes': notes,
    };
  }

  factory MaterialIssue.fromMap(Map<String, dynamic> map) {
    return MaterialIssue(
      id: map['_id'] ?? map['id'],
      issueNumber: map['issueNumber'] ?? '',
      productionPlanId: map['productionPlanId'] ?? '',
      items: List<MaterialIssueItem>.from(
        (map['items'] as List<dynamic>? ?? []).map((x) => MaterialIssueItem.fromMap(x)),
      ),
      status: map['status'] ?? 'PENDING',
      issuedById: map['issuedById'],
      issuedByName: map['issuedByName'],
      issuedAt: map['issuedAt'] != null ? DateTime.tryParse(map['issuedAt'].toString()) : null,
      notes: map['notes'],
    );
  }
}
