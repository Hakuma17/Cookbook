import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // สำหรับ RouteObserver
import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../widgets/recipe_card.dart';
import '../widgets/ingredient_card.dart';
import '../widgets/custom_bottom_nav.dart';
import 'login_screen.dart';
import 'all_ingredients_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  late Future<List<Ingredient>> _futureIngredients;
  late Future<List<Recipe>> _futurePopular;
  late Future<List<Recipe>> _futureNew;

  bool _isLoggedIn = false;
  String? _profileName;
  String? _profileImage;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadLoginStatus();
    _loadData();
  }

  void _loadData() {
    _futureIngredients = ApiService.fetchIngredients();
    _futurePopular = ApiService.fetchPopularRecipes();
    _futureNew = ApiService.fetchNewRecipes();
  }

  /// โหลดสถานะจาก SharedPreferences
  Future<void> _loadLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      _profileName = prefs.getString('profileName');
      _profileImage = prefs.getString('profileImage');
    });
  }

  void _onNavTap(int idx) {
    if ((idx == 2 || idx == 3) && !_isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      ).then((_) => _loadLoginStatus());
      return;
    }
    setState(() => _selectedIndex = idx);
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
    // กลับจากหน้าล็อกอินหรือหน้ารายละเอียด
    _loadLoginStatus();
    _loadData();
  }

  @override
  void didPush() {
    // เข้าหน้านี้ใหม่
    _loadLoginStatus();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F2),
      body: Column(
        children: [
          _buildCustomAppBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIngredientSection(),
                  const SizedBox(height: 32),
                  _buildRecipeSection('สูตรอาหารยอดนิยม', _futurePopular),
                  const SizedBox(height: 32),
                  _buildRecipeSection('สูตรอาหารอัปเดตใหม่', _futureNew),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: _selectedIndex,
        isLoggedIn: _isLoggedIn,
        onItemSelected: _onNavTap,
      ),
    );
  }

  /// AppBar ที่มีโปรไฟล์ + ปุ่ม login/logout
  PreferredSizeWidget _buildCustomAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(79),
      child: Container(
        height: 79,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            bottom: BorderSide(color: Color(0xFFE1E1E1), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(0, 3),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey[300],
              backgroundImage:
                  (_isLoggedIn && _profileImage?.isNotEmpty == true)
                      ? NetworkImage(_profileImage!)
                      : const AssetImage('lib/assets/images/default_avatar.png')
                          as ImageProvider,
              child: (!_isLoggedIn || _profileImage?.isEmpty == true)
                  ? const Icon(Icons.person, color: Colors.white, size: 20)
                  : null,
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
              iconSize: 32,
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                if (_isLoggedIn) {
                  await prefs.clear(); // ✅ ล้างทั้งหมด

                  setState(() {
                    _isLoggedIn = false;
                    _profileName = null;
                    _profileImage = null;
                  });
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ).then((_) => _loadLoginStatus());
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientSection() {
    return Container(
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
            onAction: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllIngredientsScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            switchInCurve: Curves.easeIn,
            switchOutCurve: Curves.easeOut,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: SizedBox(
              key: ValueKey(_futureIngredients),
              height: 136,
              child: FutureBuilder<List<Ingredient>>(
                future: _futureIngredients,
                builder: (ctx, snap) {
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
                    itemBuilder: (ctx, i) => IngredientCard(
                      ingredient: list[i],
                      onTap: () {},
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeSection(String title, Future<List<Recipe>> future) {
    return Column(
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
          onAction: () {},
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          switchInCurve: Curves.easeIn,
          switchOutCurve: Curves.easeOut,
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: SizedBox(
            key: ValueKey(future),
            height: 200,
            child: FutureBuilder<List<Recipe>>(
              future: future,
              builder: (ctx, snap) {
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
                  itemBuilder: (ctx, i) => RecipeCard(
                    recipe: list[i],
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/recipe_detail',
                      arguments: list[i],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String actionText,
    TextStyle? actionStyle,
    required VoidCallback onAction,
  }) {
    return Padding(
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
            child: Text(
              actionText,
              style: actionStyle ??
                  const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A2533),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
