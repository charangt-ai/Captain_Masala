import 'dart:convert';

class RawMaterial {
  final String id;
  final String name;
  final String category; // e.g., 'Core Spice', 'Common Ingredient'
  final String unit; // 'kg', 'g'
  final double? gst;
  final double minimumStockLevel;
  final double currentStock;
  final bool isActive;
  final String? imageUrl;

  RawMaterial({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    this.gst,
    required this.minimumStockLevel,
    this.currentStock = 0.0,
    this.isActive = true,
    this.imageUrl,
  });

  RawMaterial copyWith({
    String? id,
    String? name,
    String? category,
    String? unit,
    double? gst,
    double? minimumStockLevel,
    double? currentStock,
    bool? isActive,
    String? imageUrl,
  }) {
    return RawMaterial(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      gst: gst ?? this.gst,
      minimumStockLevel: minimumStockLevel ?? this.minimumStockLevel,
      currentStock: currentStock ?? this.currentStock,
      isActive: isActive ?? this.isActive,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'unit': unit,
      'gst': gst,
      'minimumStockLevel': minimumStockLevel,
      'currentStock': currentStock,
      'isActive': isActive,
      'imageUrl': imageUrl,
    };
  }

  factory RawMaterial.fromMap(Map<String, dynamic> map) {
    return RawMaterial(
      id: map['id'] ?? map['_id'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      unit: map['unit'] ?? '',
      gst: map['gst']?.toDouble(),
      minimumStockLevel: map['minimumStockLevel']?.toDouble() ?? 0.0,
      currentStock: map['currentStock']?.toDouble() ?? 0.0,
      isActive: map['isActive'] ?? true,
      imageUrl: map['imageUrl'],
    );
  }
  
  String toJson() => json.encode(toMap());
  factory RawMaterial.fromJson(String source) => RawMaterial.fromMap(json.decode(source));
}
