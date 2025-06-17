// lib/models/cart_item.dart
import 'package:cookbook/models/json_parser.dart';
import 'package:equatable/equatable.dart';
import 'cart_ingredient.dart';

/// Model ของเมนูในตะกร้า
class CartItem extends Equatable {
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
    required this.prepTime,
    required this.averageRating,
    required this.reviewCount,
    required this.nServings,
    required this.imageUrl,
    this.ingredients = const [],
  });

  /// สร้างจาก JSON map (รวม ingredients)
  factory CartItem.fromJson(Map<String, dynamic> json) {
    final ingJson = json['ingredients'] as List?;
    final ings = ingJson != null
        ? ingJson.map((e) => CartIngredient.fromJson(e)).toList()
        : <CartIngredient>[];

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
    );
  }

  /// สร้างจาก JSON map ฝั่ง Favorites (ไม่มี ingredients)
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

  /// แปลงเป็น JSON map
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

  /// สร้างสำเนาด้วยค่าที่แก้ไขบางส่วน
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
