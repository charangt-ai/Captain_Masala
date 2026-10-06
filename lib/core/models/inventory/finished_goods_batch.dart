class FinishedGoodsBatch {
  final String? id;
  final String batchNumber;
  final String masterProductId;
  final String? masterProductName;
  final String? productionPlanId;
  final String? manufacturingBatchId;
  final String? qcId;
  final double initialQuantity;
  final double currentQuantity;
  final String unit;
  final DateTime manufacturingDate;
  final DateTime expiryDate;
  final double costPerKg;
  final String status;

  FinishedGoodsBatch({
    this.id,
    required this.batchNumber,
    required this.masterProductId,
    this.masterProductName,
    this.productionPlanId,
    this.manufacturingBatchId,
    this.qcId,
    required this.initialQuantity,
    required this.currentQuantity,
    this.unit = 'kg',
    required this.manufacturingDate,
    required this.expiryDate,
    this.costPerKg = 0.0,
    this.status = 'ACTIVE',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'batchNumber': batchNumber,
      'masterProductId': masterProductId,
      'masterProductName': masterProductName,
      'productionPlanId': productionPlanId,
      'manufacturingBatchId': manufacturingBatchId,
      'qcId': qcId,
      'initialQuantity': initialQuantity,
      'currentQuantity': currentQuantity,
      'unit': unit,
      'manufacturingDate': manufacturingDate.toIso8601String(),
      'expiryDate': expiryDate.toIso8601String(),
      'costPerKg': costPerKg,
      'status': status,
    };
  }

  factory FinishedGoodsBatch.fromMap(Map<String, dynamic> map) {
    return FinishedGoodsBatch(
      id: map['_id'] ?? map['id'],
      batchNumber: map['batchNumber'] ?? '',
      masterProductId: map['masterProductId'] ?? '',
      masterProductName: map['masterProductName'],
      productionPlanId: map['productionPlanId'],
      manufacturingBatchId: map['manufacturingBatchId'],
      qcId: map['qcId'],
      initialQuantity: (map['initialQuantity'] as num?)?.toDouble() ?? 0.0,
      currentQuantity: (map['currentQuantity'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] ?? 'kg',
      manufacturingDate: map['manufacturingDate'] != null 
          ? DateTime.parse(map['manufacturingDate']) 
          : DateTime.now(),
      expiryDate: map['expiryDate'] != null 
          ? DateTime.parse(map['expiryDate']) 
          : DateTime.now().add(const Duration(days: 365)),
      costPerKg: (map['costPerKg'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'ACTIVE',
    );
  }
}
