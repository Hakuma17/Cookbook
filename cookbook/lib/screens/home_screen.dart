// lib/screens/home_screen.dart
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
// ★ เพิ่ม import ของ AllergyWarningDialog
import '../widgets/allergy_warning_dialog.dart';

import 'login_screen.dart';
import 'all_ingredients_screen.dart';
import 'my_recipes_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart'; // เพิ่ม import SearchScreen

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  /* ───────────── data state ───────────── */
  late Future<List<Ingredient>> _futureIngredients;
  late Future<List<Recipe>> _futurePopular;
  late Future<List<Recipe>> _futureNew;

  bool _isLoggedIn = false;
  String? _profileName;
  String? _profileImage;
  int _selectedIndex = 0;

  List<int> _allergyIngredientIds = [];
  List<Ingredient> _allergyList = []; // เก็บรายการวัตถุดิบที่แพ้แบบเต็ม

  bool _isLoadingInit = true;
  DateTime _lastFetch = DateTime.fromMillisecondsSinceEpoch(0);
  int _refreshToken = 0; // force AnimatedSwitcher rebuild
  bool _loggingOut = false; // กันกดซ้ำ

  /* ───────────── init ───────────── */
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadLoginStatus();
    await _fetchAllData(force: true); // ดึงครั้งแรกเสมอ
    if (!mounted) return;
    setState(() => _isLoadingInit = false);
  }

  /* ───────────── fetch helpers ───────────── */
  Future<void> _fetchAllData({bool force = false}) async {
    if (!force &&
        DateTime.now().difference(_lastFetch) < const Duration(minutes: 3)) {
      return;
    }
    _lastFetch = DateTime.now();

    final futures = await Future.wait<List<dynamic>>([
      ApiService.fetchIngredients().timeout(const Duration(seconds: 10),
          onTimeout: () => <Ingredient>[]),
      ApiService.fetchPopularRecipes()
          .timeout(const Duration(seconds: 10), onTimeout: () => <Recipe>[]),
      ApiService.fetchNewRecipes()
          .timeout(const Duration(seconds: 10), onTimeout: () => <Recipe>[]),
    ]).catchError((e, _) {
      log('Fetch all data error: $e');
      return [<Ingredient>[], <Recipe>[], <Recipe>[]];
    });

    if (!mounted) return;
    setState(() {
      _futureIngredients = Future.value(futures[0] as List<Ingredient>);
      _futurePopular = Future.value(futures[1] as List<Recipe>);
      _futureNew = Future.value(futures[2] as List<Recipe>);
      _refreshToken++;
    });
  }

  Future<void> _reloadLoginAndData() async {
    await _loadLoginStatus();
    await _fetchAllData(force: true);
  }

  Future<void> _loadLoginStatus() async {
    try {
      final loginData = await AuthService.getLoginData();
      if (!mounted) return;
      setState(() {
        _isLoggedIn = loginData['isLoggedIn'] ?? false;
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
        _allergyList = [];
        _allergyIngredientIds = [];
      }
    } catch (e) {
      log('loadLoginStatus error: $e');
    }
  }

  /* ───────────── bottom-nav ───────────── */
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
    var ok = await AuthService.isLoggedIn();
    if (ok) return true;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    ok = await AuthService.isLoggedIn();
    if (ok) await _reloadLoginAndData();
    return ok;
  }

  /* ───────────── route aware ───────────── */
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

  /* ───────────── allergy check ───────────── */
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
    // หา id ของวัตถุดิบที่ชนกับสูตร แล้วแมปเป็นชื่อ
    final badIds = recipe.ingredientIds
        .where((id) => _allergyIngredientIds.contains(id))
        .toSet();

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
        onConfirm: (r) {
          Navigator.pushNamed(context, '/recipe_detail', arguments: r);
        },
      ),
    );
  }

  /* ───────────── build ───────────── */
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
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildMainHomeView(),
          const Center(child: Text('Explore ยังไม่เปิด')),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: _selectedIndex,
        isLoggedIn: _isLoggedIn,
        onItemSelected: _onNavTap,
      ),
    );
  }

  /* ───────────── UI sections ───────────── */
  Widget _buildMainHomeView() => Column(
        children: [
          _buildCustomAppBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchAllData(force: true),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIngredientSection(),
                    const SizedBox(height: 32),
                    _buildRecipeSection(
                      'สูตรอาหารยอดนิยม',
                      _futurePopular,
                      onAction: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SearchScreen(
                            initialSortIndex: 0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildRecipeSection(
                      'สูตรอาหารอัปเดตใหม่',
                      _futureNew,
                      onAction: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SearchScreen(
                            initialSortIndex: 2,
                          ),
                        ),
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

  PreferredSizeWidget _buildCustomAppBar() {
    final provider = (_isLoggedIn && _profileImage?.startsWith('http') == true)
        ? NetworkImage(_profileImage!)
        : const AssetImage('assets/images/default_avatar.png') as ImageProvider;

    return PreferredSize(
      preferredSize: const Size.fromHeight(79),
      child: Container(
        height: 79,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE1E1E1))),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey[300],
              backgroundImage: provider,
              onBackgroundImageError: (_, __) {},
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _isLoggedIn ? 'สวัสดี ${_profileName ?? ''}' : 'ผู้เยี่ยมชม',
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 17.6,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0A2533),
                ),
              ),
            ),
            IconButton(
              icon: Icon(_isLoggedIn ? Icons.logout : Icons.login_rounded),
              color: const Color(0xFF666666),
              iconSize: 30,
              onPressed: _loggingOut
                  ? null
                  : () async {
                      if (_isLoggedIn) {
                        // logout
                        setState(() => _loggingOut = true);
                        await AuthService.logout();
                        ApiService.clearSession();
                        if (mounted) {
                          setState(() {
                            _isLoggedIn = false;
                            _profileName = null;
                            _profileImage = null;
                          });
                          _lastFetch =
                              DateTime.fromMillisecondsSinceEpoch(0); // reset
                          await _fetchAllData(force: true);
                        }
                        if (mounted) setState(() => _loggingOut = false);
                      } else {
                        // go login
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

  Widget _buildIngredientSection() => Container(
        color: const Color(0xFFFFE3D9),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: 'วัตถุดิบ',
              actionText: 'ดูทั้งหมด',
              actionStyle: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0A2533),
              ),
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllIngredientsScreen()),
              ),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: SizedBox(
                key: ValueKey(_refreshToken),
                height: 136,
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
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => IngredientCard(
                        ingredient: list[i],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SearchScreen(
                                ingredients: [list[i].name], // ★ แก้ตรงนี้
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildRecipeSection(
    String title,
    Future<List<Recipe>> future, {
    required VoidCallback onAction, // เพิ่มพารามิเตอร์ onAction
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: title,
            actionText: 'ดูเพิ่มเติม',
            actionStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFF9B05),
            ),
            onAction: onAction, // ใช้ callback ที่รับเข้ามา
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: SizedBox(
              key: ValueKey(future),
              height: 200,
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
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
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

  Widget _buildSectionHeader({
    required String title,
    required String actionText,
    required TextStyle actionStyle,
    required VoidCallback onAction,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0A2533),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onAction,
              child: Text(actionText, style: actionStyle),
            ),
          ],
        ),
      );
}
