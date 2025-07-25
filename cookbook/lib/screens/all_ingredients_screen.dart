// lib/screens/all_ingredients_screen.dart
// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'package:flutter/material.dart';

import '../models/ingredient.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/ingredient_card.dart';
import '../widgets/custom_bottom_nav.dart';
import 'search_screen.dart';

class AllIngredientsScreen extends StatefulWidget {
  final bool selectionMode;
  final void Function(Ingredient)? onSelected;

  const AllIngredientsScreen({
    super.key,
    this.selectionMode = false,
    this.onSelected,
  });

  @override
  State<AllIngredientsScreen> createState() => _AllIngredientsScreenState();
}

class _AllIngredientsScreenState extends State<AllIngredientsScreen> {
  /* ─── state ───────────────────────────────────────────── */
  late Future<void> _initFuture;
  List<Ingredient> _all = [];
  List<Ingredient> _filtered = [];

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  // ★ 1. เพิ่ม State สำหรับเก็บสถานะการล็อกอิน
  bool _isLoggedIn = false;
  String? _username, _profileImg;

  @override
  void initState() {
    super.initState();
    _initFuture = _initialize();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /* ─── data loaders ───────────────────────────────────── */
  Future<void> _initialize() async {
    await Future.wait([
      _loadUserInfo(),
      _loadIngredients(),
    ]);
  }

  Future<void> _loadUserInfo() async {
    // ★ 2. ดึงสถานะ isLoggedIn มาพร้อมกับข้อมูล User
    _isLoggedIn = await AuthService.isLoggedIn();
    _username = await AuthService.getProfileName();
    _profileImg = await AuthService.getProfileImage();
    if (mounted) setState(() {});
  }

  Future<void> _loadIngredients() async {
    try {
      final list = await ApiService.fetchIngredients();
      if (!mounted) return;

      setState(() {
        _all = list;
        _filtered = _applyFilter(list, _searchCtrl.text);
      });
    } on UnauthorizedException {
      _logout();
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('เกิดข้อผิดพลาดที่ไม่รู้จัก: $e');
    }
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

  /* ─── bottom-nav & actions ───────────────────────────── */
  Future<void> _logout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  // ★ 3. [แก้ไข] ปรับปรุง Logic การนำทางให้รองรับ Profile/Settings
  void _onTabSelected(int idx) {
    // index 1 คือหน้าปัจจุบัน (All Ingredients ถือเป็นส่วนหนึ่งของ Explore/Search)
    if (idx == 1) return;

    switch (idx) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/my_recipes');
        break;
      case 3:
        // ตรวจสอบสถานะ แล้วนำทางไปยังหน้าที่ถูกต้อง
        final route = _isLoggedIn ? '/profile' : '/settings';
        Navigator.pushReplacementNamed(context, route);
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      // ★ 4. [แก้ไข] ส่งค่า `isLoggedIn` เข้าไปใน CustomBottomNav
      bottomNavigationBar: widget.selectionMode
          ? null
          : CustomBottomNav(
              selectedIndex: 1, // Explore/Search tab
              onItemSelected: _onTabSelected,
              isLoggedIn: _isLoggedIn,
            ),
      body: SafeArea(
        child: Column(
          children: [
            /* ─── header bar ─── */
            _HeaderBar(
              username: _username,
              profileImg: _profileImg,
              selectionMode: widget.selectionMode,
              onActionPressed:
                  widget.selectionMode ? () => Navigator.pop(context) : _logout,
            ),
            /* ─── search box ─── */
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText: 'คุณอยากหาวัตถุดิบอะไร?',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
            /* ─── grid list ─── */
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

  /* ─── grid builder ───────────────────────────────────── */
  Widget _buildGrid() {
    return FutureBuilder(
      future: _initFuture,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('เกิดข้อผิดพลาดในการโหลด: ${snap.error}'));
        }
        if (_all.isEmpty) {
          return const Center(child: Text('ไม่พบข้อมูลวัตถุดิบ'));
        }
        if (_searchCtrl.text.isNotEmpty && _filtered.isEmpty) {
          return const Center(child: Text('ไม่พบวัตถุดิบที่ค้นหา'));
        }

        return LayoutBuilder(builder: (_, cs) {
          const minW = 95.0;
          final cols = (cs.maxWidth / minW).floor().clamp(2, 6);

          return GridView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: _filtered.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemBuilder: (_, i) {
              final ing = _filtered[i];
              return IngredientCard(
                ingredient: ing,
                onTap: () {
                  if (widget.selectionMode) {
                    widget.onSelected?.call(ing);
                    Navigator.pop(context, ing);
                  } else {
                    // เมื่อกดที่วัตถุดิบ ให้ไปหน้าค้นหาพร้อมกับเลือกวัตถุดิบนั้นๆ
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

/*──────────────────── header bar (refactored) ───────────────────*/
class _HeaderBar extends StatelessWidget {
  final String? username, profileImg;
  final bool selectionMode;
  final VoidCallback onActionPressed;

  const _HeaderBar({
    required this.username,
    required this.profileImg,
    required this.selectionMode,
    required this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final provider = (profileImg != null && profileImg!.isNotEmpty)
        ? NetworkImage(profileImg!)
        : const AssetImage('assets/images/default_avatar.png') as ImageProvider;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
        color: theme.colorScheme.surface,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: theme.colorScheme.surfaceVariant,
            backgroundImage: provider,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'สวัสดี ${username ?? 'คุณ'}',
              style:
                  textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(selectionMode ? Icons.close : Icons.logout_outlined),
            color: theme.colorScheme.onSurfaceVariant,
            onPressed: onActionPressed,
          ),
        ],
      ),
    );
  }
}
