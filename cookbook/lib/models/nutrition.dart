// lib/models/nutrition.dart

class Nutrition {
  final double calories;
  final double fat;
  final double protein;
  final double carbs;

  Nutrition({
    required this.calories,
    required this.fat,
    required this.protein,
    required this.carbs,
  });

  factory Nutrition.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic v) {
      if (v == null) return 0.0;
      return double.tryParse(v.toString()) ?? 0.0;
    }

    return Nutrition(
      calories: parseDouble(json['calories']),
      fat: parseDouble(json['fat']),
      protein: parseDouble(json['protein']),
      carbs: parseDouble(json['carbs']),
    );
  }
}
