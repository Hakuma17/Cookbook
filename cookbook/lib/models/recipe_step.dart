import 'package:flutter/foundation.dart';

/// ───────────────────────────────────────────
///  helpers ย่อย (เหมือนใน recipe.dart)
/// ───────────────────────────────────────────
int _toInt(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? fallback;
}

String _toString(dynamic v, {String fallback = ''}) {
  if (v == null) return fallback;
  final s = v.toString();
  return s.isEmpty ? fallback : s;
}

/// ───────────────────────────────────────────
///  RecipeStep model
/// ───────────────────────────────────────────
@immutable
class RecipeStep {
  final int stepNumber; // ลำดับ (1-based)
  final String description;

  const RecipeStep({
    required this.stepNumber,
    required this.description,
  });

  /// factory fromJson
  factory RecipeStep.fromJson(Map<String, dynamic> json) => RecipeStep(
        stepNumber: _toInt(json['step_number']),
        description: _toString(json['description']),
      );

  /// toJson (optional)
  Map<String, dynamic> toJson() => {
        'step_number': stepNumber,
        'description': description,
      };
}
