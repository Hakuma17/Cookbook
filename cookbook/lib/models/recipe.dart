import 'package:flutter/foundation.dart';

/// ──────────────────────────────────────────────────
///  helpers ย่อย  (ทำเป็น extension ก็ได้)
/// ──────────────────────────────────────────────────
int _toInt(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? fallback;
}

double _toDouble(dynamic v, {double fallback = 0.0}) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

String _toString(dynamic v, {String fallback = ''}) {
  if (v == null) return fallback;
  final s = v.toString();
  return s.isEmpty ? fallback : s;
}

/// ──────────────────────────────────────────────────
///  Recipe model
/// ──────────────────────────────────────────────────
@immutable
class Recipe {
  final int id;
  final String name;
  final String? imagePath;
  final String imageUrl;
  final int prepTime; // นาที (0 = ไม่ระบุ)
  final double averageRating; // 0-5
  final int reviewCount;
  final String shortIngredients; // string ย่อ
  final bool hasAllergy;
  final int? rank; // ตำแหน่ง ranking (ถ้ามี)
  final List<int> ingredientIds; // id วัตถุดิบทั้งหมดในสูตร

  const Recipe({
    required this.id,
    required this.name,
    this.imagePath,
    required this.imageUrl,
    required this.prepTime,
    required this.averageRating,
    required this.reviewCount,
    required this.shortIngredients,
    required this.hasAllergy,
    this.rank,
    required this.ingredientIds,
  });

  /// ───── fromJson ───────────────────────────────
  factory Recipe.fromJson(Map<String, dynamic> json) {
    // 1) รูปภาพ (image_path อาจว่าง/null)
    final rawImagePath = json['image_path'];
    final imgPath = (rawImagePath != null && rawImagePath.toString().isNotEmpty)
        ? rawImagePath.toString()
        : null;

    // 2) ingredient_ids อาจเป็น List<int> / List<dynamic> / String
    List<int> parseIds(dynamic src) {
      if (src == null) return <int>[];
      if (src is List) {
        return src
            .map((e) => _toInt(e, fallback: -1))
            .where((id) => id > 0)
            .toList();
      }
      if (src is String) {
        return src
            .split(',')
            .map((s) => _toInt(s.trim(), fallback: -1))
            .where((id) => id > 0)
            .toList();
      }
      return <int>[];
    }

    return Recipe(
      id: _toInt(json['recipe_id']),
      name: _toString(json['name'], fallback: 'ไม่มีชื่อสูตร'),
      imagePath: imgPath,
      imageUrl: _toString(json['image_url']),
      prepTime: _toInt(json['prep_time']),
      averageRating: _toDouble(json['average_rating']),
      reviewCount: _toInt(json['review_count']),
      shortIngredients: _toString(json['short_ingredients']),
      hasAllergy: (json['has_allergy'] == true) ||
          (json['has_allergy'] == 1) ||
          ('${json['has_allergy']}' == '1'),
      rank: json['rank'] == null ? null : _toInt(json['rank']),
      ingredientIds: parseIds(json['ingredient_ids']),
    );
  }

  /// ───── toJson (optional สำหรับ cache / debug) ───────────────────────────
  Map<String, dynamic> toJson() => {
        'recipe_id': id,
        'name': name,
        'image_path': imagePath,
        'image_url': imageUrl,
        'prep_time': prepTime,
        'average_rating': averageRating,
        'review_count': reviewCount,
        'short_ingredients': shortIngredients,
        'has_allergy': hasAllergy,
        'rank': rank,
        'ingredient_ids': ingredientIds,
      };
}
