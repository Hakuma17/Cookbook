import 'package:flutter/foundation.dart';

/// ─── Helper Functions ───────────────────────────────────────────
/// ย้ายออกมาเป็น Top‑level function เพื่อความเป็นมาตรฐานเดียวกับ Model อื่นๆ
int _toInt(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? fallback;
}

String _str(dynamic v, {String fallback = ''}) {
  if (v == null) return fallback;
  final s = v.toString();
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

  const Ingredient({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.category,
    this.displayName,
  });

  /* ───────────────────────── factory ───────────────────────── */

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    // ⭐️ รองรับได้ทั้ง key "id" และ "ingredient_id"
    return Ingredient(
      id: _toInt(json['id'] ?? json['ingredient_id']), // ★
      name: _str(json['name'], fallback: 'ไม่ระบุชื่อ'),
      imageUrl: _str(json['image_url']),
      category: _str(json['category'], fallback: '-'),
      displayName: json['display_name']?.toString(),
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
      };

  /// ✅ 2. เพิ่มเมธอด copyWith
  Ingredient copyWith({
    int? id,
    String? name,
    String? imageUrl,
    String? category,
    String? displayName,
  }) {
    return Ingredient(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      displayName: displayName ?? this.displayName,
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
}
