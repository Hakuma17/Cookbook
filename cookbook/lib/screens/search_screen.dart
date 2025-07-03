// lib/screens/search_screen.dart
// ─────────────────────────────────────────────────────────────
// Search Screen (rev. add "?" help icon – 2025-07-03)
//
// • เพิ่มไอคอนคู่มือ (?) ใน SliverAppBar → BottomSheet อธิบาย ranking
// • แก้ให้ส่ง `q=` ไปแบ็กเอนด์เสมอ (เลิกโยน keyword ไปเป็น ingredient filter)
// • ป้องกัน “response เก่าทับใหม่” ด้วย _reqId
// • ใช้ _searchQuery (แยกตามช่องวรรค/คอมมา) ทำ highlight
// ─────────────────────────────────────────────────────────────

// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/debouncer.dart';
import '../widgets/search_recipe_card.dart';
import '../widgets/custom_search_bar.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/hero_carousel.dart';
import '../widgets/choice_chip_filter.dart';
import 'ingredient_filter_screen.dart';

class SearchScreen extends StatefulWidget {
  final List<String>? ingredients; // include names (จาก IngredientFilter)
  final List<String>? excludeIngredients; // exclude ids (จาก IngredientFilter)

  const SearchScreen({
    super.key,
    this.ingredients,
    this.excludeIngredients,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  /* ───────────── constants ───────────── */
  static const _pageSize = 26;
  static const List<FilterOption> _sortOptions = [
    FilterOption('ยอดนิยม', 'popular'),
    FilterOption('มาแรง', 'trending'),
    FilterOption('ล่าสุด', 'latest'),
    FilterOption('แนะนำ', 'recommended'),
  ];

  /* ───────────── controllers ─────────── */
  final _scrollCtl = ScrollController();
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 400));

  /* ───────────── state ──────────────── */
  List<Recipe> _gridRecipes = [];
  List<Recipe> _heroRecipes = [];

  List<String> _includeNames = []; // ใช้เฉพาะจาก filter screen
  List<String> _excludeIds = [];

  String _searchQuery = '';
  String _error = '';

  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  int _sortIndex = 2; // “ล่าสุด”

  int _navIndex = 1;
  bool _isLoggedIn = false;

  int _reqId = 0; // ป้องกัน response เก่าทับใหม่

  /* ───────────── lifecycle ──────────── */
  @override
  void initState() {
    super.initState();
    _refreshLoginStatus();

    _includeNames = [...?widget.ingredients];
    _excludeIds = [...?widget.excludeIngredients];

    _scrollCtl.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollCtl.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  /* ───────────── networking ─────────── */
  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    try {
      _gridRecipes.clear();
      _heroRecipes.clear();
      _page = 1;
      _hasMore = true;
      await _fetchPage(1, ++_reqId);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshLoginStatus() async {
    final ok = await AuthService.isLoggedIn();
    if (mounted) setState(() => _isLoggedIn = ok);
  }

  void _onSearchChanged(String txt) => _debouncer(() => _performSearch(txt));

  Future<void> _performSearch(String raw) async {
    setState(() {
      _searchQuery = raw.trim();
      _gridRecipes.clear();
      _heroRecipes.clear();
      _page = 1;
      _hasMore = true;
      _loading = true;
      _error = '';
    });

    await _fetchPage(1, ++_reqId);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchPage(int page, int myId) async {
    if (!mounted) return;
    setState(() => _loadingMore = page > 1);

    try {
      final recipes = await ApiService.searchRecipes(
        query: _searchQuery,
        page: page,
        limit: _pageSize,
        sort: _sortOptions[_sortIndex].key,
        ingredientNames: _includeNames, // (backend R3 ยังเพิกเฉย)
        excludeIngredientIds:
            _excludeIds.map(int.tryParse).whereType<int>().toList(),
      );

      if (myId != _reqId || !mounted) return; // stale response → ทิ้ง

      setState(() {
        _page = page;
        _heroRecipes = recipes.take(3).toList();
        _gridRecipes = page == 1 ? recipes : [..._gridRecipes, ...recipes];
        _hasMore = recipes.length == _pageSize;
      });
    } on TimeoutException {
      _showError('เซิร์ฟเวอร์ตอบช้า ลองใหม่ภายหลัง');
    } on SocketException {
      _showError('ไม่มีการเชื่อมต่ออินเทอร์เน็ต');
    } catch (e) {
      _showError('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() => _error = msg);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /* ───────────── scroll listener ─────── */
  void _onScroll() {
    if (_scrollCtl.position.pixels >
            _scrollCtl.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _fetchPage(_page + 1, ++_reqId);
    }
  }

  /* ───────────── help bottom-sheet ───── */
  void _showSearchHelp() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('วิธีการจัดอันดับผลค้นหา',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                )),
            const SizedBox(height: 12),
            _bullet('1) ชื่อตรง 100% จะมาก่อนสุด'),
            _bullet('2) ถ้าไม่มีชื่อตรง → สูตรที่มีวัตถุดิบครบทุกคำค้น'),
            _bullet('3) มีบางวัตถุดิบ (≥1 คำ) จะตามมาถัดไป'),
            _bullet('4) แยกคำได้ด้วยเว้นวรรค คอมมา หรือ ;'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('เข้าใจแล้ว'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bullet(String txt) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: Text(txt, style: const TextStyle(fontSize: 14)),
          ),
        ],
      );

  /* ───────────── UI helpers ─────────── */
  Widget _resultHeading() {
    if (_searchQuery.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        'ผลค้นหาสูตร “$_searchQuery”',
        style: const TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: Color(0xFF0A2533),
        ),
      ),
    );
  }

  Widget _buildHero() {
    if (_heroRecipes.isEmpty) return const SizedBox.shrink();
    return HeroCarousel(
      recipes: _heroRecipes,
      itemSize: 110,
      highlightTerms: _searchQuery.split(RegExp(r'[ ,;]')),
      onTap: (r) =>
          Navigator.pushNamed(context, '/recipe_detail', arguments: r),
    );
  }

  Widget _buildGrid() {
    if (_loading && _gridRecipes.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_gridRecipes.isEmpty) {
      return SliverFillRemaining(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('ไม่พบสูตรอาหารที่ต้องการ',
                style: TextStyle(fontFamily: 'Roboto', color: Colors.grey)),
            SizedBox(height: 24),
            Icon(Icons.sentiment_dissatisfied, size: 48, color: Colors.grey),
          ],
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
          childAspectRatio: 0.56,
        ),
        delegate: SliverChildBuilderDelegate(
          (ctx, index) {
            if (index == _gridRecipes.length) {
              return const Center(child: CircularProgressIndicator());
            }
            return SearchRecipeCard(
              recipe: _gridRecipes[index],
              rankOverride: _sortIndex == 0 ? index + 1 : null,
              highlightTerms: _searchQuery.split(RegExp(r'[ ,;]')),
              onTap: () => Navigator.pushNamed(
                context,
                '/recipe_detail',
                arguments: _gridRecipes[index],
              ),
            );
          },
          childCount: _gridRecipes.length + (_hasMore ? 1 : 0),
        ),
      ),
    );
  }

  /* ───────────── build ─────────────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollCtl,
        slivers: [
          SliverAppBar(
            pinned: true,
            centerTitle: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: const BackButton(color: Colors.black),
            title: const Text(
              'Search',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline, color: Colors.black),
                tooltip: 'หลักการค้นหา',
                onPressed: _showSearchHelp,
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(72),
              child: CustomSearchBar(
                onChanged: _onSearchChanged,
                onSubmitted: _performSearch,
                onFilterTap: () async {
                  final res = await Navigator.push<List<List<String>>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const IngredientFilterScreen(),
                    ),
                  );
                  if (res != null) {
                    _includeNames = res[0];
                    _excludeIds = res[1];
                    _performSearch(_searchQuery);
                  }
                },
                hasActiveFilter:
                    _includeNames.isNotEmpty || _excludeIds.isNotEmpty,
              ),
            ),
          ),
          SliverToBoxAdapter(child: _resultHeading()),
          SliverToBoxAdapter(child: _buildHero()),
          SliverToBoxAdapter(
            child: ChoiceChipFilter(
              options: _sortOptions,
              initialIndex: _sortIndex,
              onChanged: (idx, key) {
                setState(() => _sortIndex = idx);
                _performSearch(_searchQuery);
              },
            ),
          ),
          _buildGrid(),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: _navIndex,
        isLoggedIn: _isLoggedIn,
        onItemSelected: (i) async {
          if ((i == 2 || i == 3) &&
              !await AuthService.checkAndRedirectIfLoggedOut(context)) {
            return;
          }
          if (i == _navIndex) return;

          setState(() => _navIndex = i);
          switch (i) {
            case 0:
              Navigator.pushReplacementNamed(context, '/home');
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/my_recipes');
              break;
            case 3:
              Navigator.pushReplacementNamed(context, '/profile');
              break;
          }
        },
      ),
    );
  }
}
