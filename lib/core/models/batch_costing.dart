class OverheadCost {
  final double labor;
  final double electricity;
  final double fuel;
  final double depreciation;
  final double miscellaneous;
  final double subtotal;

  OverheadCost({
    this.labor = 0,
    this.electricity = 0,
    this.fuel = 0,
    this.depreciation = 0,
    this.miscellaneous = 0,
    this.subtotal = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'labor': labor,
      'electricity': electricity,
      'fuel': fuel,
      'depreciation': depreciation,
      'miscellaneous': miscellaneous,
      'subtotal': subtotal,
    };
  }

  factory OverheadCost.fromMap(Map<String, dynamic> map) {
    return OverheadCost(
      labor: (map['labor'] as num?)?.toDouble() ?? 0,
      electricity: (map['electricity'] as num?)?.toDouble() ?? 0,
      fuel: (map['fuel'] as num?)?.toDouble() ?? 0,
      depreciation: (map['depreciation'] as num?)?.toDouble() ?? 0,
      miscellaneous: (map['miscellaneous'] as num?)?.toDouble() ?? 0,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
    );
  }
}

class BatchCosting {
  final String? id;
  final String costingNumber;
  final String? productionPlanId;
  final String? manufacturingBatchId;
  final String? masterProductId;
  final String? masterProductName;
  final String? batchNumber;
  final double totalCost;
  final double outputQuantity;
  final double costPerKg;
  final double processLossPercentage;
  final OverheadCost overheadCost;

  BatchCosting({
    this.id,
    required this.costingNumber,
    this.productionPlanId,
    this.manufacturingBatchId,
    this.masterProductId,
    this.masterProductName,
    this.batchNumber,
    required this.totalCost,
    required this.outputQuantity,
    required this.costPerKg,
    required this.processLossPercentage,
    required this.overheadCost,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'costingNumber': costingNumber,
      'productionPlanId': productionPlanId,
      'manufacturingBatchId': manufacturingBatchId,
      'masterProductId': masterProductId,
      'masterProductName': masterProductName,
      'batchNumber': batchNumber,
      'totalCost': totalCost,
      'outputQuantity': outputQuantity,
      'costPerKg': costPerKg,
      'processLossPercentage': processLossPercentage,
      'overheadCost': overheadCost.toMap(),
    };
  }

  factory BatchCosting.fromMap(Map<String, dynamic> map) {
    return BatchCosting(
      id: map['_id'] ?? map['id'],
      costingNumber: map['costingNumber'] ?? '',
      productionPlanId: map['productionPlanId'],
      manufacturingBatchId: map['manufacturingBatchId'],
      masterProductId: map['masterProductId'],
      masterProductName: map['masterProductName'],
      batchNumber: map['batchNumber'],
      totalCost: (map['totalCost'] as num?)?.toDouble() ?? 0.0,
      outputQuantity: (map['outputQuantity'] as num?)?.toDouble() ?? 0.0,
      costPerKg: (map['costPerKg'] as num?)?.toDouble() ?? 0.0,
      processLossPercentage: (map['processLossPercentage'] as num?)?.toDouble() ?? 0.0,
      overheadCost: map['overheadCost'] != null ? OverheadCost.fromMap(map['overheadCost']) : OverheadCost(),
    );
  }
}
