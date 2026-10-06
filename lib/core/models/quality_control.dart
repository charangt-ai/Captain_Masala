class QcParameter {
  final String name;
  final String expectedValue;
  final String? actualValue;
  final String? unit;
  final bool isPassed;

  QcParameter({
    required this.name,
    required this.expectedValue,
    this.actualValue,
    this.unit,
    this.isPassed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'expectedValue': expectedValue,
      'actualValue': actualValue,
      'unit': unit,
      'isPassed': isPassed,
    };
  }

  factory QcParameter.fromMap(Map<String, dynamic> map) {
    return QcParameter(
      name: map['name'] ?? '',
      expectedValue: map['expectedValue'] ?? '',
      actualValue: map['actualValue'],
      unit: map['unit'],
      isPassed: map['isPassed'] ?? false,
    );
  }
}

class QualityControl {
  final String? id;
  final String qcNumber;
  final String productionPlanId;
  final String manufacturingBatchId;
  final String? masterProductId;
  final String? masterProductName;
  final List<QcParameter> parameters;
  final String overallResult;
  final double? batchWeight;
  final double? sampleSize;
  final String? inspectedById;
  final String? inspectedByName;
  final DateTime? inspectedAt;
  final String? remarks;
  final String? rejectionReason;

  QualityControl({
    this.id,
    required this.qcNumber,
    required this.productionPlanId,
    required this.manufacturingBatchId,
    this.masterProductId,
    this.masterProductName,
    required this.parameters,
    this.overallResult = 'PENDING',
    this.batchWeight,
    this.sampleSize,
    this.inspectedById,
    this.inspectedByName,
    this.inspectedAt,
    this.remarks,
    this.rejectionReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'qcNumber': qcNumber,
      'productionPlanId': productionPlanId,
      'manufacturingBatchId': manufacturingBatchId,
      'masterProductId': masterProductId,
      'masterProductName': masterProductName,
      'parameters': parameters.map((x) => x.toMap()).toList(),
      'overallResult': overallResult,
      'batchWeight': batchWeight,
      'sampleSize': sampleSize,
      'inspectedById': inspectedById,
      'inspectedByName': inspectedByName,
      'inspectedAt': inspectedAt?.toIso8601String(),
      'remarks': remarks,
      'rejectionReason': rejectionReason,
    };
  }

  factory QualityControl.fromMap(Map<String, dynamic> map) {
    return QualityControl(
      id: map['_id'] ?? map['id'],
      qcNumber: map['qcNumber'] ?? '',
      productionPlanId: map['productionPlanId'] ?? '',
      manufacturingBatchId: map['manufacturingBatchId'] ?? '',
      masterProductId: map['masterProductId'],
      masterProductName: map['masterProductName'],
      parameters: List<QcParameter>.from(
        (map['parameters'] as List<dynamic>? ?? []).map((x) => QcParameter.fromMap(x)),
      ),
      overallResult: map['overallResult'] ?? 'PENDING',
      batchWeight: (map['batchWeight'] as num?)?.toDouble(),
      sampleSize: (map['sampleSize'] as num?)?.toDouble(),
      inspectedById: map['inspectedById'],
      inspectedByName: map['inspectedByName'],
      inspectedAt: map['inspectedAt'] != null ? DateTime.tryParse(map['inspectedAt'].toString()) : null,
      remarks: map['remarks'],
      rejectionReason: map['rejectionReason'],
    );
  }
}
