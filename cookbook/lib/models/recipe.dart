// lib/models/recipe.dart
import 'package:flutter/foundation.dart';

/// ───────── helper ───────────────────────────────────────────
/// แปลง dynamic → int/double/String พร้อม fallback
int toIntSafe(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? fallback;
}

double toDoubleSafe(dynamic v, {double fallback = 0}) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

String toStringSafe(dynamic v, {String fallback = ''}) {
  if (v == null) return fallback;
  final s = v.toString();
  return s.isEmpty ? fallback : s;
}

/// ★★★ [NEW] แปลง dynamic → `List<String>` (รองรับทั้ง List และ CSV)
List<String> toStringListSafe(dynamic v) {
  if (v == null) return const [];
  if (v is List) {
    return v
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return v
      .toString()
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// ───────── model ────────────────────────────────────────────
/// Immutable data class for a recipe, พร้อม helper from/to JSON.
@immutable
class Recipe {
  /// รหัสสูตร
  final int id;

  /// ชื่อเมนู
  final String name;

  /// path ของรูปบน server (อาจ null)
  final String? imagePath;

  /// URL ของรูป ที่พร้อมใช้งานในแอป
  final String imageUrl;

  /// เวลาทำ (นาที), 0 = ไม่ระบุ
  final int prepTime;

  /// เรตติ้งเฉลี่ย 0–5
  final double averageRating;

  /// จำนวนรีวิว
  final int reviewCount;

  /// จำนวนคนกด “❤”
  final int favoriteCount;

  ///  ⭐️ เพิ่ม property นี้กลับเข้ามา
  /// ผู้ใช้คนปัจจุบันกดถูกใจสูตรนี้หรือไม่
  final bool isFavorited;

  /// สรุปวัตถุดิบสั้น ๆ (text)
  final String shortIngredients;

  /// ถ้ามีวัตถุดิบที่ผู้ใช้แพ้ (จาก API หรือคำนวณใน backend)
  final bool hasAllergy;

  /// อันดับ 1–3 ในผลค้นหา (null = ไม่แสดง badge)
  final int? rank;

  /// รายการ id วัตถุดิบทั้งหมดในสูตร
  final List<int> ingredientIds;

  /// ★★★ [NEW] กลุ่มวัตถุดิบที่ “ชน” กับรายการแพ้ของผู้ใช้ (เช่น “ถั่ว”, “อาหารทะเล”)
  final List<String> allergyGroups;

  /// ★★★ [NEW] รายชื่อที่ใช้แสดงเป็นชิป (ชื่อจากรายการแพ้ของผู้ใช้ที่อยู่ในกลุ่มเดียวกับในสูตร)
  final List<String> allergyNames;

  const Recipe({
    required this.id,
    required this.name,
    this.imagePath,
    required this.imageUrl,
    required this.prepTime,
    required this.averageRating,
    required this.reviewCount,
    required this.favoriteCount,
    required this.isFavorited, //  ⭐️ เพิ่มใน constructor
    required this.shortIngredients,
    required this.hasAllergy,
    this.rank,
    required this.ingredientIds,
    this.allergyGroups = const [], // ★★★ [NEW]
    this.allergyNames = const [], // ★★★ [NEW]
  });

  /// ───── สร้างจาก JSON (จาก API) ─────────────────────────
  factory Recipe.fromJson(Map<String, dynamic> j) {
    List<int> parseIds(dynamic src) {
      if (src == null) return <int>[];
      if (src is List) {
        return src
            .map((e) => toIntSafe(e, fallback: -1))
            .where((e) => e > 0)
            .toList();
      }
      if (src is String) {
        return src
            .split(',')
            .map((s) => toIntSafe(s.trim(), fallback: -1))
            .where((e) => e > 0)
            .toList();
      }
      return <int>[];
    }

    // [Compat] บาง endpoint อาจให้ id เป็น 'id' แทน 'recipe_id'
    final rid = j.containsKey('recipe_id') ? j['recipe_id'] : j['id'];

    final rawImagePath = j['image_path'];
    final imgPath = (rawImagePath != null && rawImagePath.toString().isNotEmpty)
        ? rawImagePath.toString()
        : null;

// ใหม่: ถ้าไม่เจอ image_url ให้ใช้ imagePath แทน (หรือค่าว่างถ้าไม่มี)
    final imageUrlCandidate = toStringSafe(
      j['image_url'] ?? j['image'] ?? j['thumbnail'],
    );
    final imageUrl = imageUrlCandidate.isNotEmpty
        ? imageUrlCandidate
        : (imgPath ??
            ''); // <- ใช้ imagePath เป็นตัวแทน URL ให้ SafeImage ไปจัดการต่
    return Recipe(
      id: toIntSafe(rid),
      name: toStringSafe(j['name'], fallback: 'ไม่มีชื่อสูตร'),
      imagePath: imgPath,
      imageUrl: imageUrl,
      prepTime: toIntSafe(j['prep_time']),
      averageRating: toDoubleSafe(j['average_rating']),
      reviewCount: toIntSafe(j['review_count']),
      favoriteCount: toIntSafe(j['favorite_count'], fallback: 0),
      //  ⭐️ อ่านค่า is_favorited จาก JSON (รองรับทั้ง boolean และ integer)
      isFavorited: j['is_favorited'] == true || j['is_favorited'] == 1,
      shortIngredients: toStringSafe(j['short_ingredients']),
      hasAllergy: j['has_allergy'] == true || j['has_allergy'] == 1,
      rank: j['rank'] == null ? null : toIntSafe(j['rank']),
      ingredientIds: parseIds(j['ingredient_ids']),
      allergyGroups: toStringListSafe(j['allergy_groups']), // ★★★ [NEW]
      allergyNames: toStringListSafe(j['allergy_names']), // ★★★ [NEW]
    );
  }

  /// ───── แปลงกลับเป็น JSON (optional) ────────────────────
  Map<String, dynamic> toJson() => {
        'recipe_id': id,
        'name': name,
        'image_path': imagePath,
        'image_url': imageUrl,
        'prep_time': prepTime,
        'average_rating': averageRating,
        'review_count': reviewCount,
        'favorite_count': favoriteCount,
        'is_favorited': isFavorited, //  ⭐️ เพิ่มใน toJson
        'short_ingredients': shortIngredients,
        'has_allergy': hasAllergy,
        'rank': rank,
        'ingredient_ids': ingredientIds,
        'allergy_groups': allergyGroups, // ★★★ [NEW]
        'allergy_names': allergyNames, // ★★★ [NEW]
      };

  Recipe copyWith({
    int? id,
    String? name,
    String? imagePath,
    String? imageUrl,
    int? prepTime,
    double? averageRating,
    int? reviewCount,
    int? favoriteCount,
    bool? isFavorited, //  ⭐️ เพิ่มใน copyWith
    String? shortIngredients,
    bool? hasAllergy,
    int? rank,
    List<int>? ingredientIds,
    List<String>? allergyGroups, // ★★★ [NEW]
    List<String>? allergyNames, // ★★★ [NEW]
  }) {
    return Recipe(
      id: id ?? this.id,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      imageUrl: imageUrl ?? this.imageUrl,
      prepTime: prepTime ?? this.prepTime,
      averageRating: averageRating ?? this.averageRating,
      reviewCount: reviewCount ?? this.reviewCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      isFavorited: isFavorited ?? this.isFavorited, //  ⭐️ เพิ่มใน copyWith
      shortIngredients: shortIngredients ?? this.shortIngredients,
      hasAllergy: hasAllergy ?? this.hasAllergy,
      rank: rank ?? this.rank,
      ingredientIds: ingredientIds ?? this.ingredientIds,
      allergyGroups: allergyGroups ?? this.allergyGroups, // ★★★ [NEW]
      allergyNames: allergyNames ?? this.allergyNames, // ★★★ [NEW]
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Recipe && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
