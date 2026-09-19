class ManufacturingBatch {
  ManufacturingBatch();

  String? id;
  DateTime? timestamp;
  String? status;
  bool addedToInventory = false;
  
  String? targetProductId;
  String? targetProductName;

  String? createdById;
  String? createdByName;

  String? rawMaterialName;
  double? rawMaterialQuantity;
  double? rawMaterialAmount;
  double? gstPercentage;

  double get totalGstAmount => (rawMaterialAmount ?? 0) * ((gstPercentage ?? 0) / 100);
  double get totalCost => (rawMaterialAmount ?? 0) + totalGstAmount;

  double? weightBeforeDrying;
  double? weightAfterDrying;

  double get dryingLoss => (weightBeforeDrying ?? 0) - (weightAfterDrying ?? 0);

  double? weightBeforeGrinding;
  double? weightAfterGrinding;

  double get grindingLoss => (weightBeforeGrinding ?? 0) - (weightAfterGrinding ?? 0);

  double get finalOutputWeight => weightAfterGrinding ?? 0;

  double get totalLoss => dryingLoss + grindingLoss;

  double get yieldPercentage => (rawMaterialQuantity != null && rawMaterialQuantity! > 0)
      ? (finalOutputWeight / rawMaterialQuantity!) * 100
      : 0;

  Map<String, dynamic> toMap() {
    return {
      'targetProductId': targetProductId,
      'targetProductName': targetProductName,
      'rawMaterialName': rawMaterialName,
      'rawMaterialQuantity': rawMaterialQuantity,
      'rawMaterialAmount': rawMaterialAmount,
      'gstPercentage': gstPercentage,
      'totalGstAmount': totalGstAmount,
      'totalCost': totalCost,
      'weightBeforeDrying': weightBeforeDrying,
      'weightAfterDrying': weightAfterDrying,
      'dryingLoss': dryingLoss,
      'weightBeforeGrinding': weightBeforeGrinding,
      'weightAfterGrinding': weightAfterGrinding,
      'grindingLoss': grindingLoss,
      'finalOutputWeight': finalOutputWeight,
      'totalLoss': totalLoss,
      'yieldPercentage': yieldPercentage,
      'createdById': createdById,
      'createdByName': createdByName,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'PENDING APPROVAL',
    };
  }

  factory ManufacturingBatch.fromMap(Map<String, dynamic> map) {
    final batch = ManufacturingBatch();
    batch.id = map['_id'] ?? map['id'];
    batch.targetProductId = map['targetProductId'];
    batch.targetProductName = map['targetProductName'];
    batch.rawMaterialName = map['rawMaterialName'];
    batch.rawMaterialQuantity = (map['rawMaterialQuantity'] as num?)?.toDouble();
    batch.rawMaterialAmount = (map['rawMaterialAmount'] as num?)?.toDouble();
    batch.gstPercentage = (map['gstPercentage'] as num?)?.toDouble();
    batch.weightBeforeDrying = (map['weightBeforeDrying'] as num?)?.toDouble();
    batch.weightAfterDrying = (map['weightAfterDrying'] as num?)?.toDouble();
    batch.weightBeforeGrinding = (map['weightBeforeGrinding'] as num?)?.toDouble();
    batch.weightAfterGrinding = (map['weightAfterGrinding'] as num?)?.toDouble();
    batch.createdById = map['createdById'];
    batch.createdByName = map['createdByName'];
    
    if (map['timestamp'] != null) {
      batch.timestamp = DateTime.tryParse(map['timestamp'].toString());
    }
    batch.status = map['status'];
    batch.addedToInventory = map['addedToInventory'] ?? false;
    
    return batch;
  }
}

