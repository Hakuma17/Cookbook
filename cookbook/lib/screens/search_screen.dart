// lib/screens/search_screen.dart

import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';

// ★★★ [NEW] ดึงค่า “ตัดคำภาษาไทย” จาก SettingsStore
import 'package:provider/provider.dart';
import '../stores/settings_store.dart';

import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/search_recipe_card.dart';
import '../widgets/custom_search_bar.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/hero_carousel.dart';
import '../widgets/choice_chip_filter.dart';
import '../widgets/allergy_warning_dialog.dart';

class SearchScreen extends StatefulWidget {
  final List<String>? ingredients;
  final List<String>? excludeIngredients;
  final int? initialSortIndex;

  const SearchScreen({
    super.key,
    this.ingredients,
    this.excludeIngredients,
    this.initialSortIndex,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  /* ───────── constants ───────── */
  static const _pageSize = 26;
  static const List<FilterOption> _sortOptions = [
    FilterOption('ยอดนิยม', 'popular'),
    FilterOption('มาแรง', 'trending'),
    FilterOption('ล่าสุด', 'latest'),
    FilterOption('แนะนำ', 'recommended'),
  ];

  /* ───────── controllers ───────── */
  final _scrollCtl = ScrollController();

  /* ───────── state ───────── */
  late Future<void> _initFuture;
  List<Recipe> _recipes = [];
  List<String> _respTokens = [];
  List<String> _includeNames = [];
  List<String> _excludeNames = [];
  List<Ingredient> _allergyList = [];

  String _searchQuery = '';
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  late int _sortIndex;
  bool _isLoggedIn = false; // ★ มี state นี้อยู่แล้ว
  String? _paginationErrorMsg;
  int _reqId = 0;

  /* ───────── init ───────── */
  @override
  void initState() {
    super.initState();
    _includeNames = [...?widget.ingredients];
    _excludeNames = [...?widget.excludeIngredients];
    _sortIndex = widget.initialSortIndex ?? 2;
    _scrollCtl.addListener(_onScroll);
    _initFuture = _initialize();
  }

  @override
  void dispose() {
    _scrollCtl.dispose();
    super.dispose();
  }

  /* ───────── data fetch ───────── */
  Future<void> _initialize() async {
    await Future.wait([
      _refreshLoginStatus(),
      _performSearch(isInitialLoad: true),
    ]);
  }

  Future<void> _refreshLoginStatus() async {
    final loggedIn = await AuthService.isLoggedIn();
    if (!mounted) return;
    setState(() => _isLoggedIn = loggedIn);

    if (loggedIn) {
      try {
        final list = await ApiService.fetchAllergyIngredients();
        if (mounted) setState(() => _allergyList = list);
      } on ApiException catch (e) {
        _showSnack(e.message);
      }
    } else {
      if (mounted) setState(() => _allergyList = []);
    }
  }

  void _onQueryChanged(String q) => setState(() => _searchQuery = q);

  Future<void> _performSearch(
      {String? query, bool isInitialLoad = false}) async {
    final myId = ++_reqId;
    if (mounted) {
      setState(() {
        _searchQuery = query ?? _searchQuery;
        _page = 1;
        _hasMore = true;
        _paginationErrorMsg = null;
        if (!isInitialLoad) _recipes.clear();
      });
    }

    if (isInitialLoad) {
      await _fetchPage(1, myId);
    } else {
      final future = _fetchPage(1, myId);
      if (mounted) setState(() => _initFuture = future);
      await future;
    }
  }

  Future<void> _fetchPage(int page, int myId) async {
    if (page > 1 && mounted) {
      setState(() {
        _loadingMore = true;
        _paginationErrorMsg = null;
      });
    }

    try {
      // ★★★ [NEW] ส่งค่าสวิตช์ “ตัดคำภาษาไทย” ไปยัง backend
      // - ดีฟอลต์: ปิด (false) ตาม SettingsStore
      final tokenize =
          context.read<SettingsStore>().searchTokenizeEnabled; // true/false

      final res = await ApiService.searchRecipes(
        query: _searchQuery,
        page: page,
        limit: _pageSize,
        sort: _sortOptions[_sortIndex].key,
        ingredientNames: _includeNames,
        excludeIngredientNames: _excludeNames,
        tokenize: tokenize, // ✅ ส่งต่อให้ backend
      );

      if (myId != _reqId || !mounted) return;

      setState(() {
        _page = page;
        _respTokens = res.tokens;
        if (page == 1) {
          _recipes = res.recipes;
        } else {
          _recipes.addAll(res.recipes);
        }
        _hasMore = res.recipes.length == _pageSize;
      });
    } on UnauthorizedException {
      await AuthService.logout();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (page > 1) {
        setState(() => _paginationErrorMsg = e.message);
      } else {
        throw Exception(e.message);
      }
    } catch (e, st) {
      log('Fetch page error', error: e, stackTrace: st);
      if (!mounted) return;
      if (page > 1) {
        setState(() => _paginationErrorMsg = 'เกิดข้อผิดพลาดในการโหลด');
      } else {
        throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
      }
    } finally {
      if (mounted && page > 1) setState(() => _loadingMore = false);
    }
  }

  void _onScroll() {
    if (_scrollCtl.position.pixels >
            _scrollCtl.position.maxScrollExtent - 300 &&
        !_loadingMore &&
        _hasMore &&
        _paginationErrorMsg == null) {
      _fetchPage(_page + 1, _reqId);
    }
  }

  // ★ 1. [แก้ไข] ปรับปรุง Logic การนำทางให้เป็นมาตรฐานเดียวกัน
  void _onBottomNavTap(int index) {
    if (index == 1) return; // หน้าปัจจุบัน

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/my_recipes');
        break;
      case 3:
        final route = _isLoggedIn ? '/profile' : '/settings';
        Navigator.pushReplacementNamed(context, route);
        break;
    }
  }

  /* ───────── build ───────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildErrorState(context, snapshot.error.toString());
          }

          return RefreshIndicator(
            onRefresh: () async => await _performSearch(),
            child: CustomScrollView(
              controller: _scrollCtl,
              slivers: [
                _buildAppBar(context),
                if (_searchQuery.isNotEmpty) _buildResultHeading(context),
                _buildFilterSummary(context),
                if (_recipes.isNotEmpty) ...[
                  _buildHero(context),
                  _buildSortOptions(context),
                  _buildGrid(),
                ],
                if (_recipes.isEmpty &&
                    snapshot.connectionState == ConnectionState.done)
                  const SliverFillRemaining(
                    child:
                        Center(child: Text('ไม่พบสูตรอาหารที่ตรงกับเงื่อนไข')),
                  ),
              ],
            ),
          );
        },
      ),
      // ★ 2. [แก้ไข] ส่งค่า `isLoggedIn` เข้าไปใน CustomBottomNav
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: 1,
        onItemSelected: _onBottomNavTap,
        isLoggedIn: _isLoggedIn,
      ),
    );
  }

  /* ───────── UI helpers ───────── */

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      title: const Text('ค้นหาสูตรอาหาร'),
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline),
          onPressed: () => _showSearchHelp(context),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: CustomSearchBar(
            onChanged: _onQueryChanged,
            onSubmitted: (q) => _performSearch(query: q),
            onFilterTap: _navToFilterScreen,
            hasActiveFilter:
                _includeNames.isNotEmpty || _excludeNames.isNotEmpty,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              Text(msg.replaceFirst('Exception: ', ''),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => setState(() => _initFuture = _initialize()),
                child: const Text('ลองอีกครั้ง'),
              ),
            ],
          ),
        ),
      );

  Widget _buildResultHeading(BuildContext context) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('ผลการค้นหาสำหรับ “$_searchQuery”',
              style: Theme.of(context).textTheme.titleLarge),
        ),
      );

  Widget _buildFilterSummary(BuildContext context) {
    final theme = Theme.of(context);
    if (_includeNames.isEmpty && _excludeNames.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ..._includeNames.map((n) => Chip(
                  label: Text(n),
                  onDeleted: () {
                    setState(() => _includeNames.remove(n));
                    _performSearch();
                  },
                  backgroundColor: theme.colorScheme.primaryContainer,
                )),
            ..._excludeNames.map((n) => Chip(
                  label: Text('ไม่เอา $n'),
                  onDeleted: () {
                    setState(() => _excludeNames.remove(n));
                    _performSearch();
                  },
                  backgroundColor: theme.colorScheme.errorContainer,
                  labelStyle:
                      TextStyle(color: theme.colorScheme.onErrorContainer),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext _) {
    final top3 = _recipes.take(3).toList();
    if (top3.isEmpty) return const SliverToBoxAdapter(child: SizedBox());
    return SliverToBoxAdapter(
      child: HeroCarousel(
        recipes: top3,
        highlightTerms: _respTokens,
        onTap: _handleRecipeTap,
      ),
    );
  }

  Widget _buildSortOptions(BuildContext _) => SliverToBoxAdapter(
        child: ChoiceChipFilter(
          options: _sortOptions,
          initialIndex: _sortIndex,
          onChanged: (i, _) {
            setState(() => _sortIndex = i);
            _performSearch();
          },
        ),
      );

  Widget _buildGrid() => SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 210,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.65,
          ),
          delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              if (i == _recipes.length) {
                if (_paginationErrorMsg != null) {
                  return Center(
                    child: TextButton(
                      onPressed: () => _fetchPage(_page + 1, _reqId),
                      child: Text(_paginationErrorMsg!),
                    ),
                  );
                }
                return const Center(child: CircularProgressIndicator());
              }

              final r = _recipes[i].copyWith(
                hasAllergy: _checkIfRecipeHasAllergy(_recipes[i]),
              );

              return SearchRecipeCard(
                recipe: r,
                rankOverride: _sortIndex == 0 ? i + 1 : null,
                highlightTerms: _respTokens,
                onTap: () => _handleRecipeTap(r),
              );
            },
            childCount: _recipes.length +
                (_loadingMore || _paginationErrorMsg != null ? 1 : 0),
          ),
        ),
      );

  /* ───────── misc helpers ───────── */

  void _showSnack(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? Theme.of(context).colorScheme.error : Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
    ));
  }

  bool _checkIfRecipeHasAllergy(Recipe r) {
    final bad = _allergyList.map((e) => e.id).toSet();
    return _isLoggedIn && bad.isNotEmpty && r.ingredientIds.any(bad.contains);
  }

  void _handleRecipeTap(Recipe r) {
    if (r.hasAllergy) {
      final badNames = _allergyList
          .where((ing) => r.ingredientIds.contains(ing.id))
          .map((e) => e.name)
          .toList();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AllergyWarningDialog(
          recipe: r,
          badIngredientNames: badNames,
          onConfirm: (rx) {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/recipe_detail', arguments: rx);
          },
        ),
      );
    } else {
      Navigator.pushNamed(context, '/recipe_detail', arguments: r);
    }
  }

  Future<void> _navToFilterScreen() async {
    final result = await Navigator.pushNamed(
      context,
      '/ingredient_filter',
      arguments: {
        'initialInclude': _includeNames,
        'initialExclude': _excludeNames,
      },
    ) as List<List<String>>?;

    if (result != null) {
      _includeNames = result[0];
      _excludeNames = result[1];
      _performSearch();
    }
  }

  void _showSearchHelp(BuildContext ctx) {
    final tt = Theme.of(ctx).textTheme;
    Widget dot(String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontSize: 16)),
              Expanded(child: Text(t, style: tt.bodyMedium)),
            ],
          ),
        );
    showModalBottomSheet(
      context: ctx,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📝 วิธีใช้งานการค้นหา', style: tt.titleLarge),
            const SizedBox(height: 16),
            dot('พิมพ์คำค้นแล้วกดปุ่มค้นหาบนคีย์บอร์ด'),
            dot('ใช้ปุ่ม “กรอง” เพื่อเลือก/ยกเว้นวัตถุดิบ'),
            dot('แตะ ✕ เพื่อถอดฟิลเตอร์'),
            dot('แตะการ์ดสูตรเพื่อดูรายละเอียด'),
            // ★★★ [NEW] ช่วยอธิบายโหมดค้นหาเมื่อเปิด/ปิดการตัดคำ
            dot('หาก “ตัดคำภาษาไทย” ถูกปิด (ค่าเริ่มต้น): ใส่คำหลายคำโดยคั่นด้วยช่องว่างหรือเครื่องหมายจุลภาค เช่น "กุ้ง กระเทียม" หรือ "กุ้ง,กระเทียม" เพื่อค้นหาสูตรที่มีอย่างน้อยทั้งสองวัตถุดิบ'),
            dot('หาก “ตัดคำภาษาไทย” ถูกเปิด: ระบบจะพยายามแยกคำอัตโนมัติจากประโยคยาว (ต้องใช้เวลาเล็กน้อย)'),
          ],
        ),
      ),
    );
  }
}
