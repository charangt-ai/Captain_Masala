import 'dart:convert';

class PlannedIngredient {
  final String? rawMaterialId;
  final String rawMaterialName;
  final double requiredQuantity;
  final double availableStock;
  final bool isSufficient;

  PlannedIngredient({
    this.rawMaterialId,
    required this.rawMaterialName,
    required this.requiredQuantity,
    required this.availableStock,
    required this.isSufficient,
  });

  Map<String, dynamic> toMap() {
    return {
      'rawMaterialId': rawMaterialId,
      'rawMaterialName': rawMaterialName,
      'requiredQuantity': requiredQuantity,
      'availableStock': availableStock,
      'isSufficient': isSufficient,
    };
  }

  factory PlannedIngredient.fromMap(Map<String, dynamic> map) {
    return PlannedIngredient(
      rawMaterialId: map['rawMaterialId'],
      rawMaterialName: map['rawMaterialName'] ?? '',
      requiredQuantity: (map['requiredQuantity'] as num?)?.toDouble() ?? 0.0,
      availableStock: (map['availableStock'] as num?)?.toDouble() ?? 0.0,
      isSufficient: map['isSufficient'] ?? false,
    );
  }
}

class ProductionPlan {
  final String? id;
  final String planNumber;
  final String masterProductId;
  final String masterProductName;
  final String recipeId;
  final double plannedBatchSize;
  final List<PlannedIngredient> plannedIngredients;
  final DateTime plannedDate;
  final String priority;
  final String status;
  final String? createdById;
  final String? createdByName;
  final String? notes;

  ProductionPlan({
    this.id,
    required this.planNumber,
    required this.masterProductId,
    required this.masterProductName,
    required this.recipeId,
    required this.plannedBatchSize,
    required this.plannedIngredients,
    required this.plannedDate,
    required this.priority,
    required this.status,
    this.createdById,
    this.createdByName,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'planNumber': planNumber,
      'masterProductId': masterProductId,
      'masterProductName': masterProductName,
      'recipeId': recipeId,
      'plannedBatchSize': plannedBatchSize,
      'plannedIngredients': plannedIngredients.map((x) => x.toMap()).toList(),
      'plannedDate': plannedDate.toIso8601String(),
      'priority': priority,
      'status': status,
      'createdById': createdById,
      'createdByName': createdByName,
      'notes': notes,
    };
  }

  factory ProductionPlan.fromMap(Map<String, dynamic> map) {
    return ProductionPlan(
      id: map['_id'] ?? map['id'],
      planNumber: map['planNumber'] ?? '',
      masterProductId: map['masterProductId'] ?? '',
      masterProductName: map['masterProductName'] ?? '',
      recipeId: map['recipeId'] ?? '',
      plannedBatchSize: (map['plannedBatchSize'] as num?)?.toDouble() ?? 0.0,
      plannedIngredients: List<PlannedIngredient>.from(
        (map['plannedIngredients'] as List<dynamic>? ?? []).map((x) => PlannedIngredient.fromMap(x)),
      ),
      plannedDate: map['plannedDate'] != null ? DateTime.parse(map['plannedDate']) : DateTime.now(),
      priority: map['priority'] ?? 'MEDIUM',
      status: map['status'] ?? 'DRAFT',
      createdById: map['createdById'],
      createdByName: map['createdByName'],
      notes: map['notes'],
    );
  }
}
