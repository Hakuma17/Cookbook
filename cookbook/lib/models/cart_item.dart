import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'cart_ingredient.dart';
import 'json_parser.dart';

/// **ข้อมูล “เมนู​ 1 รายการ” ที่อยู่ในตะกร้า**
@immutable
class CartItem extends Equatable {
  /* ───────────────────────── fields ───────────────────────── */

  final int recipeId;
  final String name;
  final int? prepTime;
  final double averageRating;
  final int reviewCount;
  final double nServings;
  final String imageUrl;
  final List<CartIngredient> ingredients;

  const CartItem({
    required this.recipeId,
    required this.name,
    this.prepTime, // ✅ ทำให้ prepTime เป็น optional ที่นี่ด้วย
    required this.averageRating,
    required this.reviewCount,
    required this.nServings,
    required this.imageUrl,
    this.ingredients = const [],
  });

  /* ───────────────────────── factories ───────────────────────── */

  /// ✅ 1. สร้าง private factory กลางขึ้นมาเพื่อลดโค้ดซ้ำซ้อน
  factory CartItem._fromMap(Map<String, dynamic> json,
      {List<CartIngredient>? ingredients}) {
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
      ingredients: ingredients ?? const [],
    );
  }

  /// จาก JSON ของ **`get_cart_items.php`**
  factory CartItem.fromJson(Map<String, dynamic> json) {
    final rawIng = json['ingredients'] as List<dynamic>? ?? const [];
    final ingredients = rawIng.map((e) => CartIngredient.fromJson(e)).toList();
    return CartItem._fromMap(json, ingredients: ingredients);
  }

  /// จาก JSON ที่มาจาก **รายการ Favorites**
  factory CartItem.fromFavoritesJson(Map<String, dynamic> json) {
    // รายการโปรดไม่มี ingredients, จึงไม่ต้องส่งไป
    return CartItem._fromMap(json);
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
      };

  CartItem copyWith({
    int? recipeId,
    String? name,
    // ✅ 2. เพิ่มความสามารถในการตั้งค่า prepTime ให้เป็น null ได้
    ValueGetter<int?>? prepTime,
    double? averageRating,
    int? reviewCount,
    double? nServings,
    String? imageUrl,
    List<CartIngredient>? ingredients,
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
      ];
}
