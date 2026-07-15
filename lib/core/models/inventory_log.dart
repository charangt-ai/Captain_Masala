class InventoryLog {
  final String id;
  final String productId;
  final String productName;
  final double changeQuantity; // Positive for additions, negative for sales
  final String type; // 'Monthly Entry', 'Sale Deduction', 'Adjustment'
  final DateTime dateTime;
  final String notes;

  InventoryLog({
    required this.id,
    required this.productId,
    required this.productName,
    required this.changeQuantity,
    required this.type,
    required this.dateTime,
    this.notes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'changeQuantity': changeQuantity,
      'type': type,
      'dateTime': dateTime.toIso8601String(),
      'notes': notes,
    };
  }

  factory InventoryLog.fromMap(Map<String, dynamic> map) {
    return InventoryLog(
      id: map['id'],
      productId: map['productId'],
      productName: map['productName'],
      changeQuantity: (map['changeQuantity'] as num).toDouble(),
      type: map['type'],
      dateTime: DateTime.parse(map['dateTime']),
      notes: map['notes'] ?? '',
    );
  }
}
