import 'master_product.dart';

class RecipeIngredient {
  final String rawMaterialId;
  final String rawMaterialName;
  final double requiredQuantity;

  RecipeIngredient({
    required this.rawMaterialId,
    required this.rawMaterialName,
    required this.requiredQuantity,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      rawMaterialId: json['rawMaterialId']['_id'] ?? json['rawMaterialId'],
      rawMaterialName: json['rawMaterialId']['name'] ?? 'Unknown',
      requiredQuantity: (json['requiredQuantity'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rawMaterialId': rawMaterialId,
      'requiredQuantity': requiredQuantity,
    };
  }
}

class Recipe {
  final String id;
  final String productId;
  final double baseBatchSize;
  final String type;
  final List<RecipeIngredient> ingredients;

  Recipe({
    required this.id,
    required this.productId,
    required this.baseBatchSize,
    required this.type,
    required this.ingredients,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['_id'],
      productId: json['productId'],
      baseBatchSize: (json['baseBatchSize'] as num).toDouble(),
      type: json['type'] ?? 'MULTI_INGREDIENT',
      ingredients: (json['ingredients'] as List)
          .map((i) => RecipeIngredient.fromJson(i))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'baseBatchSize': baseBatchSize,
      'type': type,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
    };
  }
}
