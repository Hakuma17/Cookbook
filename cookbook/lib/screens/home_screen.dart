// lib/screens/home_screen.dart
// ---------------------------------------------------------------------------
// Responsive-tuned 2025-07-xx  ♦ bottom-overflow fix ②
// 2025-07-13 ★ harden session / refactor clamp
// 2025-07-14 ★ safe-future init • fix double setState on dispose
// 2025-07-15 ★ remove pingSession() → compatible with new AuthService
// 2025-07-16 ★ fix use_build_context_synchronously (capture messenger first)
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

import 'login_screen.dart';
import 'all_ingredients_screen.dart';
import 'my_recipes_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  /* ───────────── async data ───────────── */
  late Future<List<Ingredient>> _futureIngredients =
      Future.value(<Ingredient>[]);
  late Future<List<Recipe>> _futurePopular = Future.value(<Recipe>[]);
  late Future<List<Recipe>> _futureNew = Future.value(<Recipe>[]);

  /* ───────────── ui / user state ───────────── */
  bool _isLoggedIn = false;
  String? _profileName;
  String? _profileImage;
  int _selectedIndex = 0;

  List<int> _allergyIngredientIds = [];
  List<Ingredient> _allergyList = [];

  bool _isLoadingInit = true;
  DateTime _lastFetch = DateTime.fromMillisecondsSinceEpoch(0);
  int _refreshToken = 0; // force AnimatedSwitcher reload
  bool _loggingOut = false;

  /* ═════════════════════════ INIT ═════════════════════════ */
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadLoginStatus();
    await _fetchAllData(force: true);
    if (mounted) setState(() => _isLoadingInit = false);
  }

  /* ═══════════════════ DATA LOADERS ════════════════════ */
  Future<void> _fetchAllData({bool force = false}) async {
    if (!force &&
        DateTime.now().difference(_lastFetch) < const Duration(minutes: 3)) {
      return;
    }

    _lastFetch = DateTime.now();
    try {
      final results = await Future.wait([
        ApiService.fetchIngredients().timeout(const Duration(seconds: 8),
            onTimeout: () => <Ingredient>[]),
        ApiService.fetchPopularRecipes()
            .timeout(const Duration(seconds: 8), onTimeout: () => <Recipe>[]),
        ApiService.fetchNewRecipes()
            .timeout(const Duration(seconds: 8), onTimeout: () => <Recipe>[]),
      ]);

      if (!mounted) return;
      setState(() {
        _futureIngredients = Future.value(results[0] as List<Ingredient>);
        _futurePopular = Future.value(results[1] as List<Recipe>);
        _futureNew = Future.value(results[2] as List<Recipe>);
        _refreshToken++;
      });
    } catch (e, st) {
      log('Fetch all data error: $e', stackTrace: st);
    }
  }

  Future<void> _reloadLoginAndData() async {
    await _loadLoginStatus();
    await _fetchAllData(force: true);
  }

  Future<void> _loadLoginStatus() async {
    try {
      final alive = await AuthService.isLoggedIn();
      final loginData = await AuthService.getLoginData();
      if (!mounted) return;

      setState(() {
        _isLoggedIn = alive;
        _profileName = loginData['profileName'];
        _profileImage = loginData['profileImage'];
      });

      if (_isLoggedIn) {
        final allergy = await ApiService.fetchAllergyIngredients().timeout(
            const Duration(seconds: 8),
            onTimeout: () => <Ingredient>[]);
        if (!mounted) return;
        setState(() {
          _allergyList = allergy;
          _allergyIngredientIds = allergy.map((e) => e.id).toList();
        });
      } else {
        setState(() {
          _allergyList = [];
          _allergyIngredientIds = [];
        });
      }
    } catch (e, st) {
      log('loadLoginStatus error: $e', stackTrace: st);
    }
  }

  /* ════════════════ NAVIGATION HANDLERS ═══════════════ */
  Future<void> _onNavTap(int idx) async {
    switch (idx) {
      case 2:
        if (!await _ensureLoggedIn()) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyRecipesScreen()),
        );
        await _reloadLoginAndData();
        break;
      case 3:
        if (!await _ensureLoggedIn()) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );
        await _reloadLoginAndData();
        break;
      default:
        if (mounted) setState(() => _selectedIndex = idx);
    }
  }

  Future<bool> _ensureLoggedIn() async {
    if (await AuthService.isLoggedIn()) return true;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    final ok = await AuthService.isLoggedIn();
    if (ok) await _reloadLoginAndData();
    return ok;
  }

  /* ═══════════════ ROUTE AWARE ═══════════════ */
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
  void didPopNext() => _reloadLoginAndData();

  /* ═══════════════ ALLERGY CHECK ═══════════════ */
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

  /* ═══════════════ BUILD ═══════════════ */
  @override
  Widget build(BuildContext context) {
    if (_isLoadingInit) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F2),
      body: SafeArea(
        top: true,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, box) {
            final m = _metricsFor(box.biggest);
            return IndexedStack(
              index: _selectedIndex,
              children: [
                _buildMainHomeView(m),
                const Center(child: Text('Explore ยังไม่เปิด')),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: _selectedIndex,
        isLoggedIn: _isLoggedIn,
        onItemSelected: _onNavTap,
      ),
    );
  }

  /* ═══════════════ RESPONSIVE METRIC ═══════════════ */
  double _rsClamp(double v, double min, double max) =>
      v < min ? min : (v > max ? max : v);

  _Metrics _metricsFor(Size s) {
    final w = s.width, h = s.height;
    return _Metrics(
      padH: w * 0.064,
      padTop: h * 0.02,
      appBarH: _rsClamp(h * 0.10, 56, 100),
      avatarR: w * 0.059,
      iconSz: w * 0.08,
      txtLg: w * 0.047,
      txtMd: w * 0.042,
      spaceS: h * 0.03,
      spaceM: h * 0.04,
      listH1: _rsClamp(h * 0.24, 160, 340),
      listH2: _rsClamp(h * 0.35, 220, 500),
      sepW: w * 0.032,
    );
  }

  /* ═══════════════ UI SECTIONS ═══════════════ */
  Widget _buildMainHomeView(_Metrics m) => Column(
        children: [
          _buildCustomAppBar(m),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchAllData(force: true),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(top: m.padTop),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIngredientSection(m),
                    SizedBox(height: m.spaceM),
                    _buildRecipeSection(
                      'สูตรอาหารยอดนิยม',
                      _futurePopular,
                      onAction: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SearchScreen(initialSortIndex: 0),
                        ),
                      ),
                      m: m,
                    ),
                    SizedBox(height: m.spaceM),
                    _buildRecipeSection(
                      'สูตรอาหารอัปเดตใหม่',
                      _futureNew,
                      onAction: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SearchScreen(initialSortIndex: 2),
                        ),
                      ),
                      m: m,
                    ),
                    SizedBox(height: m.spaceS),
                  ],
                ),
              ),
            ),
          ),
        ],
      );

  /* ───────────────────────────────────────── */
  PreferredSizeWidget _buildCustomAppBar(_Metrics m) {
    final provider = (_isLoggedIn && _profileImage?.startsWith('http') == true)
        ? NetworkImage(_profileImage!)
        : const AssetImage('assets/images/default_avatar.png') as ImageProvider;

    return PreferredSize(
      preferredSize: Size.fromHeight(m.appBarH),
      child: Container(
        height: m.appBarH,
        padding: EdgeInsets.symmetric(horizontal: m.padH),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE1E1E1))),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: m.avatarR,
              backgroundColor: Colors.grey[300],
              backgroundImage: provider,
              onBackgroundImageError: (_, __) {},
            ),
            SizedBox(width: m.sepW),
            Expanded(
              child: Text(
                _isLoggedIn ? 'สวัสดี ${_profileName ?? ''}' : 'ผู้เยี่ยมชม',
                style: TextStyle(
                  fontFamily: 'Mitr',
                  fontSize: m.txtLg,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0A2533),
                ),
              ),
            ),
            IconButton(
              icon: Icon(_isLoggedIn ? Icons.logout : Icons.login_rounded),
              iconSize: m.iconSz,
              color: const Color(0xFF666666),
              onPressed: _loggingOut
                  ? null
                  : () async {
                      if (_isLoggedIn) {
                        // ← จับ messenger/l10n ก่อน await ใด ๆ
                        final messenger = ScaffoldMessenger.of(context);

                        setState(() => _loggingOut = true);

                        final ok = await AuthService.tryLogout()
                            .catchError((_) => false);
                        ApiService.clearSession();

                        if (!mounted) return;

                        setState(() {
                          _isLoggedIn = false;
                          _profileName = null;
                          _profileImage = null;
                          _loggingOut = false;
                        });

                        _lastFetch = DateTime.fromMillisecondsSinceEpoch(0);
                        await _fetchAllData(force: true);

                        if (!mounted) return;
                        if (!ok) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content:
                                  Text('ออกจากระบบฝ่ายเซิร์ฟเวอร์ไม่สำเร็จ'),
                            ),
                          );
                        }
                      } else {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                        );
                        await _loadLoginStatus();
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  /* --- Ingredient list -------------------------------------------------- */
  Widget _buildIngredientSection(_Metrics m) => Container(
        color: const Color(0xFFFFE3D9),
        padding: EdgeInsets.symmetric(vertical: m.padH * .4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: 'วัตถุดิบ',
              actionText: 'ดูทั้งหมด',
              actionStyle: TextStyle(
                fontFamily: 'Roboto',
                fontSize: m.txtMd,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0A2533),
              ),
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllIngredientsScreen()),
              ),
              padH: m.padH,
            ),
            SizedBox(height: m.padH * .5),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: SizedBox(
                key: ValueKey(_refreshToken),
                height: m.listH1,
                child: FutureBuilder<List<Ingredient>>(
                  future: _futureIngredients,
                  builder: (_, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final list = snap.data ?? [];
                    if (list.isEmpty) {
                      return const Center(child: Text('ยังไม่มีวัตถุดิบ'));
                    }
                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: m.padH),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => SizedBox(width: m.sepW),
                      itemBuilder: (_, i) => IngredientCard(
                        ingredient: list[i],
                        height: m.listH1,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SearchScreen(ingredients: [list[i].name]),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );

  /* --- Recipe lists ----------------------------------------------------- */
  Widget _buildRecipeSection(
    String title,
    Future<List<Recipe>> future, {
    required VoidCallback onAction,
    required _Metrics m,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: title,
            actionText: 'ดูเพิ่มเติม',
            actionStyle: TextStyle(
              fontFamily: 'Roboto',
              fontSize: m.txtMd,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFFF9B05),
            ),
            onAction: onAction,
            padH: m.padH,
          ),
          SizedBox(height: m.padH * .5),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: SizedBox(
              key: ValueKey(future),
              height: m.listH2,
              child: FutureBuilder<List<Recipe>>(
                future: future,
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final list = snap.data ?? [];
                  if (list.isEmpty) {
                    return const Center(child: Text('ยังไม่มีสูตร'));
                  }
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: m.padH),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => SizedBox(width: m.sepW),
                    itemBuilder: (_, i) => RecipeCard(
                      recipe: list[i],
                      onTap: () => _handleRecipeTap(list[i]),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      );

  /* --- small header helper --------------------------------------------- */
  Widget _buildSectionHeader({
    required String title,
    required String actionText,
    required TextStyle actionStyle,
    required VoidCallback onAction,
    required double padH,
  }) =>
      Padding(
        padding: EdgeInsets.symmetric(horizontal: padH),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: padH * .75,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0A2533),
              ),
            ),
            const Spacer(),
            GestureDetector(
                onTap: onAction, child: Text(actionText, style: actionStyle)),
          ],
        ),
      );
}

/* ───────────── responsive metric struct ───────────── */
class _Metrics {
  final double padH,
      padTop,
      appBarH,
      avatarR,
      iconSz,
      txtLg,
      txtMd,
      spaceS,
      spaceM,
      listH1,
      listH2,
      sepW;

  _Metrics({
    required this.padH,
    required this.padTop,
    required this.appBarH,
    required this.avatarR,
    required this.iconSz,
    required this.txtLg,
    required this.txtMd,
    required this.spaceS,
    required this.spaceM,
    required this.listH1,
    required this.listH2,
    required this.sepW,
  });
}
