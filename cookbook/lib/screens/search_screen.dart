// lib/screens/search_screen.dart
//  ⟵ “---” = บรรทัดที่แก้/เพิ่มให้ใช้ฟอนต์และสไตล์เดียวกับหน้า Home

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
  final List<String>? ingredients;
  final List<String>? excludeIngredients;

  const SearchScreen({super.key, this.ingredients, this.excludeIngredients});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
/* ───────────────────────── constants ───────────────────────── */
  static const _pageSize = 26;
  static const List<FilterOption> _sortOptions = [
    FilterOption('ยอดนิยม', 'popular'),
    FilterOption('มาแรง', 'trending'),
    FilterOption('ล่าสุด', 'latest'),
    FilterOption('แนะนำ', 'recommended'),
  ];

/* ─────────────────── controllers / helpers ────────────────── */
  final _scrollCtl = ScrollController();
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 400));

/* ─────────────────────────── state ────────────────────────── */
  List<Recipe> _gridRecipes = [];
  List<Recipe> _heroRecipes = [];

  List<String> _includeNames = [];
  List<String> _excludeIds = [];

  String _searchQuery = '';
  String _error = '';

  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  int _sortIndex = 2; // “ล่าสุด”

  // bottom-nav
  int _navIndex = 1;
  bool _isLoggedIn = false;

/* ───────────────────────── lifecycle ──────────────────────── */
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

/* ─────────────── initial feed + auth helpers ─────────────── */
  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    try {
      final pop = await ApiService.fetchPopularRecipes();
      _heroRecipes = pop.take(3).toList();
      _gridRecipes.clear();
      _page = 1;
      _hasMore = true;
      await _fetchPage(1);
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

/* ───────────────────────── search helpers ─────────────────── */
  void _onSearchChanged(String txt) => _debouncer(() => _performSearch(txt));

  Future<void> _performSearch(String raw) async {
    final tokens = raw
        .split(RegExp(r'[,;\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    _includeNames = {...tokens, ...?widget.ingredients}.toList();

    setState(() {
      _searchQuery = raw.trim();
      _gridRecipes.clear();
      _page = 1;
      _hasMore = true;
      _loading = true;
      _error = '';
    });

    await _fetchPage(1);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchPage(int page) async {
    setState(() => _loadingMore = page > 1);
    try {
      List<Recipe> recipes;
      if (_searchQuery.isEmpty) {
        recipes = await ApiService.fetchPopularRecipes();
      } else {
        recipes = await ApiService.searchRecipes(
          query: _searchQuery,
          page: page,
          limit: _pageSize,
          sort: _sortOptions[_sortIndex].key,
          ingredientNames: _includeNames,
          excludeIngredientIds:
              _excludeIds.map(int.tryParse).whereType<int>().toList(),
        );
      }

      setState(() {
        _page = page;
        _gridRecipes = recipes;
        _hasMore = false; // ยังไม่เปิด paging
      });
    } on TimeoutException {
      _error = 'เซิร์ฟเวอร์ตอบช้า ลองใหม่ภายหลัง';
    } on SocketException {
      _error = 'ไม่มีการเชื่อมต่ออินเทอร์เน็ต';
    } catch (e) {
      _error = 'เกิดข้อผิดพลาด: $e';
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onScroll() {
    if (_scrollCtl.position.pixels >
            _scrollCtl.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _fetchPage(_page + 1);
    }
  }

/* ───────────────────────── UI helpers ─────────────────────── */
  Widget _resultHeading() {
    if (_searchQuery.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        'ผลค้นหาสูตร “$_searchQuery”',
        style: const TextStyle(
          fontFamily: 'Montserrat', // --- ใช้ Montserrat
          fontWeight: FontWeight.w700, // --- หนาที่สุด
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
      itemSize: 110, // --- ขนาด 3 ใบพอดี
      highlightTerms: _includeNames,
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
                style: TextStyle(
                    fontFamily: 'Roboto', // --- Roboto ธรรมดา
                    color: Colors.grey)),
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
          childAspectRatio: 0.56, // 177 / 315
        ),
        delegate: SliverChildBuilderDelegate(
          (ctx, index) {
            if (index == _gridRecipes.length) {
              return const Center(child: CircularProgressIndicator());
            }
            return SearchRecipeCard(
              recipe: _gridRecipes[index],
              rankOverride: _sortIndex == 0 ? index + 1 : null,
              highlightTerms: _includeNames,
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

/* ───────────────────────── build ───────────────────────────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollCtl,
        slivers: [
          /* ── SliverAppBar + SearchBar ────────────────── */
          SliverAppBar(
            pinned: true,
            centerTitle: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: const BackButton(color: Colors.black),
            title: const Text(
              'Search',
              style: TextStyle(
                  fontFamily: 'Montserrat', // --- Montserrat
                  fontWeight: FontWeight.w600,
                  color: Colors.black),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(72),
              child: CustomSearchBar(
                onChanged: _onSearchChanged,
                onSubmitted: _performSearch,
                onFilterTap: () async {
                  final res = await Navigator.push<List<List<String>>>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const IngredientFilterScreen()),
                  );
                  if (res != null) {
                    _includeNames = res[0];
                    _excludeIds = res[1];
                    _performSearch(_searchQuery.isEmpty ? '' : _searchQuery);
                  }
                },
                hasActiveFilter:
                    _includeNames.isNotEmpty || _excludeIds.isNotEmpty,
              ),
            ),
          ),
          SliverToBoxAdapter(child: _resultHeading()),
          SliverToBoxAdapter(child: _buildHero()),

          /* ── Sort chips ─────────────────────────────── */
          SliverToBoxAdapter(
            child: ChoiceChipFilter(
              options: _sortOptions,
              initialIndex: _sortIndex,
              onChanged: (idx, key) {
                setState(() => _sortIndex = idx);
                _performSearch(_searchQuery.isEmpty ? '' : _searchQuery);
              },
            ),
          ),

          /* ── Result grid ───────────────────────────── */
          _buildGrid(),
        ],
      ),

      /* ── Bottom-navigation ────────────────────────── */
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: _navIndex,
        isLoggedIn: _isLoggedIn,
        onItemSelected: (i) async {
          if ((i == 2 || i == 3) &&
              !await AuthService.checkAndRedirectIfLoggedOut(context)) return;
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
