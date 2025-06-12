// lib/screens/recipe_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/recipe_detail.dart';
import '../services/api_service.dart';

import '../widgets/carousel_widget.dart';
import '../widgets/recipe_meta_widget.dart';
import '../widgets/tag_list.dart';
import '../widgets/ingredient_table.dart';
import '../widgets/nutrition_summary.dart';
import '../widgets/step_widget.dart';
import '../widgets/cart_button.dart';
import '../widgets/comment_section.dart';

import 'step_detail_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final int recipeId;
  const RecipeDetailScreen({Key? key, required this.recipeId})
      : super(key: key);

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late Future<RecipeDetail> _futureRecipe;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _futureRecipe = ApiService.fetchRecipeDetail(widget.recipeId);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildDots(int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == _currentPage;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4.38),
          width: 5.48,
          height: 5.48,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFF9B05) : const Color(0xFFE3E3E3),
            borderRadius: BorderRadius.circular(2.74),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        body: FutureBuilder<RecipeDetail>(
          future: _futureRecipe,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('เกิดข้อผิดพลาด: ${snap.error}'));
            }
            final recipe = snap.requireData;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ═══ CAROUSEL + OVERLAY ═══
                  SizedBox(
                    height: statusBarHeight + 272.67 + 13.088,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CarouselWidget(
                            imageUrls: recipe.imageUrls,
                            height: 272.67,
                            controller: _pageController,
                            onPageChanged: (i) => setState(() {
                              _currentPage = i;
                            }),
                          ),
                        ),
                        Positioned(
                          top: statusBarHeight + 16,
                          left: 16,
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        Positioned(
                          top: statusBarHeight + 16,
                          left: 56,
                          child: Text(
                            'ขั้นตอนที่ ${_currentPage + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 13.088,
                          left: 0,
                          right: 0,
                          child: Center(
                              child: _buildDots(recipe.imageUrls.length)),
                        ),
                        if (recipe.imageUrls.length > 1)
                          Positioned(
                            right: 16,
                            top: statusBarHeight + (272.67 - 43.63) / 2,
                            child: InkWell(
                              onTap: () {
                                final next = (_currentPage + 1) %
                                    recipe.imageUrls.length;
                                _pageController.animateToPage(
                                  next,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              borderRadius: BorderRadius.circular(21.815),
                              child: Container(
                                width: 43.63,
                                height: 43.63,
                                padding: const EdgeInsets.all(10.91),
                                decoration: const BoxDecoration(
                                  color: Colors.white70,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 21.81,
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ═══ MAIN CONTENT ═══
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        // ชื่อ, rating, date, prep time
                        RecipeMetaWidget(
                          name: recipe.name,
                          averageRating: recipe.averageRating,
                          reviewCount: recipe.reviewCount,
                          createdAt: recipe.createdAt,
                          prepTimeMinutes: recipe.prepTime,
                        ),

                        if (recipe.categories.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          TagList(tags: recipe.categories),
                        ],

                        const SizedBox(height: 24),

                        // วัตถุดิบ + ปุ่มตะกร้า
                        Row(
                          children: [
                            const Text(
                              'วัตถุดิบ',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                height: 24 / 16,
                                color: Color(0xFF000000),
                              ),
                            ),
                            const Spacer(),
                            CartButton(
                              recipeId: recipe.recipeId,
                              currentServings: recipe.currentServings,
                              onServingsChanged: (count) {
                                ApiService.updateCart(recipe.recipeId, count);
                                setState(() {});
                              },
                              onAddToCart: () {
                                ApiService.updateCart(
                                    recipe.recipeId, recipe.currentServings);
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        IngredientTable(items: recipe.ingredients),

                        const SizedBox(height: 24),

                        // โภชนาการ
                        const Text(
                          'โภชนาการ',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 24 / 16,
                            color: Color(0xFF000000),
                          ),
                        ),
                        const SizedBox(height: 8),
                        NutritionSummary(nutrition: recipe.nutrition),

                        const SizedBox(height: 24),

                        // วิธีทำ (Preview + expand inline)
                        const Text(
                          'วิธีทำ',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 24 / 16,
                            color: Color(0xFF000000),
                          ),
                        ),
                        const SizedBox(height: 8),
                        StepWidget(
                          steps: recipe.steps,
                          previewCount: 3,
                          onStepTap: (index) => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StepDetailScreen(
                                steps: recipe.steps,
                                imageUrls: recipe.imageUrls,
                                initialIndex: index,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // CTA: เพิ่มเป็นสูตรโปรด
                        SizedBox(
                          width: double.infinity,
                          height: 52.35,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await ApiService.toggleFavorite(
                                  recipe.recipeId, !recipe.isFavorited);
                              setState(() {});
                            },
                            icon: const Icon(Icons.add, size: 26.18),
                            label: const Text('เพิ่มเป็นสูตรโปรดของฉัน'),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Voice CTA
                        SizedBox(
                          width: double.infinity,
                          height: 61.18,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => StepDetailScreen(
                                    steps: recipe.steps,
                                    imageUrls: recipe.imageUrls,
                                    initialIndex: 0,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.play_arrow,
                              size: 24,
                              color: Color(0xFF000000),
                            ),
                            label: const Text(
                              'ขั้นตอนที่อธิบายด้วยเสียง',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF000000),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(
                                color: Color(0xFF828282),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(41),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),

                  // ความคิดเห็น
                  CommentSection(
                    comments: recipe.comments,
                    currentRating: recipe.userRating?.toInt() ?? 0,
                    isLoggedIn: true,
                    onRatingSelected: (r) async {
                      await ApiService.postRating(
                          recipe.recipeId, r.toDouble());
                      setState(() {});
                    },
                    onCommentPressed: () {
                      /* เปิด dialog โพสต์ใหม่ */
                    },
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
