// lib/screens/search_screen.dart
//
// 2025-08-11 – Fix & polish:
// - Tag colors: include=green, exclude=red, group=default
// - Cute dialog when group has no results (page 1)            // ⛔️ REMOVED (ดูคอมเมนต์ ★ below)
// - Remove “กลุ่ม:” prefix on tag label
// - FIX setState arrow returning Future -> use block {} instead
// - Keep safer paging & hero on page 1
//
// 2025-08-21 – UX: No modal on empty-group + pop refresh guard
// - ★ แทนที่ “ไดอะล็อกกลุ่มว่าง” ด้วย inline empty state ในหน้าเลย
// - ป้องกัน didPopNext รีเฟรชเมื่อปิด dialog/bottom sheet ภายในหน้า (ไม่โหลดซ้ำไม่จำเป็น)

import 'dart:async';
import 'package:flutter/material.dart';
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
import '../widgets/choice_chip_filter.dart'; // ใช้เฉพาะตัวเลือก sort (single)
import '../widgets/allergy_warning_dialog.dart';
import '../main.dart' show routeObserver;
import '../utils/sanitize.dart';

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

class _SearchScreenState extends State<SearchScreen> with RouteAware {
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
  Timer? _queryDebounce; // debounce สำหรับพิมพ์/ลบคำค้น

  /* ───────── state ───────── */
  late Future<void> _initFuture;
  List<Recipe> _recipes = [];
  List<String> _respTokens = [];
  int? _total; // จำนวนผลลัพธ์ทั้งหมด (ถ้า backend ส่งมา)

  // ฟิลเตอร์แบบชื่อวัตถุดิบ
  List<String> _includeNames = [];
  List<String> _excludeNames = [];

  // ฟิลเตอร์ “กลุ่มวัตถุดิบ”
  String? _group;
  final List<String> _includeGroupNames = [];
  final List<String> _excludeGroupNames = [];

  // สำหรับ dialog เตือนแพ้ (ตอนแตะการ์ด)
  List<Ingredient> _allergyList = [];

  String _searchQuery = '';
  bool _loadingMore = false;
  bool _pagingInFlight = false;
  bool _hasMore = true;
  int _page = 1;
  late int _sortIndex;
  bool _loadingNewSearch = false; // โหลดรอบใหม่ (หน้า 1) ระหว่างพิมพ์/ลบ
  bool _isLoggedIn = false;
  String? _paginationErrorMsg;
  int _reqId = 0;
  bool _didInitFromArgs = false; // ใช้ตรวจสอบว่าได้ init จาก args หรือไม่

  // ลบตัวแปรนี้ออก เพราะเราไม่ใช้ dialog อีกแล้ว
  // int? _emptyDialogShownForReq;

  // ★ Guard: กันไม่ให้ didPopNext รีเฟรชเมื่อปิด overlay ภายในหน้า (dialog/bottom sheet)
  bool _suppressNextDidPopNextRefresh = false;

  // ★ เพิ่มคีย์ sort สำหรับยิง API โดยตรง (ซ่อนชิปไว้ชั่วคราว)
  // ค่าเริ่มต้น: เรียงตามชื่อเมนู ก→ฮ
  String _sortKey =
      'name_asc'; // ถ้า BE ใช้คีย์อื่น ปรับที่นี่ได้ เช่น 'name_th_asc'

  bool get _hasGroupFilter =>
      _group != null ||
      _includeGroupNames.isNotEmpty ||
      _excludeGroupNames.isNotEmpty;

  /* ───────── init ───────── */
  @override
  void initState() {
    super.initState();
    _includeNames = [...?widget.ingredients];
    _excludeNames = [...?widget.excludeIngredients];
    _sortIndex = widget.initialSortIndex ?? 2; // เก็บไว้แม้จะไม่แสดงชิปตอนนี้
    _scrollCtl.addListener(_onScroll);
    _initFuture = _initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }

    // รับ args จากหน้าอื่น (เช่น Home → กดการ์ดกลุ่ม)
    if (!_didInitFromArgs) {
      // ← กันอ่านซ้ำ
      _didInitFromArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final g =
            (args['group'] ?? args['Group'] ?? args['catagorynew'])?.toString();
        if (g != null && g.trim().isNotEmpty) {
          _group = g.trim();
        }

        // ★ รองรับการส่ง initialSortIndex หรือ sort จากหน้า Home
        final sortFromIndex = args['initialSortIndex'];
        if (sortFromIndex is int) {
          _sortIndex = sortFromIndex;
          // map index → key ให้ตรงกับ _sortOptions ดั้งเดิม
          if (sortFromIndex >= 0 && sortFromIndex < _sortOptions.length) {
            _sortKey = _sortOptions[sortFromIndex].key; // popular/latest/...
          }
        } else if (args['sort'] is String) {
          final s = (args['sort'] as String).trim();
          if (s.isNotEmpty) _sortKey = s; // อนุญาตส่งคีย์ตรง ๆ
        } else {
          // ไม่มี args → โหมดค่าเริ่มต้น: แสดง “ทั้งหมด” เรียงชื่อ
          _sortKey = 'name_asc';
        }

        final incG = args['include_groups'] as List<String>?;
        final excG = args['exclude_groups'] as List<String>?;
        if (incG != null) {
          _includeGroupNames
            ..clear()
            ..addAll(
                incG.where((e) => e.trim().isNotEmpty).map((e) => e.trim()));
        }
        if (excG != null) {
          _excludeGroupNames
            ..clear()
            ..addAll(
                excG.where((e) => e.trim().isNotEmpty).map((e) => e.trim()));
        }
        final myId = ++_reqId; // ยิงครั้งแรกหลังอ่าน args
        _performSearch(isInitialLoad: false, forceReqId: myId);
      }
    }
  }

  @override
  void dispose() {
    _scrollCtl.dispose();
    _queryDebounce?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // กลับมาหน้านี้ → รีเฟรชหน้าแรก
  @override
  void didPopNext() {
    // ★ ถ้าพึ่งปิด dialog/bottom sheet ของ "หน้านี้เอง" ไม่ต้องรีเฟรช
    if (_suppressNextDidPopNextRefresh) {
      _suppressNextDidPopNextRefresh = false;
      return;
    }
    _paginationErrorMsg = null;
    _loadingMore = false;
    final myId = ++_reqId;
    _fetchPage(1, myId);
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

  // อัปเดตผลแบบ Live ด้วย Debounce (พิมพ์/ลบแล้วอัปเดตเร็ว ไม่หน่วง)
  void _onQueryChanged(String q) {
    final cleaned = Sanitize.query(q);
    if (cleaned == _searchQuery) return; // ไม่เปลี่ยนจริง → ข้าม
    setState(() => _searchQuery = cleaned);

    // หน่วงเล็กน้อยเพื่อรวมคีย์สโตรคต่อเนื่อง และยกเลิกงานเก่า
    _queryDebounce?.cancel();
    _queryDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _performSearch(jumpToTop: false);
    });
  }

  Future<void> _performSearch({
    String? query,
    bool isInitialLoad = false,
    int? forceReqId,
    bool jumpToTop = true,
  }) async {
    final myId = forceReqId ?? ++_reqId;
    if (mounted) {
      setState(() {
        _searchQuery = Sanitize.query(query ?? _searchQuery);
        _page = 1;
        _hasMore = true;
        _paginationErrorMsg = null;
        _total = null; // รีเซ็ตจำนวนรวมเมื่อเริ่มค้นหาใหม่
        _loadingNewSearch = true; // แสดงแถบโหลดบาง ๆ แต่คงรายการเดิมไว้
        // _emptyDialogShownForReq = null; // ⛔️ ไม่ใช้แล้ว
      });
    }

    if (jumpToTop && _scrollCtl.hasClients) {
      _scrollCtl.jumpTo(0);
    }

    // ถ้า query ว่างและไม่มีฟิลเตอร์เลย ให้เรียกแบบค่าเริ่มต้น (ยังยิงเพื่อโชว์ "ทั้งหมด")
    // หมายเหตุ: เราไม่ block คำขอ แต่พึ่งพา _reqId เพื่อทิ้งผลลัพธ์เก่า ช่วยกันค้างเมื่อเปลี่ยนคำเร็ว ๆ

    final fut = _fetchPage(1, myId);
    if (isInitialLoad) {
      // โหลดครั้งแรกเท่านั้นที่ผูกกับ FutureBuilder
      await fut;
    } else {
      // โหลดครั้งต่อไป: อย่าแตะ _initFuture เพื่อไม่ให้ทั้งหน้าถูกแทนด้วยวงกลมโหลด
      await fut;
    }
  }

  Future<void> _fetchPage(int page, int myId) async {
    final isPaging = page > 1;

    // ⬇️ บล็อกเฉพาะการโหลดต่อ (infinite scroll) เท่านั้น
    if (isPaging && _pagingInFlight) return;
    _pagingInFlight = isPaging; // กำกับเฉพาะตอนเพจ > 1

    if (isPaging && mounted) {
      setState(() {
        _loadingMore = true;
        _paginationErrorMsg = null;
      });
    }

    try {
      final tokenize = context.read<SettingsStore>().searchTokenizeEnabled;
      final res = await ApiService.searchRecipes(
        query: _searchQuery,
        page: page,
        limit: _pageSize,
        // ใช้คีย์ sort ใหม่ (_sortKey) เพื่อกำหนดพฤติกรรมเริ่มต้น: เรียงชื่อ ก→ฮ
        sort: _sortKey,
        ingredientNames: _includeNames,
        excludeIngredientNames: _excludeNames,
        tokenize: tokenize,
        group: _group,
        includeGroupNames: _includeGroupNames,
        excludeGroupNames: _excludeGroupNames,
      );

      if (myId != _reqId || !mounted) return; // ทิ้งผลเก่า

      setState(() {
        _page = page;
        _respTokens = res.tokens;
        // อัปเดตจำนวนรวมถ้า backend ส่งมา
        if (res.total != null) _total = res.total;
        if (page == 1) {
          _recipes = res.recipes;
          _loadingNewSearch = false; // จบโหลดรอบใหม่
        } else {
          _recipes.addAll(res.recipes);
        }
        _hasMore = res.recipes.length == _pageSize;
      });

      // ★ เดิม: แสดง "Cute dialog" เมื่อหน้า 1 ว่างและมี group filter
      // → ⛔️ ยกเลิก: เปลี่ยนไปแสดง inline empty state ในหน้าแทน (ไม่เด้ง dialog)
    } on UnauthorizedException {
      await AuthService.logout();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (isPaging) {
        setState(() => _paginationErrorMsg = e.message);
      } else {
        throw Exception(e.message);
      }
    } catch (_) {
      if (!mounted) return;
      if (isPaging) {
        setState(() => _paginationErrorMsg = 'เกิดข้อผิดพลาดในการโหลด');
      } else {
        throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
      }
    } finally {
      if (isPaging) {
        _pagingInFlight = false;
        if (mounted) setState(() => _loadingMore = false);
      }
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

  // Bottom nav
  void _onBottomNavTap(int index) {
    if (index == 1) return; // current
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
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // ถ้าเส้นทางนี้เป็น route แรก (เช่นถูกเปิดทับหน้า Welcome แบบผิด flow)
        // ให้ไปหน้า Home แทนการ pop ไป Welcome
        if (didPop) return;
        final isFirst = ModalRoute.of(context)?.isFirst ?? false;
        if (isFirst) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      },
      child: Scaffold(
        body: FutureBuilder<void>(
          future: _initFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                _recipes.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _buildErrorState(context, snapshot.error.toString());
            }

            return RefreshIndicator(
              onRefresh: () async => _performSearch(),
              child: CustomScrollView(
                controller: _scrollCtl,
                slivers: [
                  _buildAppBar(context),
                  if (_loadingNewSearch)
                    const SliverToBoxAdapter(
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  // ★ แสดงหัวข้อเสมอ: ถ้าไม่มีคำค้นให้บอกว่า "เมนูทั้งหมด (N)"
                  _buildResultHeading(context),
                  _buildFilterSummary(context),
                  if (_recipes.isNotEmpty) ...[
                    if (_page == 1) _buildHero(context),
                    /*
                    ─────────────────────────────────────────────
                    ชิปเรียง 4 อัน (ยอดนิยม/มาแรง/ล่าสุด/แนะนำ)
                    ปิดการแสดงผลไว้ชั่วคราวตามคำขอ แต่เก็บโค้ดไว้ไม่ลบ
                    ─────────────────────────────────────────────
                    _buildSortOptions(context),
                    */
                    _buildGrid(),
                  ],
                  if (_recipes.isEmpty &&
                      snapshot.connectionState == ConnectionState.done)
                    _buildEmptyState(context), // ★ inline empty state
                ],
              ),
            );
          },
        ),
        bottomNavigationBar: CustomBottomNav(
          selectedIndex: 1,
          onItemSelected: _onBottomNavTap,
          isLoggedIn: _isLoggedIn,
        ),
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
          tooltip: 'วิธีใช้งานการค้นหา',
          onPressed: () {
            // ★ ปิดไม่ให้ didPopNext รีเฟรชตอนปิด bottom sheet นี้
            _suppressNextDidPopNextRefresh = true;
            _showSearchHelp(context);
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: CustomSearchBar(
            initialText: _searchQuery,
            onChanged: _onQueryChanged,
            onSubmitted: (q) => _performSearch(query: q),
            onFilterTap: _navToFilterScreen,
            hasActiveFilter: _includeNames.isNotEmpty ||
                _excludeNames.isNotEmpty ||
                _group != null ||
                _includeGroupNames.isNotEmpty ||
                _excludeGroupNames.isNotEmpty,
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
              Text(
                msg.replaceFirst('Exception: ', ''),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              // ⬇⬇ FIX: อย่าใช้ arrow-return ใน setState (จะคืน Future ออกมา)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _initFuture = _initialize();
                  });
                },
                child: const Text('ลองอีกครั้ง'),
              ),
            ],
          ),
        ),
      );

  Widget _buildResultHeading(BuildContext context) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Builder(builder: (_) {
            final count = _total ?? _recipes.length;
            // เลเบลกรณีเปิดมาจากหน้า Home → ดูเพิ่มเติม (popular/latest/…)
            String? seeMoreLabel;
            switch (_sortKey) {
              case 'popular':
                seeMoreLabel = 'เมนูยอดนิยม';
                break;
              case 'latest':
                seeMoreLabel = 'เมนูอัปเดตใหม่';
                break;
              case 'trending':
                seeMoreLabel = 'เมนูมาแรง';
                break;
              case 'recommended':
                seeMoreLabel = 'เมนูแนะนำ';
                break;
            }

            final text = _searchQuery.isNotEmpty
                ? 'ผลการค้นหาสำหรับ “$_searchQuery” ($count)'
                : (seeMoreLabel != null &&
                        _group == null &&
                        _includeNames.isEmpty &&
                        _excludeNames.isEmpty &&
                        _includeGroupNames.isEmpty &&
                        _excludeGroupNames.isEmpty)
                    ? 'ผลการค้นหา$seeMoreLabel ($count)'
                    : 'เมนูทั้งหมด ($count)'; // โหมดค่าเริ่มต้น (เรียงชื่อ ก→ฮ)
            return Text(text, style: Theme.of(context).textTheme.titleLarge);
          }),
        ),
      );

  // ★ Summary chips (include = เขียว, exclude = แดง, group = สีเดิม)
  Widget _buildFilterSummary(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_includeNames.isEmpty &&
        _excludeNames.isEmpty &&
        _group == null &&
        _includeGroupNames.isEmpty &&
        _excludeGroupNames.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (_group != null)
              Chip(
                // ⚠️ เอาคำว่า “กลุ่ม:” ออก เหลือชื่ออย่างเดียว
                label: Text(_group!),
                onDeleted: () {
                  setState(() => _group = null);
                  _performSearch();
                },
                backgroundColor: cs.secondaryContainer,
                labelStyle: TextStyle(color: cs.onSecondaryContainer),
              ),

            // include “กลุ่ม” (สีปกติ)
            ..._includeGroupNames.map((g) => Chip(
                  label: Text(g),
                  onDeleted: () {
                    setState(() => _includeGroupNames.remove(g));
                    _performSearch();
                  },
                  backgroundColor: cs.secondaryContainer,
                  labelStyle: TextStyle(color: cs.onSecondaryContainer),
                )),

            // exclude “กลุ่ม” (สีปกติอีกโทน)
            ..._excludeGroupNames.map((g) => Chip(
                  label: Text(g),
                  onDeleted: () {
                    setState(() => _excludeGroupNames.remove(g));
                    _performSearch();
                  },
                  backgroundColor: cs.tertiaryContainer,
                  labelStyle: TextStyle(color: cs.onTertiaryContainer),
                )),

            // include ชื่อวัตถุดิบ → สีเขียว
            ..._includeNames.map((n) => Chip(
                  label: Text(n),
                  onDeleted: () {
                    setState(() => _includeNames.remove(n));
                    _performSearch();
                  },
                  backgroundColor: Colors.green.shade100,
                  labelStyle: const TextStyle(
                    color: Color(0xFF0E7A36), // เขียวเข้มอ่านง่าย
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(color: Colors.green.shade400),
                )),

            // exclude ชื่อวัตถุดิบ → สีแดง
            ..._excludeNames.map((n) => Chip(
                  label: Text('ไม่เอา $n'),
                  onDeleted: () {
                    setState(() => _excludeNames.remove(n));
                    _performSearch();
                  },
                  backgroundColor: cs.errorContainer,
                  labelStyle: TextStyle(
                    color: cs.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                  side: BorderSide(color: cs.error.withValues(alpha: .35)),
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

  // ignore: unused_element
  Widget _buildSortOptions(BuildContext _) => SliverToBoxAdapter(
        child: ChoiceChipFilter(
          options: _sortOptions,
          initialIndex: _sortIndex,
          onChanged: (i, _) {
            setState(() {
              _sortIndex = i;
              _sortKey = _sortOptions[i].key; // sync กับคีย์ที่ยิง API
            });
            _performSearch();
          },
        ),
      );

  Widget _buildGrid() => SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverGrid(
          key: const PageStorageKey('search_grid'),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 210,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.575,
          ),
          delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              if (i == _recipes.length) {
                if (_paginationErrorMsg != null) {
                  return Center(
                    child: TextButton.icon(
                      onPressed: () => _fetchPage(_page + 1, _reqId),
                      icon: const Icon(Icons.refresh),
                      label: Text(
                          '${_paginationErrorMsg!} • แตะเพื่อโหลดอีกครั้ง'),
                    ),
                  );
                }
                return const Center(child: CircularProgressIndicator());
              }

              final r = _recipes[i];
              return SearchRecipeCard(
                key: ValueKey(r.id),
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

  void _handleRecipeTap(Recipe r) {
    if (r.hasAllergy) {
      // ★★★ ใช้ชื่อจาก backend ก่อน (recipe.allergyNames) แล้วค่อย fallback เป็นคำนวณเอง
      final backendNames = r.allergyNames;
      final fallbackNames = _allergyList
          .where((ing) => r.ingredientIds.contains(ing.id))
          .map((e) => e.name)
          .toList();
      final badNames =
          backendNames.isNotEmpty ? backendNames : fallbackNames; //

      // ★ กันไม่ให้ didPopNext รีเฟรชเมื่อปิด dialog เตือนแพ้
      _suppressNextDidPopNextRefresh = true;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AllergyWarningDialog(
          recipe: r,
          badIngredientNames: badNames, //   ส่งชื่อเข้า dialog
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
    _suppressNextDidPopNextRefresh =
        true; // กลับมาจะไม่รีเฟรชทับก่อนเราอัปเดตฟิลเตอร์

    // รวม group เดี่ยว (_group) เข้ากับลิสต์ที่จะส่งไปหน้า Filter
    final includeGroupsArg = <String>{
      if (_group != null) _group!, // กลุ่มที่ติดมาจากการ์ด
      ..._includeGroupNames, // กลุ่มที่ผู้ใช้เลือกไว้ก่อนหน้า
    }.toList();

    final result = await Navigator.pushNamed(
      context,
      '/ingredient_filter',
      arguments: {
        'initialInclude': _includeNames,
        'initialExclude': _excludeNames,
        'initialIncludeGroups': includeGroupsArg, // 👈 ส่งอันที่รวมแล้ว
        'initialExcludeGroups': _excludeGroupNames,
      },
    ) as List<dynamic>?; // ← ยอมรับ dynamic แล้วค่อย cast

    if (result != null) {
      // 0,1: ชื่อวัตถุดิบ
      _includeNames = {...(result[0] as List).cast<String>()}.toList();
      _excludeNames = {...(result[1] as List).cast<String>()}.toList();

      // หลังใช้หน้าตัวกรองแล้ว ให้ถือว่าค่าที่กลับมาเป็น "ความจริง" ชุดใหม่
      _group = null; // กันกลุ่มเดี่ยว (ที่เคยมากับ args) โผล่กลับมา

      // 2,3: กลุ่มวัตถุดิบ (ถ้ามี)
      _includeGroupNames
        ..clear()
        ..addAll((result.length > 2 ? (result[2] as List) : const [])
            .cast<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty));

      _excludeGroupNames
        ..clear()
        ..addAll((result.length > 3 ? (result[3] as List) : const [])
            .cast<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty));

      // ยิงค้นหาทันที (ไม่ต้องรีเฟรชเอง)
      await _performSearch();
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
            Text('วิธีใช้งานการค้นหา', style: tt.titleLarge),
            const SizedBox(height: 16),
            dot('พิมพ์คำค้นแล้วกดปุ่มค้นหาบนคีย์บอร์ด'),
            dot('ใช้ปุ่ม “กรอง” เพื่อเลือก/ยกเว้นวัตถุดิบ'),
            dot('แตะ ✕ เพื่อถอดฟิลเตอร์'),
            dot('แตะการ์ดสูตรเพื่อดูรายละเอียด'),
            dot('ใส่หลายคำคั่นด้วยเว้นวรรคหรือจุลภาค เช่น กุ้ง กระเทียม หรือ กุ้ง,กระเทียม'),
            dot('เริ่มค้นหาด้วย “กลุ่มวัตถุดิบ” ได้จากหน้าแรก: กดการ์ดกลุ่มเพื่อกรองเมนูในกลุ่มนั้นอัตโนมัติ'),
          ],
        ),
      ),
    );
  }

  // ── ★ Inline Empty State (แทน dialog เดิม) ──────────────────────────
  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_hasGroupFilter) {
      final label = _group ??
          (_includeGroupNames.isNotEmpty
              ? _includeGroupNames.first
              : (_excludeGroupNames.isNotEmpty
                  ? _excludeGroupNames.first
                  : 'กลุ่มที่เลือก'));
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sentiment_dissatisfied_outlined,
                    size: 40, color: cs.primary),
                const SizedBox(height: 8),
                Text('ยังไม่มีสูตรในกลุ่มนี้',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          if (_group != null) {
                            _group = null;
                          } else {
                            _includeGroupNames.clear();
                            _excludeGroupNames.clear();
                          }
                        });
                        _performSearch();
                      },
                      child:
                          Text(_group != null ? 'ลบแท็กนี้' : 'ล้างแท็กกลุ่ม'),
                    ),
                    TextButton(
                      onPressed: _navToFilterScreen,
                      child: const Text('แก้ตัวกรอง'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // กรณีว่างทั่วไป (ไม่มี group filter)
    return const SliverFillRemaining(
      hasScrollBody: false,
      child: Center(child: Text('ไม่พบสูตรอาหารที่ตรงกับเงื่อนไข')),
    );
  }

  // ⛔️ REMOVED: _showEmptyGroupDialog(String) – ไม่ใช้ dialog อีกต่อไป
}
