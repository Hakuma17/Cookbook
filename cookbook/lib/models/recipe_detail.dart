import 'package:flutter/foundation.dart';

import 'recipe.dart';
import 'ingredient_quantity.dart';
import 'recipe_step.dart';
import 'nutrition.dart';

/// ─────────────────────────────────────────────────────────────
///  RecipeDetail  (extends Recipe)
///  – ปลอด null 100 %
///  – ถ้าไม่มีรูป => ใช้ assets/images/default_recipe.png
/// ─────────────────────────────────────────────────────────────
@immutable
class RecipeDetail extends Recipe {
  /* __________ fields ที่เฉพาะ RecipeDetail __________ */
  final List<String> imageUrls; // ≥ 1 เสมอ
  final List<String> categories; // อนุญาตว่าง []
  final List<IngredientQuantity> ingredients;
  final Nutrition? nutrition;
  final List<RecipeStep> steps;
  final DateTime createdAt;
  final int nServings;
  final int currentServings;

  /* __________ constructor (รับค่าที่ “ปลอด null” แล้ว) __________ */
  RecipeDetail({
    // ── fields จาก Recipe ──
    required super.id,
    required super.name,
    super.imagePath,
    required super.imageUrl,
    required super.prepTime,
    required super.averageRating,
    required super.reviewCount,
    required super.favoriteCount,
    required super.isFavorited,
    required super.shortIngredients,
    required super.hasAllergy,
    super.rank,
    required super.ingredientIds,

    // ── fields ของ RecipeDetail ──
    required this.imageUrls,
    required this.categories,
    required this.ingredients,
    this.nutrition,
    required this.steps,
    required this.createdAt,
    required this.nServings,
    required this.currentServings,
  });

  /* ───────────────────────── factory fromJson ───────────────────────── */
  factory RecipeDetail.fromJson(Map<String, dynamic> j) {
    /* helper */
    T _or<T>(T? v, T fallback) => v ?? fallback;

    String _parseStr(dynamic v) => (v ?? '').toString();

    int _parseInt(dynamic v, [int fb = 0]) =>
        v == null ? fb : int.tryParse(v.toString()) ?? fb;

    double _parseDouble(dynamic v) =>
        v == null ? 0 : double.tryParse(v.toString()) ?? 0;

    List<String> _parseImages(dynamic single, dynamic list) {
      final out = <String>[];
      if (list is List && list.isNotEmpty) {
        out.addAll(list.map((e) => _parseStr(e)));
      } else if (single != null && _parseStr(single).isNotEmpty) {
        out.add(_parseStr(single));
      }
      if (out.isEmpty) out.add('assets/images/default_recipe.png');
      return out;
    }

    List<int> _parseIds(dynamic src) {
      if (src == null) return <int>[];
      if (src is List) {
        return src
            .map((e) => _parseInt(e, -1))
            .where((e) => e > 0)
            .toList(growable: false);
      }
      if (src is String) {
        return src
            .split(',')
            .map((s) => _parseInt(s.trim(), -1))
            .where((e) => e > 0)
            .toList(growable: false);
      }
      return <int>[];
    }

    /* ---------- mapping ---------- */
    final imgUrls = _parseImages(j['image_url'], j['image_urls']);

    return RecipeDetail(
      /* base Recipe */
      id: _parseInt(j['recipe_id']),
      name: _parseStr(j['name']),
      imagePath: _parseStr(j['image_path']).isEmpty
          ? null
          : _parseStr(j['image_path']),
      imageUrl: imgUrls.first,
      prepTime: _parseInt(j['prep_time']),
      averageRating: _parseDouble(j['average_rating']),
      reviewCount: _parseInt(j['review_count']),
      favoriteCount: _parseInt(j['favorite_count']),
      isFavorited: j['is_favorited'] == true || j['is_favorited'] == 1,
      shortIngredients: _parseStr(j['short_ingredients']),
      hasAllergy: j['has_allergy'] == true || j['has_allergy'] == 1,
      rank: j['rank'] != null ? _parseInt(j['rank']) : null,
      ingredientIds: _parseIds(j['ingredient_ids']),

      /* detail */
      imageUrls: imgUrls,
      categories: (j['categories'] as List?)?.map(_parseStr).toList() ?? [],
      ingredients: (j['ingredients'] as List?)
              ?.map((e) => IngredientQuantity.fromJson(e))
              .toList() ??
          [],
      nutrition:
          j['nutrition'] != null ? Nutrition.fromJson(j['nutrition']) : null,
      steps:
          (j['steps'] as List?)?.map((e) => RecipeStep.fromJson(e)).toList() ??
              [],
      createdAt:
          DateTime.tryParse(_parseStr(j['created_at'])) ?? DateTime.now(),
      nServings: _parseInt(j['nServings'], 1),
      currentServings: _parseInt(j['current_servings'], 1),
    );
  }

  /* ───────────────────────── toJson ───────────────────────── */
  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'image_urls': imageUrls,
        'categories': categories,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'nutrition': nutrition?.toJson(),
        'steps': steps.map((e) => e.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'nServings': nServings,
        'current_servings': currentServings,
      };

  /* ───────────────────────── copyWith ───────────────────────── */
  @override
  RecipeDetail copyWith({
    int? id,
    String? name,
    String? imagePath,
    String? imageUrl,
    int? prepTime,
    double? averageRating,
    int? reviewCount,
    int? favoriteCount,
    bool? isFavorited,
    String? shortIngredients,
    bool? hasAllergy,
    int? rank,
    List<int>? ingredientIds,
    List<String>? imageUrls,
    List<String>? categories,
    List<IngredientQuantity>? ingredients,
    ValueGetter<Nutrition?>? nutrition,
    List<RecipeStep>? steps,
    DateTime? createdAt,
    int? nServings,
    int? currentServings,
  }) {
    final urls = imageUrls ?? this.imageUrls;
    return RecipeDetail(
      id: id ?? this.id,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      imageUrl: imageUrl ?? urls.first,
      prepTime: prepTime ?? this.prepTime,
      averageRating: averageRating ?? this.averageRating,
      reviewCount: reviewCount ?? this.reviewCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      isFavorited: isFavorited ?? this.isFavorited,
      shortIngredients: shortIngredients ?? this.shortIngredients,
      hasAllergy: hasAllergy ?? this.hasAllergy,
      rank: rank ?? this.rank,
      ingredientIds: ingredientIds ?? this.ingredientIds,
      imageUrls: urls,
      categories: categories ?? this.categories,
      ingredients: ingredients ?? this.ingredients,
      nutrition: nutrition != null ? nutrition() : this.nutrition,
      steps: steps ?? this.steps,
      createdAt: createdAt ?? this.createdAt,
      nServings: nServings ?? this.nServings,
      currentServings: currentServings ?? this.currentServings,
    );
  }
}
