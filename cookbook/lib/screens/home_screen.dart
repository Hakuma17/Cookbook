// lib/screens/home_screen.dart

import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';

// ★★★ [NEW] ใช้ SettingsStore เพื่ออ่านค่าสวิตช์ "ตัดคำภาษาไทย"
import 'package:provider/provider.dart';
import '../stores/settings_store.dart';

import '../main.dart';
import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/recipe_card.dart';
import '../widgets/ingredient_card.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/allergy_warning_dialog.dart';

// ⬆️ อ้างอิงค่าความกว้างการ์ดแนวตั้งจาก recipe_card.dart
//    (ถ้าตัว import ไม่ expose constant ให้คัดลอกค่ามาใช้ให้ตรงกัน)
// 🔁 ปรับเป็น 188 ให้ตรงกับการ์ดใหม่ (Meta 2 บรรทัด)
const double kRecipeCardVerticalWidth = 188;

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
  List<int> _allergyIngredientIds = [];

  bool _isLoggedIn = false;
  String? _profileName;
  String? _profileImage;
  int _selectedIndex = 0;
  String? _errorMessage;

  /* ═════════════ INIT ═════════════ */
  @override
  void initState() {
    super.initState();
    // ★ ไม่มีการแก้ไขในส่วนนี้ โครงสร้างดีอยู่แล้ว
    _initFuture = _initialize();
  }

  Future<void> _initialize({bool forceRefresh = false}) async {
    if (mounted) setState(() => _errorMessage = null);
    try {
      // โหลดสถานะล็อกอินและข้อมูลทั้งหมดไปพร้อมกัน
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

  // ★ การใช้ didPopNext เพื่อ refresh ข้อมูลเมื่อกลับมาหน้านี้เป็น Logic ที่ดีมาก
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
    await AuthService.init();
    if (await AuthService.isLoggedIn()) {
      final login = await AuthService.getLoginData();
      final allergy = await ApiService.fetchAllergyIngredients();
      if (!mounted) return;
      setState(() {
        _isLoggedIn = true;
        _profileName = login['profileName'];
        _profileImage = login['profileImage'];
        _allergyList = allergy;
        _allergyIngredientIds = allergy.map((e) => e.id).toList();
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
  // ★ 1. [แก้ไข] ปรับปรุง Logic การนำทางทั้งหมดให้ชัดเจนขึ้น
  // และรองรับการสลับไปหน้า Profile/Settings ตามสถานะ _isLoggedIn
  Future<void> _onNavTap(int idx) async {
    // ถ้ากดแท็บเดิม ไม่ต้องทำอะไร
    if (idx == _selectedIndex) return;

    switch (idx) {
      case 0: // Home
        setState(() => _selectedIndex = idx);
        break;

      case 1: // Search
        await Navigator.pushNamed(context, '/search');
        break;

      case 2: // My Recipes (protected)
        if (!_isLoggedIn) {
          final result = await Navigator.pushNamed(context, '/login');
          if (result == true) didPopNext();
          return;
        }
        await Navigator.pushNamed(context, '/my_recipes');
        break;

      case 3: // Profile / Settings
        final route = _isLoggedIn ? '/profile' : '/settings';
        await Navigator.pushNamed(context, route);
        break;
    }
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
            // ★ ไม่มีการแก้ไขในส่วนนี้ การใช้ IndexedStack ถูกต้องแล้ว
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildMainHomeView(),
                const SizedBox.shrink(),
                const SizedBox.shrink(),
                const SizedBox.shrink(),
              ],
            ),
          ),
          // ★ 2. [แก้ไข] ส่งค่า `isLoggedIn` ที่เรามีอยู่ เข้าไปใน CustomBottomNav
          bottomNavigationBar: CustomBottomNav(
            selectedIndex: _selectedIndex,
            onItemSelected: _onNavTap,
            isLoggedIn: _isLoggedIn,
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
              height: 150,
              child: _ingredients.isEmpty
                  ? const Center(child: Text('ไม่พบวัตถุดิบ'))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _ingredients.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 16),
                      itemBuilder: (_, i) => IngredientCard(
                        ingredient: _ingredients[i],
                        // ================== บรรทัดที่แก้ไข ==================
                        // ลบ onTap ที่ override ออก เพื่อให้ IngredientCard
                        // ใช้ Logic การกดเริ่มต้นของตัวเอง (ที่เราแก้ไปแล้ว)
                        // onTap: () => _onIngredientTap(_ingredients[i]),
                        // =================================================
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
            height: _recipeStripHeight(context), // ✅ คำนวณอัตโนมัติ
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
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2), // +space
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
              style: theme.textTheme.titleMedium?.copyWith(
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
  // ★ 3. [แก้ไข] ทำให้รูปโปรไฟล์กดได้ และปรับปรุงปุ่ม Action ด้านขวา
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
          // ทำให้ CircleAvatar กดได้ เพื่อเป็นทางลัดไปหน้าโปรไฟล์
          GestureDetector(
            onTap: _isLoggedIn ? () => _onNavTap(3) : null,
            child: CircleAvatar(radius: 24, backgroundImage: avatar),
          ),
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
            // ปุ่ม Action นี้ เมื่อกดจะทำงานเหมือนกดแท็บที่ 4
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

  // ================== ส่วนที่แก้ไข (ลบออก) ==================
  // ลบฟังก์ชัน _onIngredientTap และ _hasResults ออกทั้งหมด
  // เนื่องจากไม่ได้ใช้งานแล้ว
  // ======================================================

  // ======= HEIGHT HELPER: คำนวณความสูงแถวการ์ดแนวนอนแบบอัตโนมัติ =======
  double _recipeStripHeight(BuildContext context) {
    // ใช้ความกว้างของการ์ดแนวตั้งเป็นฐาน
    const imageW = kRecipeCardVerticalWidth;
    final ts = Theme.of(context).textTheme;
    final scale = MediaQuery.textScaleFactorOf(context);

    // Helper สำหรับคำนวณความสูงของ Text โดยดูจาก fontSize และ lineHeight
    double lh(TextStyle s) => (s.height ?? 1.2) * (s.fontSize ?? 14);

    final titleH = lh(ts.titleMedium!) * 2 * scale; // ชื่อ 2 บรรทัด
    final metaH = lh(ts.bodyMedium!) * 2 * scale; // Meta 2 บรรทัด
    const padding = 8 + 4 + 8 + 8; // padding ทั้งหมดของการ์ด

    // รวมความสูงทั้งหมด +2 เพื่อ buffer ป้องกัน overflow
    final h = imageW + titleH + metaH + padding + 2;

    // Clamp ค่าความสูงเพื่อไม่ให้สูงเกินไปบนจอเล็ก
    return h.clamp(322.0, 390.0).roundToDouble();
  }
}
