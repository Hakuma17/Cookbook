// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _HomeScreenState extends State<HomeScreen> {
  // เก็บ Future สำหรับดึงข้อมูลจาก API
  late Future<List<Ingredient>> _futureIngredients;
  late Future<List<Recipe>> _futurePopular;
  late Future<List<Recipe>> _futureNew;

  // สถานะผู้ใช้
  bool _isLoggedIn = false;
  String? _profileName;
  String? _profileImage;
  int _selectedIndex = 0; // ดัชนีเมนูด้านล่าง

  @override
  void initState() {
    super.initState();
    _loadLoginStatus(); // โหลดสถานะล็อกอิน
    _futureIngredients = ApiService.fetchIngredients(); // API วัตถุดิบ
    _futurePopular = ApiService.fetchPopularRecipes(); // API สูตรยอดนิยม
    _futureNew = ApiService.fetchNewRecipes(); // API สูตรใหม่
  }

  /// โหลดสถานะจาก SharedPreferences (isLoggedIn, profileName, profileImage)
  Future<void> _loadLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      _profileName = prefs.getString('profileName');
      _profileImage = prefs.getString('profileImage');
    });
  }

  /// เมื่อกดแท็บเมนูล่าง
  void _onNavTap(int idx) {
    if ((idx == 2 || idx == 3) && !_isLoggedIn) {
      // ถ้าไม่ล็อกอินแล้วกดเมนูสูตรหรือฉัน → ไปหน้า Login
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      ).then((_) => _loadLoginStatus());
      return;
    }
    setState(() => _selectedIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // พื้นหลังทั้งหน้าสีอ่อนตามดีไซน์
      backgroundColor: const Color(0xFFFDF7F2),
      body: Column(
        children: [
          _buildCustomAppBar(), // AppBar กำหนดเอง
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIngredientSection(), // Section วัตถุดิบ
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

      // ─── Custom Bottom Navigation ─────────────────────
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
            // รูปโปรไฟล์
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey[300],
              backgroundImage: (_profileImage?.isNotEmpty ?? false)
                  ? NetworkImage(_profileImage!)
                  : AssetImage('lib/assets/images/default_avatar.png')
                      as ImageProvider,
              child: (_profileImage?.isEmpty ?? true)
                  ? const Icon(Icons.person, color: Colors.white, size: 20)
                  : null,
            ),
            const SizedBox(width: 12),

            // ข้อความต้อนรับ
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

            // ปุ่ม login/logout
            IconButton(
              icon: Icon(_isLoggedIn ? Icons.logout : Icons.login_rounded),
              color: const Color(0xFF666666),
              iconSize: 32,
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                if (_isLoggedIn) {
                  // ลบข้อมูลสถานะการล็อกอิน
                  await prefs.remove('isLoggedIn');
                  await prefs.remove('profileName');
                  await prefs.remove('profileImage');
                  setState(() => _isLoggedIn = false);
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

  /// Section: วัตถุดิบ (แนวนอน)
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
          SizedBox(
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
        ],
      ),
    );
  }

  /// Section: สูตรอาหาร (ยอดนิยม / ใหม่)
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
        SizedBox(
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
      ],
    );
  }

  /// Header ของแต่ละหมวด (เช่น "วัตถุดิบ", "สูตรยอดนิยม")
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
