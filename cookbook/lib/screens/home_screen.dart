// lib/screens/home_screen.dart
// ---------------------------------------------------------------------------
// ★ 2025‑07‑21 – UI‑polish & gesture safe
//   • ลด Ingredient section สูง 180 → 150         (★A)
//   • ลด Recipe card list สูง 280 → 260            (★B)
//   • bottomNavigationBar ห่อ SafeArea(bottom)     (★C)
//   • เก็บ _allergyIngredientIds สำหรับ warning    (★D)
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';

import '../main.dart';
import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/recipe_card.dart';
import '../widgets/ingredient_card.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/allergy_warning_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  /* ───────────── State ───────────── */
  late Future<void> _initFuture;

  List<Ingredient> _ingredients = [];
  List<Recipe> _popularRecipes = [];
  List<Recipe> _newRecipes = [];
  List<Ingredient> _allergyList = [];
  List<int> _allergyIngredientIds = []; // ★D

  bool _isLoggedIn = false;
  String? _profileName;
  String? _profileImage;
  int _selectedIndex = 0;
  String? _errorMessage;

  /* ═════════════ INIT ═════════════ */
  @override
  void initState() {
    super.initState();
    _initFuture = _initialize();
  }

  Future<void> _initialize({bool forceRefresh = false}) async {
    if (mounted) setState(() => _errorMessage = null);
    try {
      await Future.wait([
        _loadLoginStatus(),
        _fetchAllData(force: forceRefresh),
      ]);
    } on UnauthorizedException {
      await _handleLogout(silent: true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e, st) {
      log('init error: $e', stackTrace: st);
      if (mounted) setState(() => _errorMessage = 'เกิดข้อผิดพลาดไม่คาดคิด');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    setState(() {
      _initFuture = _initialize(forceRefresh: true);
    });
  }

  /* ═════════════ DATA ═════════════ */
  Future<void> _fetchAllData({bool force = false}) async {
    final results = await Future.wait([
      ApiService.fetchIngredients(),
      ApiService.fetchPopularRecipes(),
      ApiService.fetchNewRecipes(),
    ]);
    if (!mounted) return;
    setState(() {
      _ingredients = results[0] as List<Ingredient>;
      _popularRecipes = results[1] as List<Recipe>;
      _newRecipes = results[2] as List<Recipe>;
    });
  }

  Future<void> _loadLoginStatus() async {
    if (await AuthService.isLoggedIn()) {
      final login = await AuthService.getLoginData();
      final allergy = await ApiService.fetchAllergyIngredients();
      if (!mounted) return;
      setState(() {
        _isLoggedIn = true;
        _profileName = login['profileName'];
        _profileImage = login['profileImage'];
        _allergyList = allergy;
        _allergyIngredientIds = allergy.map((e) => e.id).toList(); // ★D
      });
    } else if (mounted) {
      setState(() {
        _isLoggedIn = false;
        _profileName = null;
        _profileImage = null;
        _allergyList = [];
        _allergyIngredientIds = [];
      });
    }
  }

  /* ═════════════ LOGOUT ═════════════ */
  Future<void> _handleLogout({bool silent = false}) async {
    await AuthService.logout();
    if (mounted && !silent) {
      setState(() {
        _isLoggedIn = false;
        _profileName = null;
        _profileImage = null;
        _allergyList = [];
        _allergyIngredientIds = [];
        _initFuture = _initialize(forceRefresh: true);
      });
    }
  }

  /* ═════════════ NAV ═════════════ */
  Future<void> _onNavTap(int idx) async {
    // ── ❶ ถ้ากด “ค้นหา” ──────────────────
    if (idx == 1) {
      // เปิดหน้า Search แบบ route (สร้าง‑ทำลายทุกครั้ง)
      await Navigator.pushNamed(context, '/search');
      // หลัง back กลับมา เซ็ต tab กลับเป็น Home
      if (mounted) setState(() => _selectedIndex = 0);
      return;
    }

    // ── ❷ My Recipes / Profile (ต้องล็อกอิน) ──────────────────
    const routes = [null, null, '/my_recipes', '/profile'];
    if (routes[idx] != null) {
      if (!_isLoggedIn) {
        final ok = await Navigator.pushNamed(context, '/login');
        if (ok == true) didPopNext();
        return;
      }
      await Navigator.pushNamed(context, routes[idx]!);
      return;
    }

    // ── ❸ กรณี idx == 0 (Home) ──────────────────
    setState(() => _selectedIndex = idx);
  }

  /* ═════════════ BUILD ═════════════ */
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFuture,
      builder: (_, snap) {
        if (_ingredients.isEmpty &&
            snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (_errorMessage != null) {
          return Scaffold(body: Center(child: Text(_errorMessage!)));
        }

        return Scaffold(
          backgroundColor: const Color(0xFFFDF7F2),
          body: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildMainHomeView(),
                // index 1 ไม่ต้องใส่อะไร (หรือใส่ Container())
                // เพราะเราจะเปิด Search ด้วย Navigator ต่างหาก
                const SizedBox.shrink(),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            // ★C
            top: false,
            child: CustomBottomNav(
              selectedIndex: _selectedIndex,
              onItemSelected: _onNavTap,
            ),
          ),
        );
      },
    );
  }

  /* ═════════════ MAIN VIEW ═════════════ */
  Widget _buildMainHomeView() => Column(
        children: [
          _buildCustomAppBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _initialize(forceRefresh: true),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIngredientSection(),
                    const SizedBox(height: 24),
                    _buildRecipeSection(
                      title: 'สูตรอาหารยอดนิยม',
                      recipes: _popularRecipes,
                      onAction: () => Navigator.pushNamed(
                        context,
                        '/search',
                        arguments: {'initialSortIndex': 0},
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildRecipeSection(
                      title: 'สูตรอาหารอัปเดตใหม่',
                      recipes: _newRecipes,
                      onAction: () => Navigator.pushNamed(
                        context,
                        '/search',
                        arguments: {'initialSortIndex': 2},
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      );

  /* ═════════════ INGREDIENT SECTION ═════════════ */
  Widget _buildIngredientSection() => Container(
        color: const Color(0xFFFFE3D9),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            _buildSectionHeader(
              title: 'วัตถุดิบ',
              actionText: 'ดูทั้งหมด',
              onAction: () => Navigator.pushNamed(context, '/all_ingredients'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 150, // ★A
              child: _ingredients.isEmpty
                  ? const Center(child: Text('ไม่พบวัตถุดิบ'))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _ingredients.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 16),
                      itemBuilder: (_, i) => IngredientCard(
                        ingredient: _ingredients[i],
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/search',
                          arguments: {
                            'ingredients': [_ingredients[i].name]
                          },
                        ),
                      ),
                    ),
            ),
          ],
        ),
      );

  /* ═════════════ RECIPE SECTION ═════════════ */
  Widget _buildRecipeSection({
    required String title,
    required List<Recipe> recipes,
    required VoidCallback onAction,
  }) =>
      Column(
        children: [
          _buildSectionHeader(
              title: title, actionText: 'ดูเพิ่มเติม', onAction: onAction),
          const SizedBox(height: 12),
          SizedBox(
            height: 250, // ★B
            child: recipes.isEmpty
                ? const Center(child: Text('ยังไม่มีสูตรอาหาร'))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: recipes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (_, i) => RecipeCard(
                      recipe: recipes[i],
                      onTap: () => _handleRecipeTap(recipes[i]),
                    ),
                  ),
          ),
        ],
      );

  /* ═════════════ COMMON HEADER ═════════════ */
  Widget _buildSectionHeader({
    required String title,
    required String actionText,
    required VoidCallback onAction,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          InkWell(
            onTap: onAction,
            child: Text(
              actionText,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /* ═════════════ CUSTOM APP BAR ═════════════ */
  Widget _buildCustomAppBar() {
    final theme = Theme.of(context);
    ImageProvider avatar = const AssetImage('assets/images/default_avatar.png');
    if (_isLoggedIn && _profileImage?.isNotEmpty == true) {
      avatar = NetworkImage(_profileImage!);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 24, backgroundImage: avatar),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isLoggedIn ? 'สวัสดี ${_profileName ?? ''}' : 'ผู้เยี่ยมชม',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(
                _isLoggedIn ? Icons.logout_outlined : Icons.login_outlined),
            onPressed: _isLoggedIn ? _handleLogout : () => _onNavTap(3),
          ),
        ],
      ),
    );
  }

  /* ═════════════ ALLERGY LOGIC ═════════════ */
  void _handleRecipeTap(Recipe recipe) {
    final hasAllergy = _isLoggedIn &&
        _allergyIngredientIds.isNotEmpty &&
        recipe.ingredientIds.any(_allergyIngredientIds.contains);

    if (hasAllergy) {
      _showAllergyWarning(recipe);
    } else {
      Navigator.pushNamed(context, '/recipe_detail', arguments: recipe);
    }
  }

  void _showAllergyWarning(Recipe recipe) {
    final badIds =
        recipe.ingredientIds.where(_allergyIngredientIds.contains).toSet();
    final badNames = _allergyList
        .where((ing) => badIds.contains(ing.id))
        .map((ing) => ing.displayName ?? ing.name)
        .toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AllergyWarningDialog(
        recipe: recipe,
        badIngredientNames: badNames,
        onConfirm: (r) =>
            Navigator.pushNamed(context, '/recipe_detail', arguments: r),
      ),
    );
  }
}
