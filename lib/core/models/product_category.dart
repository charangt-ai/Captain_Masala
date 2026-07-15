class ProductCategory {
  final String id;
  final String name;
  final String image;

  ProductCategory({
    required this.id,
    required this.name,
    this.image = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'image': image,
    };
  }

  factory ProductCategory.fromMap(Map<String, dynamic> map) {
    return ProductCategory(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      image: map['image'] ?? '',
    );
  }
}
