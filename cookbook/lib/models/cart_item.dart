import 'package:equatable/equatable.dart';

import 'cart_ingredient.dart';
import 'json_parser.dart';

/// **ข้อมูล “เมนู​ 1 รายการ” ที่อยู่ในตะกร้า**
///
/// * ใช้ร่วมกับ `/get_cart_items.php`
/// * สามารถนำไปแสดงผล / ปรับจำนวนเสิร์ฟแล้วส่งกลับไปอัปเดตตะกร้า
class CartItem extends Equatable {
  /* ───────────────────────── fields ───────────────────────── */

  final int recipeId; // ID สูตรอาหาร
  final String name; // ชื่อเมนู
  final int? prepTime; // เวลาทำ (นาที) - อาจไม่มี
  final double averageRating; // คะแนนเฉลี่ย
  final int reviewCount; // จำนวนรีวิว
  final double nServings; // เสิร์ฟที่ผู้ใช้เลือกใส่ตะกร้า
  final String imageUrl; // URL รูปเมนู (เต็ม)
  final List<CartIngredient> ingredients; // วัตถุดิบ (หลัง scale)

  const CartItem({
    required this.recipeId,
    required this.name,
    required this.prepTime,
    required this.averageRating,
    required this.reviewCount,
    required this.nServings,
    required this.imageUrl,
    this.ingredients = const [],
  });

  /* ───────────────────────── factories ───────────────────────── */

  /// จาก JSON ของ **`get_cart_items.php`**
  /// มีฟิลด์ `ingredients` ติดมาด้วย
  factory CartItem.fromJson(Map<String, dynamic> json) {
    final rawIng = json['ingredients'] as List<dynamic>? ?? const [];

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
      ingredients: rawIng.map((e) => CartIngredient.fromJson(e)).toList(),
    );
  }

  /// จาก JSON ที่มาจาก **รายการ Favorites** (ไม่มี ingredients)
  factory CartItem.fromFavoritesJson(Map<String, dynamic> json) {
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
      };

  CartItem copyWith({
    int? recipeId,
    String? name,
    int? prepTime,
    double? averageRating,
    int? reviewCount,
    double? nServings,
    String? imageUrl,
    List<CartIngredient>? ingredients,
  }) {
    return CartItem(
      recipeId: recipeId ?? this.recipeId,
      name: name ?? this.name,
      prepTime: prepTime ?? this.prepTime,
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
