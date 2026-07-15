class Product {
  final String id;
  final String name;
  final String packSize; // e.g. "500 g"
  double wholesalePrice;
  double originalPrice;
  double remainingStock; // in kg/units
  final String imageUrl;
  bool isEnabled;
  final String categoryId;
  String masterProductId;

  Product({
    required this.id,
    required this.name,
    required this.packSize,
    required this.wholesalePrice,
    this.originalPrice = 0.0,
    required this.remainingStock,
    this.imageUrl = '',
    this.isEnabled = true,
    this.categoryId = '',
    this.masterProductId = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'packSize': packSize,
      'wholesalePrice': wholesalePrice,
      'originalPrice': originalPrice,
      'remainingStock': remainingStock,
      'imageUrl': imageUrl,
      'isEnabled': isEnabled ? 1 : 0,
      'categoryId': categoryId,
      'masterProductId': masterProductId,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      packSize: map['packSize'],
      wholesalePrice: (map['wholesalePrice'] as num).toDouble(),
      originalPrice: (map['originalPrice'] ?? map['wholesalePrice']).toDouble(),
      remainingStock: (map['remainingStock'] as num).toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      isEnabled: map['isEnabled'] == 1 || map['isEnabled'] == true,
      categoryId: map['categoryId'] ?? '',
      masterProductId: map['masterProductId'] ?? '',
    );
  }
}
