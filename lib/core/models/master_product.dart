class MasterProduct {
  final String id;
  final String name;
  double totalStockKg;

  MasterProduct({
    required this.id,
    required this.name,
    this.totalStockKg = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'totalStockKg': totalStockKg,
    };
  }

  factory MasterProduct.fromMap(Map<String, dynamic> map) {
    return MasterProduct(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      totalStockKg: (map['totalStockKg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
