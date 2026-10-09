class RawMaterialItem {
  String name;
  double quantity;
  double? amount;
  double? gstPercentage;

  RawMaterialItem({
    required this.name,
    required this.quantity,
    this.amount,
    this.gstPercentage,
  });

  double get totalGstAmount => (amount ?? 0) * ((gstPercentage ?? 0) / 100);
  double get totalCost => (amount ?? 0) + totalGstAmount;

  Map<String, dynamic> toMap() => {
    'name': name,
    'quantity': quantity,
    'amount': amount,
    'gstPercentage': gstPercentage,
  };

  factory RawMaterialItem.fromMap(Map<String, dynamic> map) => RawMaterialItem(
    name: map['name'] ?? '',
    quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
    amount: (map['amount'] as num?)?.toDouble(),
    gstPercentage: (map['gstPercentage'] as num?)?.toDouble(),
  );
}

class ManufacturingBatch {
  ManufacturingBatch();

  String? id;
  DateTime? timestamp;
  String? status;
  bool addedToInventory = false;
  
  String? targetProductId;
  String? targetProductName;
  String? planNumber;
  String? productionPlanId;

  String? createdById;
  String? createdByName;

  String? rawMaterialName;
  double? rawMaterialQuantity;
  double? rawMaterialAmount;
  double? gstPercentage;

  List<RawMaterialItem> rawMaterials = [];

  double dryingCost = 0.0;
  double grindingCost = 0.0;
  List<Map<String, dynamic>> otherCosts = [];

  double get totalGstAmount {
    if (rawMaterials.isNotEmpty) {
      return rawMaterials.fold(0.0, (sum, item) => sum + item.totalGstAmount);
    }
    return (rawMaterialAmount ?? 0) * ((gstPercentage ?? 0) / 100);
  }
  
  double get totalCost {
    double baseCost = 0.0;
    if (rawMaterials.isNotEmpty) {
      baseCost = rawMaterials.fold(0.0, (sum, item) => sum + item.totalCost);
    } else {
      baseCost = (rawMaterialAmount ?? 0) + totalGstAmount;
    }
    
    double otherCostsTotal = otherCosts.fold(0.0, (sum, item) => sum + (item['amount'] as num? ?? 0.0).toDouble());
    
    return baseCost + dryingCost + grindingCost + otherCostsTotal;
  }

  double get totalRawMaterialQuantity {
    if (rawMaterials.isNotEmpty) {
      return rawMaterials.fold(0.0, (sum, item) => sum + item.quantity);
    }
    return rawMaterialQuantity ?? 0;
  }


  double? weightBeforeDrying;
  double? weightAfterDrying;

  double get dryingLoss => (weightBeforeDrying ?? 0) - (weightAfterDrying ?? 0);

  double? weightBeforeGrinding;
  double? weightAfterGrinding;

  double get grindingLoss => (weightBeforeGrinding ?? 0) - (weightAfterGrinding ?? 0);

  double get finalOutputWeight => weightAfterGrinding ?? 0;

  double get totalLoss => dryingLoss + grindingLoss;

  double get yieldPercentage => (totalRawMaterialQuantity > 0)
      ? (finalOutputWeight / totalRawMaterialQuantity) * 100
      : 0;

  Map<String, dynamic> toMap() {
    return {
      'targetProductId': targetProductId,
      'targetProductName': targetProductName,
      'planNumber': planNumber,
      'productionPlanId': productionPlanId,
      'rawMaterialName': rawMaterialName,
      'rawMaterialQuantity': rawMaterialQuantity,
      'rawMaterialAmount': rawMaterialAmount,
      'gstPercentage': gstPercentage,
      'rawMaterials': rawMaterials.map((e) => e.toMap()).toList(),
      'totalGstAmount': totalGstAmount,
      'totalCost': totalCost,
      'weightBeforeDrying': weightBeforeDrying,
      'weightAfterDrying': weightAfterDrying,
      'dryingLoss': dryingLoss,
      'weightBeforeGrinding': weightBeforeGrinding,
      'weightAfterGrinding': weightAfterGrinding,
      'grindingLoss': grindingLoss,
      'dryingCost': dryingCost,
      'grindingCost': grindingCost,
      'otherCosts': otherCosts,
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
    batch.planNumber = map['planNumber'];
    batch.productionPlanId = map['productionPlanId'];
    batch.rawMaterialName = map['rawMaterialName'];
    batch.rawMaterialQuantity = (map['rawMaterialQuantity'] as num?)?.toDouble();
    batch.rawMaterialAmount = (map['rawMaterialAmount'] as num?)?.toDouble();
    batch.gstPercentage = (map['gstPercentage'] as num?)?.toDouble();
    
    if (map['rawMaterials'] != null) {
      batch.rawMaterials = (map['rawMaterials'] as List).map((e) => RawMaterialItem.fromMap(e)).toList();
    }
    batch.weightBeforeDrying = (map['weightBeforeDrying'] as num?)?.toDouble();
    batch.weightAfterDrying = (map['weightAfterDrying'] as num?)?.toDouble();
    batch.weightBeforeGrinding = (map['weightBeforeGrinding'] as num?)?.toDouble();
    batch.weightAfterGrinding = (map['weightAfterGrinding'] as num?)?.toDouble();
    
    batch.dryingCost = (map['dryingCost'] as num?)?.toDouble() ?? 0.0;
    batch.grindingCost = (map['grindingCost'] as num?)?.toDouble() ?? 0.0;
    
    if (map['otherCosts'] != null) {
      batch.otherCosts = List<Map<String, dynamic>>.from(map['otherCosts']);
    }

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

