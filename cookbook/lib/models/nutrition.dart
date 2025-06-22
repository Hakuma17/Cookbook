/// ข้อมูลโภชนาการต่อ “สูตรทั้งหมด” (ยังไม่หารเสิร์ฟ)
class Nutrition {
  final double calories;
  final double fat;
  final double protein;
  final double carbs;

  const Nutrition({
    required this.calories,
    required this.fat,
    required this.protein,
    required this.carbs,
  });

  /* ───────────────────────── factory ───────────────────────── */

  factory Nutrition.fromJson(Map<String, dynamic> json) {
    double _double(dynamic v) => v == null
        ? 0.0
        : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);

    return Nutrition(
      calories: _double(json['calories']),
      fat: _double(json['fat']),
      protein: _double(json['protein']),
      carbs: _double(json['carbs']),
    );
  }

  /* ───────────────────────── toJson ───────────────────────── */

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'fat': fat,
        'protein': protein,
        'carbs': carbs,
      };
}
