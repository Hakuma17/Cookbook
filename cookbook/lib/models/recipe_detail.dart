import 'ingredient_quantity.dart';
import 'recipe_step.dart';
import 'nutrition.dart';
import 'comment.dart';

class RecipeDetail {
  final int recipeId;
  final String name;

  /// URL ของรูป (1 – n ภาพ สำหรับ carousel)
  final List<String> imageUrls;

  /// เวลาเตรียม (นาที) – อาจเป็น null
  final int? prepTime;

  final double averageRating;
  final int reviewCount;
  final DateTime createdAt;
  final String sourceReference;

  final List<IngredientQuantity> ingredients;
  final List<RecipeStep> steps;
  final Nutrition nutrition;
  final List<Comment> comments;
  final List<String> categories;

  final bool isFavorited;
  final double? userRating;

  /// จำนวนเสิร์ฟปัจจุบันที่ผู้ใช้กำหนดในตะกร้า
  final int currentServings;

  /// จำนวนเสิร์ฟต้นฉบับของสูตร
  final int nServings;

  const RecipeDetail({
    required this.recipeId,
    required this.name,
    required this.imageUrls,
    this.prepTime,
    required this.averageRating,
    required this.reviewCount,
    required this.createdAt,
    required this.sourceReference,
    required this.ingredients,
    required this.steps,
    required this.nutrition,
    required this.comments,
    required this.categories,
    required this.isFavorited,
    this.userRating,
    required this.currentServings,
    required this.nServings,
  });

  /* ───────────────────────── factory ───────────────────────── */

  factory RecipeDetail.fromJson(Map<String, dynamic> json) {
    int _int(dynamic v) =>
        v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);

    double _double(dynamic v) => v == null
        ? 0.0
        : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);

    DateTime _date(dynamic v) => v == null
        ? DateTime.now()
        : (DateTime.tryParse(v.toString()) ?? DateTime.now());

    List<String> _strList(dynamic v) =>
        (v is List) ? v.map((e) => e.toString()).toList() : <String>[];

    return RecipeDetail(
      recipeId: _int(json['recipe_id']),
      name: json['name']?.toString() ?? '',
      imageUrls: _strList(json['image_urls']),
      prepTime: json['prep_time'] == null ? null : _int(json['prep_time']),
      averageRating: _double(json['average_rating']),
      reviewCount: _int(json['review_count']),
      createdAt: _date(json['created_at']),
      sourceReference: json['source_reference']?.toString() ?? '',
      ingredients: (json['ingredients'] as List<dynamic>)
          .map((e) => IngredientQuantity.fromJson(e as Map<String, dynamic>))
          .toList(),
      steps: (json['steps'] as List<dynamic>)
          .map((e) => RecipeStep.fromJson(e as Map<String, dynamic>))
          .toList(),
      nutrition: Nutrition.fromJson(json['nutrition'] as Map<String, dynamic>),
      comments: (json['comments'] as List<dynamic>)
          .map((e) => Comment.fromJson(e as Map<String, dynamic>))
          .toList(),
      categories: _strList(json['categories']),
      isFavorited: json['is_favorited'] == true ||
          json['is_favorited']?.toString().toLowerCase() == 'true' ||
          json['is_favorited'] == 1,
      userRating:
          json['user_rating'] == null ? null : _double(json['user_rating']),
      currentServings: _int(json['current_servings']),
      nServings: _int(json['nServings']),
    );
  }

  /* ───────────────────────── toJson ───────────────────────── */

  Map<String, dynamic> toJson() => {
        'recipe_id': recipeId,
        'name': name,
        'image_urls': imageUrls,
        'prep_time': prepTime,
        'average_rating': averageRating,
        'review_count': reviewCount,
        'created_at': createdAt.toIso8601String(),
        'source_reference': sourceReference,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'steps': steps.map((e) => e.toJson()).toList(),
        'nutrition': nutrition.toJson(),
        'comments': comments.map((e) => e.toJson()).toList(),
        'categories': categories,
        'is_favorited': isFavorited,
        'user_rating': userRating,
        'current_servings': currentServings,
        'nServings': nServings,
      };
}
