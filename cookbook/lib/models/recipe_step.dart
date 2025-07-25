import 'package:flutter/foundation.dart';

/// ───────────────────────────────────────────
///  helpers ย่อย
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

  factory RecipeStep.fromJson(Map<String, dynamic> json) => RecipeStep(
        stepNumber: _toInt(json['step_number']),
        description: _toString(json['description']),
      );

  Map<String, dynamic> toJson() => {
        'step_number': stepNumber,
        'description': description,
      };

  // ✅ เพิ่มเมธอดมาตรฐานสำหรับ Immutable class
  RecipeStep copyWith({
    int? stepNumber,
    String? description,
  }) {
    return RecipeStep(
      stepNumber: stepNumber ?? this.stepNumber,
      description: description ?? this.description,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecipeStep &&
        other.stepNumber == stepNumber &&
        other.description == description;
  }

  @override
  int get hashCode => stepNumber.hashCode ^ description.hashCode;
}
