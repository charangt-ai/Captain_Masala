import 'dart:convert';

class RawMaterialInventory {
  final String id;
  final String rawMaterialId;
  final String batchNumber;
  final double openingStock;
  final double purchasedQuantity;
  final double issuedQuantity;
  final double availableStock;
  final String storageLocation;
  final DateTime? expiryDate;

  RawMaterialInventory({
    required this.id,
    required this.rawMaterialId,
    required this.batchNumber,
    required this.openingStock,
    required this.purchasedQuantity,
    required this.issuedQuantity,
    required this.availableStock,
    required this.storageLocation,
    this.expiryDate,
  });

  RawMaterialInventory copyWith({
    String? id,
    String? rawMaterialId,
    String? batchNumber,
    double? openingStock,
    double? purchasedQuantity,
    double? issuedQuantity,
    double? availableStock,
    String? storageLocation,
    DateTime? expiryDate,
  }) {
    return RawMaterialInventory(
      id: id ?? this.id,
      rawMaterialId: rawMaterialId ?? this.rawMaterialId,
      batchNumber: batchNumber ?? this.batchNumber,
      openingStock: openingStock ?? this.openingStock,
      purchasedQuantity: purchasedQuantity ?? this.purchasedQuantity,
      issuedQuantity: issuedQuantity ?? this.issuedQuantity,
      availableStock: availableStock ?? this.availableStock,
      storageLocation: storageLocation ?? this.storageLocation,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rawMaterialId': rawMaterialId,
      'batchNumber': batchNumber,
      'openingStock': openingStock,
      'purchasedQuantity': purchasedQuantity,
      'issuedQuantity': issuedQuantity,
      'availableStock': availableStock,
      'storageLocation': storageLocation,
      'expiryDate': expiryDate?.millisecondsSinceEpoch,
    };
  }

  factory RawMaterialInventory.fromMap(Map<String, dynamic> map) {
    return RawMaterialInventory(
      id: map['id'] ?? '',
      rawMaterialId: map['rawMaterialId'] ?? '',
      batchNumber: map['batchNumber'] ?? '',
      openingStock: map['openingStock']?.toDouble() ?? 0.0,
      purchasedQuantity: map['purchasedQuantity']?.toDouble() ?? 0.0,
      issuedQuantity: map['issuedQuantity']?.toDouble() ?? 0.0,
      availableStock: map['availableStock']?.toDouble() ?? 0.0,
      storageLocation: map['storageLocation'] ?? '',
      expiryDate: map['expiryDate'] != null ? DateTime.fromMillisecondsSinceEpoch(map['expiryDate']) : null,
    );
  }
  
  String toJson() => json.encode(toMap());
  factory RawMaterialInventory.fromJson(String source) => RawMaterialInventory.fromMap(json.decode(source));
}
