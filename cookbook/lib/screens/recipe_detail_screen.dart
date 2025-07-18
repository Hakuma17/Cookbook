// lib/screens/recipe_detail_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/recipe_detail.dart';
import '../models/comment.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

import '../widgets/carousel_widget.dart';
import '../widgets/recipe_meta_widget.dart';
import '../widgets/tag_list.dart';
import '../widgets/ingredient_table.dart';
import '../widgets/nutrition_summary.dart';
import '../widgets/step_widget.dart';
import '../widgets/cart_button.dart';
import '../widgets/comment_section.dart';
import '../widgets/comment_editor.dart';
import '../widgets/custom_bottom_nav.dart';

import 'login_screen.dart';
import 'step_detail_screen.dart';
import 'my_recipes_screen.dart';
import 'profile_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final int recipeId;
  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final _pageCtrl = PageController();
  final _scrollCtrl = ScrollController();
  final _commentKey = GlobalKey();

  late Future<RecipeDetail?> _futureRecipe; // ← nullable (404 = null)

  int _currentPage = 0;
  int _selectedIndex = 2;
  bool _isLoggedIn = false;
  bool _isFavorited = false;
  int _currentServings = 1;

  List<Comment> _comments = [];
  int _userRating = 0;

  @override
  void initState() {
    super.initState();
    if (widget.recipeId <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบสูตรอาหารที่ต้องการ')),
        );
      });
      return;
    }
    _futureRecipe = _safeFetchDetail();
    _refreshData();
  }

  Future<RecipeDetail?> _safeFetchDetail() async {
    try {
      return await ApiService.fetchRecipeDetail(widget.recipeId);
    } catch (_) {
      return null; // network error / 404
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToComments() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _commentKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _openEditor({int initRating = 0, String initText = ''}) async {
    final offset = _scrollCtrl.offset;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CommentEditor(
        recipeId: widget.recipeId,
        initialRating: initRating,
        initialText: initText,
        onSubmitted: () {},
      ),
    );

    if (ok == true) await _refreshData();

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _scrollCtrl.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _deleteComment() async {
    await ApiService.deleteComment(widget.recipeId);
    await _refreshData();
    _scrollToComments();
  }

  Future<void> _refreshData() async {
    try {
      final loggedIn = await AuthService.isLoggedIn();
      final recipe = await ApiService.fetchRecipeDetail(widget.recipeId);
      final rawComment = await ApiService.getComments(widget.recipeId);
      final loginData = await AuthService.getLoginData();

      final mapped = rawComment.map((c) {
        if (!c.isMine) return c;
        return Comment(
          userId: c.userId,
          profileName: loginData['profileName'] ?? c.profileName,
          avatarUrl: loginData['profileImage'] ?? c.avatarUrl,
          rating: c.rating,
          comment: c.comment,
          createdAt: c.createdAt,
          isMine: true,
        );
      }).toList();

      final mine =
          mapped.firstWhere((c) => c.isMine, orElse: () => Comment.empty());

      if (mounted) {
        setState(() {
          _futureRecipe = Future.value(recipe);
          _comments = mapped;
          _userRating = mine.rating ?? 0;
          _isLoggedIn = loggedIn;
          _currentServings = recipe.currentServings;
          _isFavorited = recipe.isFavorited;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ดึงข้อมูลล้มเหลว: $e')),
        );
      }
    }
  }

  Widget _buildDots(int total, double dot) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(total, (i) {
          final active = i == _currentPage;
          return Container(
            margin: EdgeInsets.symmetric(horizontal: dot / 2),
            width: dot,
            height: dot,
            decoration: BoxDecoration(
              color: active ? const Color(0xFFFF9B05) : const Color(0xFFE3E3E3),
              borderRadius: BorderRadius.circular(dot / 2),
            ),
          );
        }),
      );

  @override
  Widget build(BuildContext context) {
    final statusBar = MediaQuery.of(context).padding.top;

    return LayoutBuilder(builder: (context, constraints) {
      /* ───── responsive numbers ───── */
      final w = constraints.maxWidth;

      double clamp(double v, double min, double max) =>
          v < min ? min : (v > max ? max : v);

      final carouselH = clamp(w * 0.68, 220, 340); // รูปหลัก
      final dotSz = clamp(w * 0.014, 4.5, 7); // ดอทแถบล่าง
      final nextBtn = clamp(w * 0.11, 40, 56); // ปุ่ม next
      final paddingH = clamp(w * 0.04, 12, 24); // ขอบซ้าย/ขวา
      final text16 = clamp(w * 0.04, 14, 18); // ฟอนต์ 16→ responsive

      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          extendBodyBehindAppBar: true,
          body: FutureBuilder<RecipeDetail?>(
            future: _futureRecipe,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.data == null) {
                return const Center(child: Text('ไม่พบสูตรอาหารนี้'));
              }

              final recipe = snap.data!;

              return RefreshIndicator(
                onRefresh: _refreshData,
                child: SingleChildScrollView(
                  controller: _scrollCtrl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: statusBar + carouselH + 16,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CarouselWidget(
                                imageUrls: recipe.imageUrls,
                                height: carouselH,
                                controller: _pageCtrl,
                                onPageChanged: (i) =>
                                    setState(() => _currentPage = i),
                              ),
                            ),
                            Positioned(
                              top: statusBar + 16,
                              left: 16,
                              child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 24),
                              ),
                            ),
                            if (recipe.imageUrls.length > 1) ...[
                              Positioned(
                                bottom: 20,
                                left: 0,
                                right: 0,
                                child: Center(
                                    child: _buildDots(
                                        recipe.imageUrls.length, dotSz)),
                              ),
                              Positioned(
                                right: 16,
                                top: statusBar + (carouselH - nextBtn) / 2,
                                child: _NextButton(
                                  size: nextBtn,
                                  iconSize: nextBtn * 0.55,
                                  onTap: () {
                                    final next = (_currentPage + 1) %
                                        recipe.imageUrls.length;
                                    _pageCtrl.animateToPage(
                                      next,
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: paddingH),
                        child: _MainContent(
                          recipe: recipe,
                          currentServings: _currentServings,
                          onServingsChange: (v) =>
                              setState(() => _currentServings = v),
                          isFavorited: _isFavorited,
                          onToggleFavorite: _toggleFavorite,
                          baseFont: text16,
                        ),
                      ),
                      CommentSection(
                        key: _commentKey,
                        comments: _comments,
                        currentRating: _userRating,
                        isLoggedIn: _isLoggedIn,
                        onRatingSelected: (r) async {
                          if (!await AuthService.checkAndRedirectIfLoggedOut(
                              context)) return;
                          _openEditor(initRating: r);
                        },
                        onCommentPressed: () {
                          if (!_isLoggedIn) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen()),
                            ).then((_) => _refreshData());
                            return;
                          }
                          _openEditor(initRating: _userRating);
                        },
                        onEdit: (c) => _openEditor(
                            initRating: c.rating ?? 0,
                            initText: c.comment ?? ''),
                        onDelete: (_) => _deleteComment(),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              );
            },
          ),
          bottomNavigationBar: CustomBottomNav(
            selectedIndex: _selectedIndex,
            isLoggedIn: _isLoggedIn,
            onItemSelected: _onBottomNav,
          ),
        ),
      );
    });
  }

  Future<void> _onBottomNav(int idx) async {
    if (idx == 2 || idx == 3) {
      if (!await AuthService.checkAndRedirectIfLoggedOut(context)) return;
    }

    if (idx == _selectedIndex) {
      if (idx == 2) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyRecipesScreen()),
        );
      } else if (idx == 3) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );
      }
    } else {
      setState(() => _selectedIndex = idx);
    }
  }

  Future<void> _toggleFavorite(bool fav) async {
    if (!await AuthService.checkAndRedirectIfLoggedOut(context)) return;
    setState(() => _isFavorited = fav);
    await ApiService.toggleFavorite(widget.recipeId, fav);
  }
}

class _NextButton extends StatelessWidget {
  final double size;
  final double iconSize;
  final VoidCallback onTap;
  const _NextButton(
      {required this.size, required this.iconSize, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.25),
        decoration: const BoxDecoration(
          color: Colors.white70,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.arrow_forward_ios,
            size: iconSize, color: const Color(0xFF666666)),
      ),
    );
  }
}

class _MainContent extends StatelessWidget {
  final RecipeDetail recipe;
  final int currentServings;
  final ValueChanged<int> onServingsChange;
  final bool isFavorited;
  final ValueChanged<bool> onToggleFavorite;
  final double baseFont; // responsive font base

  const _MainContent({
    required this.recipe,
    required this.currentServings,
    required this.onServingsChange,
    required this.isFavorited,
    required this.onToggleFavorite,
    required this.baseFont,
  });

  @override
  Widget build(BuildContext context) {
    final baseServ = recipe.nServings;
    final titleF = baseFont + 2;
    final smallF = baseFont - 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
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

        /* ───────── ingredients ───────── */
        Row(
          children: [
            Text(
              'วัตถุดิบ',
              style: TextStyle(fontSize: baseFont, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            CartButton(
              recipeId: recipe.recipeId,
              currentServings: currentServings,
              onServingsChanged: onServingsChange,
              onAddToCart: () async {
                if (!await AuthService.checkAndRedirectIfLoggedOut(context))
                  return;
                await ApiService.updateCart(
                  recipe.recipeId,
                  currentServings.toDouble(),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('เพิ่มลงตะกร้าเรียบร้อยแล้ว')),
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        IngredientTable(
          items: recipe.ingredients,
          baseServings: baseServ,
          currentServings: currentServings,
        ),
        const SizedBox(height: 24),

        /* ───────── nutrition ───────── */
        Text(
          'โภชนาการ',
          style: TextStyle(fontSize: baseFont, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        NutritionSummary(
          nutrition: recipe.nutrition,
          baseServings: baseServ,
          currentServings: currentServings,
        ),
        const SizedBox(height: 24),

        /* ───────── steps ───────── */
        Text(
          'วิธีทำ',
          style: TextStyle(fontSize: baseFont, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        StepWidget(
          steps: recipe.steps,
          previewCount: 3,
          onStepTap: (idx) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StepDetailScreen(
                steps: recipe.steps,
                imageUrls: recipe.imageUrls,
                initialIndex: idx,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        /* ───────── favorite button ───────── */
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => onToggleFavorite(!isFavorited),
            icon: Icon(
              isFavorited ? Icons.bookmark : Icons.bookmark_border,
              size: 26,
              color: Colors.white,
            ),
            label: Text(
              isFavorited ? 'อยู่ในสูตรโปรดแล้ว' : 'เพิ่มเป็นสูตรโปรดของฉัน',
              style: TextStyle(fontSize: baseFont, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9B05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(41),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        /* ───────── voice step button ───────── */
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              if (recipe.steps.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('เมนูนี้ยังไม่มีขั้นตอนประกอบอาหารเลยน้า~'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StepDetailScreen(
                    steps: recipe.steps,
                    imageUrls: recipe.imageUrls,
                    initialIndex: 0,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow, size: 24, color: Colors.black),
            label: Text(
              'ขั้นตอนที่อธิบายด้วยเสียง',
              style: TextStyle(fontSize: smallF, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF828282), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(41),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
