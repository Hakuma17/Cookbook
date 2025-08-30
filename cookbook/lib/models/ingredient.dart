// lib/models/ingredient.dart
import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';

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
///   - @immutable
///   - เทียบความเท่ากันด้วย id (ผ่าน Equatable)
@immutable
class Ingredient extends Equatable {
  final int id; // ingredient_id หรือ id
  final String name; // ชื่อ (ภาษาไทย / ค่า default)
  final String imageUrl; // URL เต็มของรูปภาพ
  final String category; // หมวดหมู่ เช่น “ผัก”, “เนื้อสัตว์”
  final String? displayName; // ชื่อการตลาด / ตามฉลาก (อาจเป็น null)

  /// ★ จำนวน “สูตรอาหาร” ที่มีวัตถุดิบนี้ (เตรียมไว้ทำ Badge)
  /// - backend อาจส่งมาเป็น recipe_count / total_recipes / recipes / count
  /// - ถ้าไม่ส่งมาให้ถือเป็น 0 ไปก่อน
  final int recipeCount;

  const Ingredient({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.category,
    this.displayName,
    this.recipeCount = 0,
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
      id: _toInt(json['id'] ?? json['ingredient_id']),
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
        'id': id, // ใช้ id เป็นหลัก
        'ingredient_id': id, // ส่งซ้ำเพื่อรองรับ backend เก่า
        'name': name,
        'image_url': imageUrl,
        'category': category,
        'display_name': displayName,
        'recipe_count': recipeCount,
      };

  /// copyWith สำหรับอัปเดตแบบ Immutable
  Ingredient copyWith({
    int? id,
    String? name,
    String? imageUrl,
    String? category,
    String? displayName,
    int? recipeCount,
  }) {
    return Ingredient(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      displayName: displayName ?? this.displayName,
      recipeCount: recipeCount ?? this.recipeCount,
    );
  }

  /// ให้ UI เดิมเรียกใช้แบบเดียวกับ group ได้
  int get totalRecipes => recipeCount;

  /* ───────────────────────── equatable ───────────────────────── */
  /// เทียบความเท่ากันด้วย `id` เท่านั้น (ตรงกับของเดิมที่ override ==/hashCode)
  @override
  List<Object?> get props => [id];

  @override
  String toString() =>
      'Ingredient(id=$id, name=$name, cat=$category, recipes=$recipeCount)';
}

/// ★ Optional helpers เพิ่มความสะดวกตอนใช้ใน UI
extension IngredientX on Ingredient {
  bool get hasImage => imageUrl.trim().isNotEmpty;
  bool get hasRecipeCount => recipeCount > 0;
  String get primaryDisplay => (displayName?.trim().isNotEmpty ?? false)
      ? displayName!.trim()
      : name.trim();
}
