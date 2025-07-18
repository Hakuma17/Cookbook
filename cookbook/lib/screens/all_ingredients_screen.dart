// lib/screens/all_ingredients_screen.dart
// ignore_for_file: use_build_context_synchronously
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
import 'search_screen.dart';

class AllIngredientsScreen extends StatefulWidget {
  /// ★ ถ้า true จะเป็นโหมดเลือก (Selection),
  ///    ไม่กระโดดไป Search แต่เรียก `onSelected`
  final bool selectionMode;

  /// ★ Callback เมื่อเลือก Ingredient (ใช้ในโหมดเลือก)
  final void Function(Ingredient)? onSelected;

  const AllIngredientsScreen({
    Key? key,
    this.selectionMode = false,
    this.onSelected,
  }) : super(key: key);

  @override
  State<AllIngredientsScreen> createState() => _AllIngredientsScreenState();
}

class _AllIngredientsScreenState extends State<AllIngredientsScreen> {
  /* ─── state ───────────────────────────────────────────── */
  late Future<List<Ingredient>> _futureIngredients;
  List<Ingredient> _all = [];
  List<Ingredient> _filtered = [];

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  int _selectedIndex = 1; // Explore tab
  String? _username, _profileImg;

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
      _profileImg = prefs.getString('profileImage');
    });
  }

  void _loadIngredients() {
    _futureIngredients = _fetchIngredientsSafe();
  }

  Future<List<Ingredient>> _fetchIngredientsSafe() async {
    try {
      final list = await ApiService.fetchIngredients()
          .timeout(const Duration(seconds: 10));
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
    return [];
  }

  /* ─── search ─────────────────────────────────────────── */
  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _filtered = _applyFilter(_all, _searchCtrl.text));
    });
  }

  List<Ingredient> _applyFilter(List<Ingredient> src, String q) {
    final clean = src.where((e) => e.name.trim().isNotEmpty).toList();
    if (q.trim().isEmpty) return clean;
    final lower = q.toLowerCase();
    return clean.where((i) => i.name.toLowerCase().contains(lower)).toList();
  }

  /* ─── bottom-nav ─────────────────────────────────────── */
  void _onTabSelected(int idx) {
    if (idx == _selectedIndex) return;
    setState(() => _selectedIndex = idx);

    switch (idx) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
        break;
      case 1:
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyRecipesScreen()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );
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
    // responsive helpers
    final size = MediaQuery.of(context).size;
    double clamp(double v, double min, double max) =>
        v < min ? min : (v > max ? max : v);

    // dynamic paddings / font
    final padH = clamp(size.width * .045, 14, 24);
    final padTop = clamp(size.height * .016, 12, 20);
    final searchV = clamp(size.height * .012, 10, 18);
    final avatarR = clamp(size.width * .06, 20, 28);
    final fontH = clamp(size.width * .048, 16, 22);
    final iconSz = avatarR; // ให้ไอคอน ~ เท่า avatar เสมอ

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: widget.selectionMode
          ? null
          : CustomBottomNav(
              selectedIndex: _selectedIndex,
              onItemSelected: _onTabSelected,
              isLoggedIn: true,
            ),
      body: SafeArea(
        child: Column(
          children: [
            /* ─── header bar ─── */
            _HeaderBar(
              avatarR: avatarR,
              iconSz: iconSz,
              padH: padH,
              padV: padTop,
              fontSz: fontH,
              username: _username,
              profileImg: _profileImg,
              selectionMode: widget.selectionMode,
            ),

            /* ─── search box ─── */
            Padding(
              padding: EdgeInsets.fromLTRB(padH, searchV, padH, 0),
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
            SizedBox(height: clamp(size.height * .012, 8, 14)),

            /* ─── grid list ─── */
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: padH),
                child: _buildGrid(clamp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ─── grid builder ───────────────────────────────────── */
  Widget _buildGrid(double Function(double, double, double) clamp) {
    return FutureBuilder<List<Ingredient>>(
      future: _futureIngredients,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_filtered.isEmpty) {
          return const Center(child: Text('ไม่พบวัตถุดิบ'));
        }

        // คำนวณจำนวนคอลัมน์ตามขนาดหน้าจอ
        return LayoutBuilder(builder: (_, cs) {
          const minW = 95.0;
          final cols = (cs.maxWidth / minW).floor().clamp(2, 6);
          final itemW = cs.maxWidth / cols;
          final itemH = itemW * 1.35;

          return GridView.builder(
            itemCount: _filtered.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: clamp(itemH * .12, 12, 20),
              crossAxisSpacing: clamp(itemW * .08, 8, 16),
              childAspectRatio: itemW / itemH,
            ),
            itemBuilder: (_, i) {
              final ing = _filtered[i];
              return IngredientCard(
                ingredient: ing,
                width: itemW,
                height: itemH,
                onTap: () {
                  if (widget.selectionMode) {
                    widget.onSelected?.call(ing);
                    Navigator.pop(context, ing);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SearchScreen(ingredients: [ing.name]),
                      ),
                    );
                  }
                },
              );
            },
          );
        });
      },
    );
  }
}

/*──────────────────── header bar (extract) ───────────────────*/
class _HeaderBar extends StatelessWidget {
  final double padH, padV, avatarR, iconSz, fontSz;
  final String? username, profileImg;
  final bool selectionMode;

  const _HeaderBar({
    required this.padH,
    required this.padV,
    required this.avatarR,
    required this.iconSz,
    required this.fontSz,
    required this.username,
    required this.profileImg,
    required this.selectionMode,
  });

  @override
  Widget build(BuildContext context) {
    final provider = (profileImg?.isNotEmpty ?? false)
        ? NetworkImage(profileImg!)
        : const AssetImage('assets/images/default_avatar.png') as ImageProvider;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE1E1E1))),
        color: Colors.white,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: avatarR,
            backgroundColor: Colors.grey[300],
            backgroundImage: provider,
          ),
          SizedBox(width: padH * .7),
          Expanded(
            child: Text(
              'สวัสดี ${username ?? ''}',
              style: TextStyle(fontSize: fontSz, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: Icon(
              selectionMode ? Icons.close : Icons.logout,
              color: const Color(0xFF666666),
            ),
            iconSize: iconSz,
            onPressed: selectionMode
                ? () => Navigator.pop(context)
                : () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(
                          context, '/login', (_) => false);
                    }
                  },
          ),
        ],
      ),
    );
  }
}
