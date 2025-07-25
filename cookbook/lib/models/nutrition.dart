import 'package:flutter/foundation.dart';

// ✅ 1. ย้าย Helper function ออกมาเป็น Top-level
double _toDouble(dynamic v) =>
    v is num ? v.toDouble() : (double.tryParse(v.toString()) ?? 0.0);

/// ข้อมูลโภชนาการ
@immutable
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

  factory Nutrition.fromJson(Map<String, dynamic> json) {
    return Nutrition(
      calories: _toDouble(json['calories']),
      fat: _toDouble(json['fat']),
      protein: _toDouble(json['protein']),
      carbs: _toDouble(json['carbs']),
    );
  }

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'fat': fat,
        'protein': protein,
        'carbs': carbs,
      };

  // ✅ 2. เพิ่มเมธอดมาตรฐานสำหรับ Immutable class
  Nutrition copyWith({
    double? calories,
    double? fat,
    double? protein,
    double? carbs,
  }) {
    return Nutrition(
      calories: calories ?? this.calories,
      fat: fat ?? this.fat,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Nutrition &&
        other.calories == calories &&
        other.fat == fat &&
        other.protein == protein &&
        other.carbs == carbs;
  }

  @override
  int get hashCode {
    return calories.hashCode ^ fat.hashCode ^ protein.hashCode ^ carbs.hashCode;
  }
}
