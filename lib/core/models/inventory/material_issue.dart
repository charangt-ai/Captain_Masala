import 'dart:convert';

class IngredientIssueItem {
  final String rawMaterialId;
  final String batchNumber;
  final double issueQuantity;

  IngredientIssueItem({
    required this.rawMaterialId,
    required this.batchNumber,
    required this.issueQuantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'rawMaterialId': rawMaterialId,
      'batchNumber': batchNumber,
      'issueQuantity': issueQuantity,
    };
  }

  factory IngredientIssueItem.fromMap(Map<String, dynamic> map) {
    return IngredientIssueItem(
      rawMaterialId: map['rawMaterialId'] ?? '',
      batchNumber: map['batchNumber'] ?? '',
      issueQuantity: map['issueQuantity']?.toDouble() ?? 0.0,
    );
  }
}

class MaterialIssue {
  final String id;
  final String productId; // Target product or recipe
  final List<IngredientIssueItem> ingredientsIssued;
  final DateTime dateIssued;
  final String issuedByUserId;

  MaterialIssue({
    required this.id,
    required this.productId,
    required this.ingredientsIssued,
    required this.dateIssued,
    required this.issuedByUserId,
  });

  MaterialIssue copyWith({
    String? id,
    String? productId,
    List<IngredientIssueItem>? ingredientsIssued,
    DateTime? dateIssued,
    String? issuedByUserId,
  }) {
    return MaterialIssue(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      ingredientsIssued: ingredientsIssued ?? this.ingredientsIssued,
      dateIssued: dateIssued ?? this.dateIssued,
      issuedByUserId: issuedByUserId ?? this.issuedByUserId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'ingredientsIssued': ingredientsIssued.map((x) => x.toMap()).toList(),
      'dateIssued': dateIssued.millisecondsSinceEpoch,
      'issuedByUserId': issuedByUserId,
    };
  }

  factory MaterialIssue.fromMap(Map<String, dynamic> map) {
    return MaterialIssue(
      id: map['id'] ?? '',
      productId: map['productId'] ?? '',
      ingredientsIssued: List<IngredientIssueItem>.from(
        (map['ingredientsIssued'] as List<dynamic>? ?? []).map((x) => IngredientIssueItem.fromMap(x)),
      ),
      dateIssued: DateTime.fromMillisecondsSinceEpoch(map['dateIssued']),
      issuedByUserId: map['issuedByUserId'] ?? '',
    );
  }
  
  String toJson() => json.encode(toMap());
  factory MaterialIssue.fromJson(String source) => MaterialIssue.fromMap(json.decode(source));
}
