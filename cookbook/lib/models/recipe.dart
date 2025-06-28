import 'package:flutter/foundation.dart';

// ───────── helper ───────────────────────────────────────────
int _toInt(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? fallback;
}

double _toDouble(dynamic v, {double fallback = 0}) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

String _toString(dynamic v, {String fallback = ''}) {
  if (v == null) return fallback;
  final s = v.toString();
  return s.isEmpty ? fallback : s;
}

// ───────── model ────────────────────────────────────────────
@immutable
class Recipe {
  final int id;
  final String name;

  /// path ในเซิร์ฟเวอร์ (อาจ null)
  final String? imagePath;

  /// URL พร้อมใช้ (รวม default)
  final String imageUrl;

  /// เวลาทำ (นาที)  – 0 = ไม่ระบุ
  final int prepTime;

  /// เรตติ้งเฉลี่ย 0-5
  final double averageRating;

  /// จำนวนรีวิว
  final int reviewCount;

  /// จำนวนคนกด “❤”
  final int favoriteCount; // ← ★ new

  /// สรุปวัตถุดิบสั้น ๆ
  final String shortIngredients;

  /// มีวัตถุดิบที่ผู้ใช้แพ้
  final bool hasAllergy;

  /// อันดับ 1-3 (null = ไม่มี)
  final int? rank;

  /// id วัตถุดิบทั้งหมด
  final List<int> ingredientIds;

  const Recipe({
    required this.id,
    required this.name,
    this.imagePath,
    required this.imageUrl,
    required this.prepTime,
    required this.averageRating,
    required this.reviewCount,
    required this.favoriteCount,
    required this.shortIngredients,
    required this.hasAllergy,
    this.rank,
    required this.ingredientIds,
  });

  // ───── fromJson ──────────────────────────────────────────
  factory Recipe.fromJson(Map<String, dynamic> j) {
    List<int> _parseIds(dynamic src) {
      if (src == null) return <int>[];
      if (src is List) {
        return src
            .map((e) => _toInt(e, fallback: -1))
            .where((e) => e > 0)
            .toList();
      }
      if (src is String) {
        return src
            .split(',')
            .map((s) => _toInt(s.trim(), fallback: -1))
            .where((e) => e > 0)
            .toList();
      }
      return <int>[];
    }

    final rawImagePath = j['image_path'];
    final imgPath = (rawImagePath != null && rawImagePath.toString().isNotEmpty)
        ? rawImagePath.toString()
        : null;

    return Recipe(
      id: _toInt(j['recipe_id']),
      name: _toString(j['name'], fallback: 'ไม่มีชื่อสูตร'),
      imagePath: imgPath,
      imageUrl: _toString(j['image_url']),
      prepTime: _toInt(j['prep_time']),
      averageRating: _toDouble(j['average_rating']),
      reviewCount: _toInt(j['review_count']),
      favoriteCount: _toInt(j['favorite_count'], fallback: 0),
      shortIngredients: _toString(j['short_ingredients']),
      hasAllergy: j['has_allergy'] == true || j['has_allergy'] == 1,
      rank: j['rank'] == null ? null : _toInt(j['rank']),
      ingredientIds: _parseIds(j['ingredient_ids']),
    );
  }

  // ───── toJson (optional, cache / debug) ──────────────────
  Map<String, dynamic> toJson() => {
        'recipe_id': id,
        'name': name,
        'image_path': imagePath,
        'image_url': imageUrl,
        'prep_time': prepTime,
        'average_rating': averageRating,
        'review_count': reviewCount,
        'favorite_count': favoriteCount, // ★
        'short_ingredients': shortIngredients,
        'has_allergy': hasAllergy,
        'rank': rank,
        'ingredient_ids': ingredientIds,
      };
}
