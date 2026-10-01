import 'dart:convert';

class PurchaseEntry {
  final String id;
  final String rawMaterialId;
  final String supplierId;
  final String batchNumber;
  final double quantity;
  final String unit;
  final double purchasePrice;
  final double? gst;
  final DateTime purchaseDate;
  final DateTime? expiryDate;
  final String storageLocation;

  PurchaseEntry({
    required this.id,
    required this.rawMaterialId,
    required this.supplierId,
    required this.batchNumber,
    required this.quantity,
    required this.unit,
    required this.purchasePrice,
    this.gst,
    required this.purchaseDate,
    this.expiryDate,
    required this.storageLocation,
  });

  PurchaseEntry copyWith({
    String? id,
    String? rawMaterialId,
    String? supplierId,
    String? batchNumber,
    double? quantity,
    String? unit,
    double? purchasePrice,
    double? gst,
    DateTime? purchaseDate,
    DateTime? expiryDate,
    String? storageLocation,
  }) {
    return PurchaseEntry(
      id: id ?? this.id,
      rawMaterialId: rawMaterialId ?? this.rawMaterialId,
      supplierId: supplierId ?? this.supplierId,
      batchNumber: batchNumber ?? this.batchNumber,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      gst: gst ?? this.gst,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expiryDate: expiryDate ?? this.expiryDate,
      storageLocation: storageLocation ?? this.storageLocation,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rawMaterialId': rawMaterialId,
      'supplierId': supplierId,
      'batchNumber': batchNumber,
      'quantity': quantity,
      'unit': unit,
      'purchasePrice': purchasePrice,
      'gst': gst,
      'purchaseDate': purchaseDate.millisecondsSinceEpoch,
      'expiryDate': expiryDate?.millisecondsSinceEpoch,
      'storageLocation': storageLocation,
    };
  }

  factory PurchaseEntry.fromMap(Map<String, dynamic> map) {
    return PurchaseEntry(
      id: map['id'] ?? '',
      rawMaterialId: map['rawMaterialId'] ?? '',
      supplierId: map['supplierId'] ?? '',
      batchNumber: map['batchNumber'] ?? '',
      quantity: map['quantity']?.toDouble() ?? 0.0,
      unit: map['unit'] ?? '',
      purchasePrice: map['purchasePrice']?.toDouble() ?? 0.0,
      gst: map['gst']?.toDouble(),
      purchaseDate: DateTime.fromMillisecondsSinceEpoch(map['purchaseDate']),
      expiryDate: map['expiryDate'] != null ? DateTime.fromMillisecondsSinceEpoch(map['expiryDate']) : null,
      storageLocation: map['storageLocation'] ?? '',
    );
  }
  
  String toJson() => json.encode(toMap());
  factory PurchaseEntry.fromJson(String source) => PurchaseEntry.fromMap(json.decode(source));
}
