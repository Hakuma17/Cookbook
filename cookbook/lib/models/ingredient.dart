// lib/models/ingredient.dart
import 'package:flutter/foundation.dart';

/// ─── Helper Functions ───────────────────────────────────────────
/// ย้ายออกมาเป็น Top-level function เพื่อความเป็นมาตรฐานเดียวกับ Model อื่นๆ
int _toInt(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is double) return v.toInt();
  final s = v.toString().trim();
  if (s.isEmpty) return fallback;
  // รองรับ "12.0" ด้วย
  final d = double.tryParse(s);
  if (d != null) return d.toInt();
  return int.tryParse(s) ?? fallback;
}

String _str(dynamic v, {String fallback = ''}) {
  if (v == null) return fallback;
  final s = v.toString().trim();
  return s.isEmpty ? fallback : s;
}

/// ─── Ingredient Model ──────────────────────────────────────────
/// ✅ 1. เพิ่ม @immutable annotation
@immutable
class Ingredient {
  final int id; // ingredient_id หรือ id
  final String name; // ชื่อ (ภาษาไทย / ค่า default)
  final String imageUrl; // URL เต็มของรูปภาพ
  final String category; // หมวดหมู่ เช่น “ผัก”, “เนื้อสัตว์”
  final String? displayName; // ชื่อทางการตลาด / ชื่อตามฉลาก (อาจเป็น null)

  /// ★ NEW: จำนวน “สูตรอาหาร” ที่มีวัตถุดิบนี้ (เตรียมไว้ทำ Badge)
  /// - backend อาจส่งมาเป็น recipe_count / total_recipes / recipes / count
  /// - ถ้าไม่ส่งมาให้ถือเป็น 0 ไปก่อน (UI ยังไม่ต้องโชว์ก็ได้)
  final int recipeCount;

  const Ingredient({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.category,
    this.displayName,
    this.recipeCount = 0, // ★ NEW: ค่าเริ่มต้น = 0
  });

  /* ───────────────────────── factory ───────────────────────── */

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    // ชื่อ: ถ้า name ว่าง ให้ fallback เป็น display_name
    final rawDisplay = json['display_name']?.toString();
    final rawName = _str(json['name']);
    final name = rawName.isNotEmpty
        ? rawName
        : _str(rawDisplay, fallback: 'ไม่ระบุชื่อ');

    // รูป: รองรับ image / image_path เพิ่ม
    final imageUrl = _str(
      json['image_url'] ?? json['image'] ?? json['image_path'],
    );

    return Ingredient(
      id: _toInt(
          json['id'] ?? json['ingredient_id']), // รองรับทั้ง id/ingredient_id
      name: name,
      imageUrl: imageUrl,
      category: _str(json['category'], fallback: '-'),
      displayName: rawDisplay,
      // ★ NEW: รองรับหลายชื่อคีย์ที่สื่อจำนวน "สูตร"
      recipeCount: _toInt(
        json['recipe_count'] ??
            json['total_recipes'] ??
            json['recipes'] ??
            json['count'],
        fallback: 0,
      ),
    );
  }

  /* ───────────────────────── toJson ───────────────────────── */

  Map<String, dynamic> toJson() => {
        'id': id, // ★ เปลี่ยนเป็น id ให้สอดคล้อง spec ใหม่
        'ingredient_id': id, //   (ยังคงส่งซ้ำสำหรับ backend เก่า)
        'name': name,
        'image_url': imageUrl,
        'category': category,
        'display_name': displayName,
        'recipe_count': recipeCount, // ★ NEW: เผื่อ backend ใหม่
      };

  /// ✅ 2. เพิ่มเมธอด copyWith
  Ingredient copyWith({
    int? id,
    String? name,
    String? imageUrl,
    String? category,
    String? displayName,
    int? recipeCount, // ★ NEW
  }) {
    return Ingredient(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      displayName: displayName ?? this.displayName,
      recipeCount: recipeCount ?? this.recipeCount, // ★ NEW
    );
  }

  /// ✅ 3. override `==` และ `hashCode` ให้เทียบกันที่ id
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Ingredient && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  /// ★ NEW (optional helper): ให้ UI เดิมเรียกใช้แบบเดียวกับ group ได้
  /// ใช้ชื่อเดียวกับ compatibility getter ของ IngredientGroup
  int get totalRecipes => recipeCount; // เผื่อจะเรียก `ing.totalRecipes`
}

/// ★ Optional helpers เพิ่มความสะดวกตอนใช้ใน UI
extension IngredientX on Ingredient {
  bool get hasImage => imageUrl.trim().isNotEmpty;
  bool get hasRecipeCount => recipeCount > 0;
  String get primaryDisplay => (displayName?.trim().isNotEmpty ?? false)
      ? displayName!.trim()
      : name.trim();
}
