// lib/screens/search_screen.dart
// ─────────────────────────────────────────────────────────────
// Search Screen (rev. backend-tokens – 2025-07-04)
//
// • backend ส่ง “tokens” กลับมา → ใช้ไฮไลท์ได้ตรงโดยไม่ตัดคำในแอป
// • ใช้ SearchResponse แทน List<Recipe>
// • ป้องกัน response เก่าทับใหม่ด้วย _reqId (คงเดิม)
// ─────────────────────────────────────────────────────────────

// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../models/search_response.dart'; // ★ NEW
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
  const SearchScreen({super.key, this.ingredients, this.excludeIngredients});
  final List<String>? ingredients;
  final List<String>? excludeIngredients;

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
  List<String> _respTokens = []; // ★ tokens จาก backend

  List<String> _includeNames = [];
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
      _respTokens.clear();
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
      _respTokens.clear();
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
      /* ★ ใช้ SearchResponse แทน List<Recipe> */
      final SearchResponse res = await ApiService.searchRecipes(
        query: _searchQuery,
        page: page,
        limit: _pageSize,
        sort: _sortOptions[_sortIndex].key,
        // ingredientNames: _includeNames, // backend ยังไม่ใช้
        excludeIngredientIds:
            _excludeIds.map(int.tryParse).whereType<int>().toList(),
      );

      if (myId != _reqId || !mounted) return; // stale response → ทิ้ง

      setState(() {
        _page = page;
        _respTokens = res.tokens;
        _heroRecipes = res.recipes.take(3).toList();
        _gridRecipes =
            page == 1 ? res.recipes : [..._gridRecipes, ...res.recipes];
        _hasMore = res.recipes.length == _pageSize;
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

  /* ───────────── helper: highlight terms ───── */
  List<String> get _highlightTerms => _respTokens.isNotEmpty
      ? _respTokens
      : _searchQuery.split(RegExp(r'[ ,;]'));

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
      highlightTerms: _highlightTerms, // ★
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
      return const SliverFillRemaining(
        child: Center(
          child: Text('ไม่พบสูตรอาหารที่ต้องการ',
              style: TextStyle(fontFamily: 'Roboto', color: Colors.grey)),
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
              highlightTerms: _highlightTerms, // ★
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
          _buildAppBar(),
          SliverToBoxAdapter(child: _resultHeading()),
          SliverToBoxAdapter(child: _buildHero()),
          SliverToBoxAdapter(
            child: ChoiceChipFilter(
              options: _sortOptions,
              initialIndex: _sortIndex,
              onChanged: (idx, _) {
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
        onItemSelected: _onBottomNavTap,
      ),
    );
  }

  /* ───────────── SliverAppBar ─────────── */
  Widget _buildAppBar() => SliverAppBar(
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
            hasActiveFilter: _includeNames.isNotEmpty || _excludeIds.isNotEmpty,
          ),
        ),
      );

  /* ───────────── bottom-nav helper ───── */
  Future<void> _onBottomNavTap(int i) async {
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
  }

  /* ───────────── bottom-sheet helper ───── */
  void _showSearchHelp() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🧐 วิธีค้นหาสูตรอาหาร',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            _bullet('พิมพ์ชื่อเมนู เช่น “ผัดกะเพรา” ได้เลย'),
            _bullet('ใส่หลายคำก็ได้นะ เช่น “กุ้ง กระเทียม”'),
            _bullet('พิมพ์ติดกันก็ไม่เป็นไร เดี๋ยวแอปช่วยแยกให้เอง'),
            _bullet('ระบบจะหาจากชื่อก่อน แล้วดูวัตถุดิบในสูตร'),
            _bullet('เลือกการจัดเรียงหรือกดปุ่มกรองได้ด้วยน้า'),
            const SizedBox(height: 8),
            const Text(
              'ขอให้เจอเมนูอร่อย ๆ นะ!',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bullet(String t) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [const Text('• '), Expanded(child: Text(t))],
      );
}
