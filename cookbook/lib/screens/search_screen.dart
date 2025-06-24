// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:cookbook/screens/ingredient_filter_screen.dart';
import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/recipe_card.dart';
import '../widgets/custom_search_bar.dart';
import '../widgets/custom_bottom_nav.dart';
import '../utils/debouncer.dart';

class SearchScreen extends StatefulWidget {
  final List<String>? ingredients; // include
  final List<String>? excludeIngredients; // exclude

  const SearchScreen({
    super.key,
    this.ingredients,
    this.excludeIngredients,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 400));

  List<Recipe> _results = [];
  bool _loading = false;
  String _error = '';
  String _searchQuery = '';
  int _selectedChip = 0;
  List<String> _includeIds = [];
  List<String> _excludeIds = [];

  int _selectedIndex = 1;
  bool _isLoggedIn = false;

  static const _filter = [
    ('อาหารยอดนิยม', 'popular'),
    ('กำลังมาแรง', 'trending'),
    ('ล่าสุด', 'latest'),
    ('เมนูแนะนำ', 'recommended'),
  ];

  @override
  void initState() {
    super.initState();
    _refreshLoginStatus();

    if (widget.excludeIngredients?.isNotEmpty ?? false) {
      _excludeIds = List.from(widget.excludeIngredients!);
    }

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
      final list = await ApiService.searchRecipes(
        query: q,
        sort: sortKey,
        includeIngredientIds: _includeIds.map(int.parse).toList(),
        excludeIngredientIds: _excludeIds.map(int.parse).toList(),
      ).timeout(const Duration(seconds: 10));

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

  Future<void> _openFilter() async {
    final lists = await Navigator.push<List<List<String>>>(
      context,
      MaterialPageRoute(builder: (_) => const IngredientFilterScreen()),
    );
    if (lists == null) return;

    setState(() {
      _includeIds = lists[0];
      _excludeIds = lists[1];
    });

    if (_includeIds.isNotEmpty || _excludeIds.isNotEmpty) {
      _performSearch(_searchQuery.isEmpty ? ' ' : _searchQuery);
    }
  }

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
                    _performSearch(_searchQuery);
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

  Future<void> _onBottomNav(int idx) async {
    if (idx == 2 || idx == 3) {
      if (!await AuthService.checkAndRedirectIfLoggedOut(context)) return;
    }
    if (idx == _selectedIndex) return;
    setState(() => _selectedIndex = idx);

    switch (idx) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/my_recipes');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

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
              onFilterTap: _openFilter,
              hasActiveFilter: _includeIds.isNotEmpty || _excludeIds.isNotEmpty,
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
