// lib/models/recipe_detail.dart

import 'ingredient_quantity.dart';
import 'recipe_step.dart';
import 'nutrition.dart';
import 'comment.dart';

class RecipeDetail {
  final int recipeId;
  final String name;
  final List<String> imageUrls; // carousel หลายรูป
  final int? prepTime; // prep_time (นาที)
  final double averageRating; // average_rating
  final int reviewCount; // review_count
  final DateTime createdAt; // created_at
  final String sourceReference; // source_reference
  final List<IngredientQuantity> ingredients;
  final List<RecipeStep> steps;
  final Nutrition nutrition;
  final List<Comment> comments;
  final List<String> categories;
  final bool isFavorited; // is_favorited
  final double? userRating; // user_rating ของผู้ใช้ปัจจุบัน
  final int currentServings; // current_servings

  RecipeDetail({
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
  });

  factory RecipeDetail.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 0;
    }

    double parseDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    // image_urls → List<String>
    final images = (json['image_urls'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];

    return RecipeDetail(
      recipeId: parseInt(json['recipe_id']),
      name: json['name']?.toString() ?? '',
      imageUrls: images,
      prepTime: json['prep_time'] != null ? parseInt(json['prep_time']) : null,
      averageRating: parseDouble(json['average_rating']),
      reviewCount: parseInt(json['review_count']),
      createdAt: parseDate(json['created_at']),
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
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[],
      isFavorited: json['is_favorited'] == true ||
          json['is_favorited']?.toString().toLowerCase() == 'true' ||
          json['is_favorited'] == 1,
      userRating:
          json['user_rating'] != null ? parseDouble(json['user_rating']) : null,
      currentServings: parseInt(json['current_servings']),
    );
  }
}
