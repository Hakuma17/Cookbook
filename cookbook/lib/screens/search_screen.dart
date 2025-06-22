import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/recipe_card.dart';
import '../widgets/custom_search_bar.dart';
import '../widgets/custom_bottom_nav.dart';
import '../utils/debouncer.dart';

class SearchScreen extends StatefulWidget {
  final List<String>? ingredients;
  const SearchScreen({super.key, this.ingredients});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  /* ──────────────────────  local state  ───────────────────── */
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 400));

  List<Recipe> _results = [];
  bool _loading = false;
  String _error = '';
  String _searchQuery = '';
  int _selectedChip = 0; // filter chip index

  /* bottom-nav */
  int _selectedIndex = 1; // 0=Home,1=Search,2=MyRecipes,3=Profile
  bool _isLoggedIn = false;

  static const _filter = [
    ('อาหารยอดนิยม', 'popular'),
    ('กำลังมาแรง', 'trending'),
    ('ล่าสุด', 'latest'),
    ('เมนูแนะนำ', 'recommended'),
  ];

  /* ──────────────────────  init/dispose  ──────────────────── */
  @override
  void initState() {
    super.initState();
    _refreshLoginStatus();

    // ถ้ามาจาก ingredients list ให้ค้นหาอัตโนมัติ
    if (widget.ingredients?.isNotEmpty ?? false) {
      _performIngredientSearch(widget.ingredients!);
    }
  }

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> _refreshLoginStatus() async {
    final ok = await AuthService.isLoggedIn();
    if (mounted) setState(() => _isLoggedIn = ok);
  }

  /* ──────────────────────  search helpers  ─────────────────── */
  void _onTextChanged(String q) => _debouncer(() => _performSearch(q));

  Future<void> _performSearch(String q) async {
    if (q.trim().length < 2) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _error = 'ใส่คำค้นอย่างน้อย 2 ตัวอักษร';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _searchQuery = q;
      _loading = true;
      _error = '';
    });

    try {
      final (_, sortKey) = _filter[_selectedChip];
      final list = await ApiService.searchRecipes(query: q, sort: sortKey)
          .timeout(const Duration(seconds: 10));

      if (mounted) setState(() => _results = list);
    } on TimeoutException {
      if (mounted) setState(() => _error = 'เซิร์ฟเวอร์ตอบช้า ลองใหม่ภายหลัง');
    } on SocketException {
      if (mounted) setState(() => _error = 'ไม่มีการเชื่อมต่ออินเทอร์เน็ต');
    } catch (e) {
      if (mounted) setState(() => _error = 'เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _performIngredientSearch(List<String> names) async {
    if (!mounted) return;
    setState(() {
      _searchQuery = names.join(', ');
      _loading = true;
      _error = '';
    });

    try {
      final list = await ApiService.searchRecipesByIngredientNames(names)
          .timeout(const Duration(seconds: 10));

      if (mounted) setState(() => _results = list);
    } on TimeoutException {
      if (mounted) setState(() => _error = 'เซิร์ฟเวอร์ตอบช้า ลองใหม่ภายหลัง');
    } on SocketException {
      if (mounted) setState(() => _error = 'ไม่มีการเชื่อมต่ออินเทอร์เน็ต');
    } catch (e) {
      if (mounted) setState(() => _error = 'เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /* ──────────────────────  UI pieces  ─────────────────────── */
  Widget _buildFilterChips() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: List.generate(_filter.length, (i) {
            final selected = i == _selectedChip;
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ChoiceChip(
                label: Text(
                  _filter[i].$1,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                selected: selected,
                selectedColor: const Color(0xFFFF9B05),
                backgroundColor: const Color(0xFFF2F2F2),
                onSelected: (_) {
                  if (selected) return;
                  setState(() => _selectedChip = i);
                  if (_searchQuery.isNotEmpty && widget.ingredients == null) {
                    _performSearch(_searchQuery); // re-query
                  }
                },
              ),
            );
          }),
        ),
      );

  Widget _buildResultArea() {
    if (_loading) return const SizedBox.shrink();

    if (_results.isEmpty) {
      return Center(
        child: Text(
          _error.isNotEmpty ? '' : 'ลองค้นหาสูตรดูสิ',
          style: const TextStyle(fontSize: 15, color: Colors.grey),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.6,
      ),
      itemCount: _results.length,
      itemBuilder: (_, i) => RecipeCard(
        recipe: _results[i],
        onTap: () => Navigator.pushNamed(context, '/recipe_detail',
            arguments: _results[i]),
        expanded: true,
      ),
    );
  }

  /* ──────────────────────  bottom-nav  ───────────────────── */
  Future<void> _onBottomNav(int idx) async {
    if (idx == 2 || idx == 3) {
      if (!await AuthService.checkAndRedirectIfLoggedOut(context)) return;
    }
    if (idx == _selectedIndex) return; // แตะซ้ำไม่ต้องทำอะไร
    setState(() => _selectedIndex = idx);

    switch (idx) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        /* already here */ break;
      case 2:
        Navigator.pushReplacementNamed(context, '/my_recipes');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

  /* ──────────────────────  build  ────────────────────────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ค้นหาสูตรอาหาร')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.ingredients == null)
            CustomSearchBar(
              onChanged: _onTextChanged,
              onSubmitted: _performSearch,
            ),
          if (_searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('ผลค้นหาสูตร “$_searchQuery”',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          _buildFilterChips(),
          if (_loading) const LinearProgressIndicator(),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child:
                  Text(_error, style: const TextStyle(color: Colors.redAccent)),
            ),
          Expanded(child: _buildResultArea()),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: _selectedIndex,
        isLoggedIn: _isLoggedIn,
        onItemSelected: _onBottomNav,
      ),
    );
  }
}
