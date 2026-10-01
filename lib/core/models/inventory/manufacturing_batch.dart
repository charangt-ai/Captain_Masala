import 'dart:convert';

enum ManufacturingType { singleIngredient, multiIngredient }

class ProcessStep {
  final String stepName; // e.g., 'Drying', 'Grinding', 'Mixing'
  final double inputQuantity;
  final double outputQuantity;
  
  double get lossQuantity => inputQuantity - outputQuantity;
  double get yieldPercentage => (outputQuantity / inputQuantity) * 100;

  ProcessStep({
    required this.stepName,
    required this.inputQuantity,
    required this.outputQuantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'stepName': stepName,
      'inputQuantity': inputQuantity,
      'outputQuantity': outputQuantity,
    };
  }

  factory ProcessStep.fromMap(Map<String, dynamic> map) {
    return ProcessStep(
      stepName: map['stepName'] ?? '',
      inputQuantity: map['inputQuantity']?.toDouble() ?? 0.0,
      outputQuantity: map['outputQuantity']?.toDouble() ?? 0.0,
    );
  }
}

class ManufacturingBatch {
  final String id;
  final String materialIssueId;
  final ManufacturingType type;
  final String targetProductId; // Final product (e.g., Turmeric Powder)
  final double totalInputQuantity;
  final List<ProcessStep> processSteps;
  final double finalOutputQuantity;
  final DateTime batchDate;
  
  double get overallYieldPercentage => (finalOutputQuantity / totalInputQuantity) * 100;

  ManufacturingBatch({
    required this.id,
    required this.materialIssueId,
    required this.type,
    required this.targetProductId,
    required this.totalInputQuantity,
    required this.processSteps,
    required this.finalOutputQuantity,
    required this.batchDate,
  });

  ManufacturingBatch copyWith({
    String? id,
    String? materialIssueId,
    ManufacturingType? type,
    String? targetProductId,
    double? totalInputQuantity,
    List<ProcessStep>? processSteps,
    double? finalOutputQuantity,
    DateTime? batchDate,
  }) {
    return ManufacturingBatch(
      id: id ?? this.id,
      materialIssueId: materialIssueId ?? this.materialIssueId,
      type: type ?? this.type,
      targetProductId: targetProductId ?? this.targetProductId,
      totalInputQuantity: totalInputQuantity ?? this.totalInputQuantity,
      processSteps: processSteps ?? this.processSteps,
      finalOutputQuantity: finalOutputQuantity ?? this.finalOutputQuantity,
      batchDate: batchDate ?? this.batchDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'materialIssueId': materialIssueId,
      'type': type.name,
      'targetProductId': targetProductId,
      'totalInputQuantity': totalInputQuantity,
      'processSteps': processSteps.map((x) => x.toMap()).toList(),
      'finalOutputQuantity': finalOutputQuantity,
      'batchDate': batchDate.millisecondsSinceEpoch,
    };
  }

  factory ManufacturingBatch.fromMap(Map<String, dynamic> map) {
    return ManufacturingBatch(
      id: map['id'] ?? '',
      materialIssueId: map['materialIssueId'] ?? '',
      type: ManufacturingType.values.firstWhere((e) => e.name == map['type'], orElse: () => ManufacturingType.singleIngredient),
      targetProductId: map['targetProductId'] ?? '',
      totalInputQuantity: map['totalInputQuantity']?.toDouble() ?? 0.0,
      processSteps: List<ProcessStep>.from(
        (map['processSteps'] as List<dynamic>? ?? []).map((x) => ProcessStep.fromMap(x)),
      ),
      finalOutputQuantity: map['finalOutputQuantity']?.toDouble() ?? 0.0,
      batchDate: DateTime.fromMillisecondsSinceEpoch(map['batchDate']),
    );
  }
  
  String toJson() => json.encode(toMap());
  factory ManufacturingBatch.fromJson(String source) => ManufacturingBatch.fromMap(json.decode(source));
}
