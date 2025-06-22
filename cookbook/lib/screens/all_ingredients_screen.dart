// lib/screens/all_ingredients_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ingredient.dart';
import '../services/api_service.dart';
import '../widgets/ingredient_card.dart';
import '../widgets/custom_bottom_nav.dart';
import 'home_screen.dart';
import 'my_recipes_screen.dart';
import 'profile_screen.dart';

class AllIngredientsScreen extends StatefulWidget {
  const AllIngredientsScreen({Key? key}) : super(key: key);

  @override
  State<AllIngredientsScreen> createState() => _AllIngredientsScreenState();
}

class _AllIngredientsScreenState extends State<AllIngredientsScreen> {
  /* ─── state ───────────────────────────────────────────── */
  late Future<List<Ingredient>> _futureIngredients;

  List<Ingredient> _all = [];
  List<Ingredient> _filtered = [];

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce; // 💡 debounce
  bool _loadingUser = true;

  int _selectedIndex = 1; // Explore tab
  String? _username;
  String? _profileImage;

  /* ─── init / dispose ─────────────────────────────────── */
  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadIngredients();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /* ─── data loaders ───────────────────────────────────── */
  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _username = prefs.getString('profileName') ?? 'ผู้ใช้';
      _profileImage = prefs.getString('profileImage');
      _loadingUser = false;
    });
  }

  void _loadIngredients() {
    _futureIngredients = _fetchIngredientsSafe();
  }

  Future<List<Ingredient>> _fetchIngredientsSafe() async {
    try {
      final list = await ApiService.fetchIngredients()
          .timeout(const Duration(seconds: 10)); // 💡 timeout
      _all = list;
      _filtered = _applyFilter(list, _searchCtrl.text);
      return list;
    } on TimeoutException {
      _showSnack('เซิร์ฟเวอร์ไม่ตอบสนอง');
    } on SocketException {
      _showSnack('ไม่มีการเชื่อมต่ออินเทอร์เน็ต');
    } catch (e) {
      _showSnack('เกิดข้อผิดพลาด: $e');
    }
    return []; // fallback
  }

  /* ─── search ─────────────────────────────────────────── */
  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _filtered = _applyFilter(_all, _searchCtrl.text);
      });
    });
  }

  List<Ingredient> _applyFilter(List<Ingredient> src, String q) {
    if (q.trim().isEmpty) return List.from(src);
    final lower = q.toLowerCase();
    return src.where((i) => i.name.toLowerCase().contains(lower)).toList();
  }

  /* ─── bottom-nav ─────────────────────────────────────── */
  void _onTabSelected(int idx) {
    if (idx == _selectedIndex) return;

    setState(() => _selectedIndex = idx);
    switch (idx) {
      case 0:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        break;
      case 1:
        break; // already here
      case 2:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const MyRecipesScreen()));
        break;
      case 3:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
        break;
    }
  }

  /* ─── helpers ────────────────────────────────────────── */
  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /* ─── build ──────────────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: _selectedIndex,
        onItemSelected: _onTabSelected,
        isLoggedIn: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeaderBar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'คุณอยากหาวัตถุดิบอะไร?',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildGrid(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBar() {
    final imgProvider = (_profileImage?.isNotEmpty ?? false)
        ? NetworkImage(_profileImage!)
        : const AssetImage('assets/images/profile.jpg') as ImageProvider;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFE1E1E1))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.grey[300],
            backgroundImage: imgProvider,
            child: (_profileImage?.isEmpty ?? true)
                ? const Icon(Icons.person, color: Colors.white, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'สวัสดี ${_username ?? ''}',
              style:
                  const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF666666)),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (_) => false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return FutureBuilder<List<Ingredient>>(
      future: _futureIngredients,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_filtered.isEmpty) {
          return const Center(child: Text('ไม่พบวัตถุดิบ'));
        }
        return GridView.builder(
          itemCount: _filtered.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (_, i) => IngredientCard(ingredient: _filtered[i]),
        );
      },
    );
  }
}
