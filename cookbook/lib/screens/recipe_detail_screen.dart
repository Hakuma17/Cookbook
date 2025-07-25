// ------------------------------------------------------------
// 2025‑07‑23  – fix: empty‑steps handling, bottom overflow,
//                infinite‑width button, clean‑ups
// ------------------------------------------------------------

import 'dart:async';
import 'dart:developer';

import 'package:cookbook/widgets/voice_button.dart';
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

class RecipeDetailScreen extends StatefulWidget {
  final int recipeId;
  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  /* ───── controllers ───── */
  final _pageCtrl = PageController();
  final _commentKey = GlobalKey();
  final _scrollCtrl = ScrollController();

  /* ───── futures ───── */
  late Future<RecipeDetail> _initFuture;

  /* ───── UI state ───── */
  int _currentPage = 0;
  bool _isLoggedIn = false;
  bool _isFavorited = false;
  int _currentServings = 1;
  List<Comment> _comments = [];
  int _userRating = 0;

  /* ───── life‑cycle ───── */
  @override
  void initState() {
    super.initState();
    if (widget.recipeId <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      _initFuture = Future.error('Invalid Recipe ID');
      return;
    }
    _initFuture = _loadAllData();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /* ───── data load ───── */
  Future<RecipeDetail> _loadAllData() async {
    try {
      final results = await Future.wait([
        AuthService.isLoggedIn(),
        ApiService.fetchRecipeDetail(widget.recipeId),
        ApiService.getComments(widget.recipeId),
        AuthService.getLoginData(),
      ]);

      final isLoggedIn = results[0] as bool;
      final recipe = results[1] as RecipeDetail;
      final rawComments = results[2] as List<Comment>;
      final loginData = results[3] as Map<String, dynamic>;

      final mapped = rawComments
          .map((c) => c.isMine
              ? c.copyWith(
                  profileName: () => loginData['profileName'] ?? c.profileName,
                  avatarUrl: () => loginData['profileImage'] ?? c.avatarUrl,
                )
              : c)
          .toList();

      final myComment =
          mapped.firstWhere((c) => c.isMine, orElse: () => Comment.empty());

      if (mounted) {
        setState(() {
          _isLoggedIn = isLoggedIn;
          _isFavorited = recipe.isFavorited;
          _currentServings = recipe.currentServings;
          _comments = mapped;
          _userRating = myComment.rating ?? 0;
        });
      }
      return recipe;
    } on UnauthorizedException {
      await AuthService.logout();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
      }
      throw Exception('Session หมดอายุ');
    } on ApiException catch (e) {
      throw Exception(e.message);
    } catch (e, st) {
      log('loadAllData error', error: e, stackTrace: st);
      throw Exception('ไม่สามารถโหลดข้อมูลสูตรอาหารได้');
    }
  }

  /* ───── build ───── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<RecipeDetail>(
        future: _initFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return _buildErrorState(snap.error?.toString() ?? 'ไม่พบข้อมูล');
          }

          final recipe = snap.data!;
          final hasSteps = recipe.steps.isNotEmpty;

          return RefreshIndicator(
            onRefresh: () async => setState(() => _initFuture = _loadAllData()),
            child: CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
                _buildSliverAppBar(recipe),
                _buildSliverContent(recipe, hasSteps),
              ],
            ),
          );
        },
      ),
    );
  }

  /* ───── Sliver app‑bar ───── */
  Widget _buildSliverAppBar(RecipeDetail recipe) {
    final theme = Theme.of(context);
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      stretch: true,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      backgroundColor: theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            CarouselWidget(
              imageUrls: recipe.imageUrls,
              controller: _pageCtrl,
              onPageChanged: (i) => setState(() => _currentPage = i),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                  stops: [0, .5],
                ),
              ),
            ),
            if (recipe.imageUrls.length > 1)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: _buildDotsIndicator(recipe.imageUrls.length, theme),
              ),
          ],
        ),
      ),
    );
  }

  /* ───── Sliver content ───── */
  Widget _buildSliverContent(RecipeDetail recipe, bool hasSteps) {
    final theme = Theme.of(context);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return SliverList(
      delegate: SliverChildListDelegate(
        [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('วัตถุดิบ', style: theme.textTheme.titleLarge),
                    CartButton(
                      recipeId: recipe.id,
                      currentServings: _currentServings,
                      onServingsChanged: (v) =>
                          setState(() => _currentServings = v),
                      onAddToCart: _addToCart,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                IngredientTable(
                  items: recipe.ingredients,
                  baseServings: recipe.nServings,
                  currentServings: _currentServings,
                ),
                const SizedBox(height: 24),

                // Nutrition
                if (recipe.nutrition != null) ...[
                  Text('โภชนาการ', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  NutritionSummary(
                    nutrition: recipe.nutrition!,
                    baseServings: recipe.nServings,
                    currentServings: _currentServings,
                  ),
                  const SizedBox(height: 24),
                ],

                // Steps
                Text('วิธีทำ', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                if (hasSteps)
                  StepWidget(
                    steps: recipe.steps,
                    onStepTap: (i) => Navigator.pushNamed(
                      context,
                      '/step_detail',
                      arguments: {
                        'steps': recipe.steps,
                        'imageUrls': recipe.imageUrls,
                        'initialIndex': i,
                      },
                    ),
                  )
                else
                  Text('เมนูนี้ยังไม่มีขั้นตอนวิธีทำ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 24),

                // Favorite
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _toggleFavorite(!_isFavorited),
                    icon: Icon(
                      _isFavorited ? Icons.bookmark : Icons.bookmark_border,
                      color: Colors.white,
                    ),
                    label: const Text('เพิ่มเป็นสูตรโปรด',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 56),
                      shape: const StadiumBorder(),
                      backgroundColor: _isFavorited
                          ? theme.colorScheme.primary
                          : Colors.grey.shade500,
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Voice button
                VoiceButton(
                  enabled: hasSteps,
                  onPressed: hasSteps
                      ? () => Navigator.pushNamed(
                            context,
                            '/step_detail',
                            arguments: {
                              'steps': recipe.steps,
                              'imageUrls': recipe.imageUrls,
                              'initialIndex': 0,
                            },
                          )
                      : null,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),

          // Comments
          CommentSection(
            key: _commentKey,
            myComment: _comments.firstWhere((c) => c.isMine,
                orElse: () => Comment.empty()),
            otherComments: _comments.where((c) => !c.isMine).toList(),
            currentRating: _userRating,
            isLoggedIn: _isLoggedIn,
            onRatingSelected: (r) => _openEditor(initRating: r),
            onCommentPressed: () => _openEditor(initRating: _userRating),
            onEdit: (c) => _openEditor(
                initRating: c.rating ?? 0, initText: c.comment ?? ''),
            onDelete: (_) => _deleteComment(),
          ),

          // bottom padding to avoid overflow
          SizedBox(height: 32 + bottomPad),
        ],
      ),
    );
  }

  /* ───── dots indicator ───── */
  Widget _buildDotsIndicator(int count, ThemeData theme) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          count,
          (i) {
            final active = i == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 10 : 8,
              height: active ? 10 : 8,
              decoration: BoxDecoration(
                color: active ? theme.colorScheme.primary : Colors.white70,
                shape: BoxShape.circle,
              ),
            );
          },
        ),
      );

  /* ───── error ui ───── */
  Widget _buildErrorState(String msg) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                const SizedBox(height: 16),
                Text(msg,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => setState(() => _initFuture = _loadAllData()),
                  child: const Text('ลองอีกครั้ง'),
                ),
              ],
            ),
          ),
        ),
      );

  /* ───── helpers ───── */
  void _showSnack(String m, {bool err = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor:
          err ? Theme.of(context).colorScheme.error : Colors.green[600],
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _scrollToComments() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _commentKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut);
      }
    });
  }

  /* ───── actions ───── */
  Future<void> _toggleFavorite(bool fav) async {
    if (!_isLoggedIn) {
      final ok = await Navigator.pushNamed(context, '/login');
      if (ok != true) return;
      setState(() => _initFuture = _loadAllData());
      return;
    }

    setState(() => _isFavorited = fav);
    try {
      await ApiService.toggleFavorite(widget.recipeId, fav);
    } on ApiException catch (e) {
      _showSnack(e.message);
      setState(() => _isFavorited = !fav);
    }
  }

  Future<void> _addToCart() async {
    if (!_isLoggedIn) {
      final ok = await Navigator.pushNamed(context, '/login');
      if (ok != true) return;
      setState(() => _initFuture = _loadAllData());
      return;
    }

    try {
      await ApiService.updateCart(widget.recipeId, _currentServings.toDouble());
      _showSnack('เพิ่มลงตะกร้าเรียบร้อยแล้ว', err: false);
    } on ApiException catch (e) {
      _showSnack(e.message);
    }
  }

  Future<void> _openEditor({int initRating = 0, String initText = ''}) async {
    if (!_isLoggedIn) {
      final ok = await Navigator.pushNamed(context, '/login');
      if (ok != true) return;
    }

    final offset = _scrollCtrl.offset;
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CommentEditor(
        recipeId: widget.recipeId,
        initialRating: initRating,
        initialText: initText,
      ),
    );

    if (submitted == true) {
      setState(() {
        _initFuture = _loadAllData().then((v) {
          _scrollToComments();
          return v;
        });
      });
    } else if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _deleteComment() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: const Text('คุณต้องการลบคอมเมนต์นี้ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('ลบ',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.deleteComment(widget.recipeId);
      setState(() {
        _initFuture = _loadAllData().then((v) {
          _scrollToComments();
          return v;
        });
      });
    } on ApiException catch (e) {
      _showSnack(e.message);
    }
  }
}
