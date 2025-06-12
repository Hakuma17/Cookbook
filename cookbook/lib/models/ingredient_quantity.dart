// lib/models/ingredient_quantity.dart

class IngredientQuantity {
  final int ingredientId;
  final String name;
  final String imageUrl;
  final double quantity;
  final String unit;
  final double gramsActual;
  final String description;

  IngredientQuantity({
    required this.ingredientId,
    required this.name,
    required this.imageUrl,
    required this.quantity,
    required this.unit,
    required this.gramsActual,
    required this.description,
  });

  factory IngredientQuantity.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v == null) return 0;
      return int.tryParse(v.toString()) ?? 0;
    }

    double parseDouble(dynamic v) {
      if (v == null) return 0.0;
      return double.tryParse(v.toString()) ?? 0.0;
    }

    String parseString(dynamic v) {
      if (v == null) return '';
      return v.toString();
    }

    return IngredientQuantity(
      ingredientId: parseInt(json['ingredient_id']),
      name: parseString(json['name']),
      imageUrl: parseString(json['image_url']),
      quantity: parseDouble(json['quantity']),
      unit: parseString(json['unit']),
      gramsActual: parseDouble(json['grams_actual']),
      description: parseString(json['descrip']),
    );
  }
}
