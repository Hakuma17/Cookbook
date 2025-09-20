import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'cart_ingredient.dart';
import 'json_parser.dart';

/// ข้อมูล “เมนู 1 รายการ” ที่อยู่ในตะกร้า
///
/// ใช้กับผลลัพธ์จาก `get_cart_items.php`
/// - หลังบ้านจะรวมวัตถุดิบของเมนูนี้ (ถ้ามีฟิลด์ `ingredients`)
/// - ถ้าไม่มีฟิลด์ `has_allergy` ระดับเมนู เราจะคำนวณจากรายการวัตถุดิบอีกชั้น
@immutable
class CartItem extends Equatable {
  /* ───────────────────────── fields ───────────────────────── */

  /// รหัสเมนู (recipe_id)
  final int recipeId;

  /// ชื่อเมนู
  final String name;

  /// เวลาเตรียม (นาที) อาจไม่มี
  final int? prepTime;

  /// เรตติ้งเฉลี่ยปัจจุบันของเมนู
  final double averageRating;

  /// จำนวนรีวิวทั้งหมดของเมนู
  final int reviewCount;

  /// จำนวนเสิร์ฟที่ผู้ใช้ตั้งไว้ในตะกร้า
  final double nServings;

  /// URL รูปเมนู (เป็น URL ที่พร้อมแสดงได้)
  final String imageUrl;

  /// รายการวัตถุดิบของเมนูนี้ (ถ้ามี)
  final List<CartIngredient> ingredients;

  /// [NEW] ธงว่าเมนูนี้มีวัตถุดิบที่ผู้ใช้แพ้หรือไม่
  ///
  /// แหล่งข้อมูล:
  /// - ถ้าหลังบ้านส่ง `has_allergy` ของเมนูมา เราจะใช้ค่านั้น
  /// - ถ้าไม่ส่งมา เราจะ OR จาก `ingredients[i].hasAllergy`
  final bool hasAllergy;

  const CartItem({
    required this.recipeId,
    required this.name,
    this.prepTime,
    required this.averageRating,
    required this.reviewCount,
    required this.nServings,
    required this.imageUrl,
    this.ingredients = const [],
    this.hasAllergy = false, // [NEW] ค่าเริ่มต้น
  });

  /* ───────────────────────── factories ───────────────────────── */

  /// สร้างจาก Map พื้นฐานหนึ่งจุด เพื่อหลีกเลี่ยงโค้ดซ้ำ
  ///
  /// หมายเหตุ: ในกรณีที่ไม่ได้ส่ง `ingredients` เข้ามา ให้เว้นไว้เป็น `[]`
  /// และให้ผู้เรียกเป็นผู้คำนวณ `hasAllergy` ต่อ (หรือส่ง `hasAllergyOverride`)
  factory CartItem._fromMap(
    Map<String, dynamic> json, {
    List<CartIngredient>? ingredients,
    bool? hasAllergyOverride, // [NEW] เผื่ออยากบังคับค่าจากภายนอก
  }) {
    final ings = ingredients ?? const <CartIngredient>[];

    // 1) ถ้ามีค่านี้มาจาก backend ใช้เลย
    final hasAllergyFromJson = JsonParser.parseBool(json['has_allergy']);

    // 2) ถ้า backend ไม่ส่ง key has_allergy แต่มี ingredients ให้คำนวณจากวัตถุดิบ
    final hasAllergyFromIngs = json.containsKey('has_allergy')
        ? hasAllergyFromJson
        : ings.any((e) => e.hasAllergy);

    // 3) อนุญาต override
    final hasAllergy = hasAllergyOverride ?? hasAllergyFromIngs;

    return CartItem(
      recipeId: JsonParser.parseInt(json['recipe_id']),
      name: JsonParser.parseString(json['name']),
      prepTime: json['prep_time'] != null
          ? JsonParser.parseInt(json['prep_time'])
          : null,
      averageRating: JsonParser.parseDouble(json['average_rating']),
      reviewCount: JsonParser.parseInt(json['review_count']),
      nServings: JsonParser.parseDouble(json['nServings']),
      imageUrl: JsonParser.parseString(json['image_url']),
      ingredients: ings,
      hasAllergy: hasAllergy,
    );
  }

  /// จาก JSON ของ `get_cart_items.php`
  ///
  /// รูปแบบที่รองรับ:
  /// - มีฟิลด์ `ingredients` เป็นลิสต์ของวัตถุดิบ
  /// - อาจมีหรือไม่มีฟิลด์ `has_allergy` ระดับเมนู
  factory CartItem.fromJson(Map<String, dynamic> json) {
    final rawIng = json['ingredients'] as List<dynamic>? ?? const [];
    final ingredients = rawIng.map((e) => CartIngredient.fromJson(e)).toList();

    // คำนวณธงแพ้: ถ้ามีใน json ใช้เลย, ถ้าไม่มีก็ OR จากรายการวัตถุดิบ
    final hasAllergyOverride = json.containsKey('has_allergy')
        ? JsonParser.parseBool(json['has_allergy'])
        : ingredients.any((e) => e.hasAllergy);

    return CartItem._fromMap(
      json,
      ingredients: ingredients,
      hasAllergyOverride: hasAllergyOverride,
    );
  }

  /// จาก JSON ที่มาจาก “รายการโปรด”
  ///
  /// กรณีนี้โดยปกติจะไม่มีวัตถุดิบแนบมา จึงไม่สามารถคำนวณธงแพ้จากวัตถุดิบได้
  /// ถ้าหลังบ้านส่ง `has_allergy` มาด้วยจะใช้ค่าโดยตรง
  factory CartItem.fromFavoritesJson(Map<String, dynamic> json) {
    return CartItem._fromMap(
      json,
      hasAllergyOverride: JsonParser.parseBool(json['has_allergy']),
    );
  }

  /* ───────────────────────── toJson / copyWith ───────────────────────── */

  Map<String, dynamic> toJson() => {
        'recipe_id': recipeId,
        'name': name,
        'prep_time': prepTime,
        'average_rating': averageRating,
        'review_count': reviewCount,
        'nServings': nServings,
        'image_url': imageUrl,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'has_allergy': hasAllergy, // [NEW]
      };

  CartItem copyWith({
    int? recipeId,
    String? name,

    /// ต้องการตั้งค่า `prepTime` ให้เป็น null ได้ จึงใช้ `ValueGetter<int?>`
    ValueGetter<int?>? prepTime,
    double? averageRating,
    int? reviewCount,
    double? nServings,
    String? imageUrl,
    List<CartIngredient>? ingredients,
    bool? hasAllergy, // [NEW]
  }) {
    return CartItem(
      recipeId: recipeId ?? this.recipeId,
      name: name ?? this.name,
      prepTime: prepTime != null ? prepTime() : this.prepTime,
      averageRating: averageRating ?? this.averageRating,
      reviewCount: reviewCount ?? this.reviewCount,
      nServings: nServings ?? this.nServings,
      imageUrl: imageUrl ?? this.imageUrl,
      ingredients: ingredients ?? this.ingredients,
      hasAllergy: hasAllergy ?? this.hasAllergy,
    );
  }

  /* ───────────────────────── equatable ───────────────────────── */

  @override
  List<Object?> get props => [
        recipeId,
        name,
        prepTime,
        averageRating,
        reviewCount,
        nServings,
        imageUrl,
        ingredients,
        hasAllergy, // [NEW]
      ];
}
