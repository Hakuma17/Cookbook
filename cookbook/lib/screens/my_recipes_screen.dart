// lib/screens/my_recipes_screen.dart
//
// ปรับกริดการ์ดให้เท่ากันทุกใบ + ลดพื้นที่ขาวล่าง
// + โหมดเลือกหลายรายการ (แท็บสูตรโปรด)
// + โหมดสลับหน่วยแสดงผลในตะกร้าวัตถุดิบ (หน่วยเดิม/กรัม)
// + แก้ error PopScope.onPopInvokedWithResult / RouteAware cast
// + กัน overflow ด้วย SafeArea/ConstrainedBox/PageStorageKey/Scrollbar
// + FIX: ปุ่มแท็บและแถบโหมดเลือกป้องกัน RenderFlex overflow ด้านขวา

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ★ หน่วยแสดงผล
import '../stores/favorite_store.dart';

import 'package:cookbook/services/auth_service.dart';
import 'package:cookbook/services/api_service.dart';
import 'package:cookbook/widgets/custom_bottom_nav.dart';
import 'package:cookbook/widgets/my_recipe_card.dart';
import 'package:cookbook/widgets/cart_recipe_card.dart';
import 'package:cookbook/widgets/cart_ingredient_list_section.dart';

import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/cart_item.dart';
import '../models/cart_response.dart';
import '../models/cart_ingredient.dart';
import '../models/unit_display_mode.dart'; // ★ หน่วยแสดงผล
import '../widgets/allergy_warning_dialog.dart';
import '../main.dart';

/* ───────────── Grid constants ───────────── */
const double _kGridHPad = 16.0; // ซ้าย/ขวา
const double _kGridSpacing = 12.0; // ระยะห่างการ์ด
const double _kHeaderHPad = 20.0; // padding หัวข้อ
const int _kGridColumns = 2; // ล็อค 2 คอลัมน์

class MyRecipesScreen extends StatefulWidget {
  final int initialTab;
  const MyRecipesScreen({super.key, this.initialTab = 0});

  @override
  State<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends State<MyRecipesScreen> with RouteAware {
  /* ────────── View/State ────────── */
  late int _selectedTab; // 0=favorites, 1=cart

  // Favorites
  late Future<List<Recipe>> _futureFavorites;

  // Cart
  List<CartItem> _cartItems = [];
  List<CartIngredient> _cartIngredients = [];
  bool _loadingCart = true;

  // Allergy
  List<Ingredient> _allergyList = [];

  // Login
  bool _isLoggedIn = false;

  // Init
  late Future<void> _initFuture;

  // ★ โหมดหน่วยใน “ตะกร้าวัตถุดิบ”
  static const _kUnitModeKey = 'cart_unit_mode';
  UnitDisplayMode _cartUnitMode = UnitDisplayMode.original;

  // ★ Selection Mode (สูตรโปรดของฉัน)
  bool _selectionMode = false;
  final Set<int> _selectedIds = <int>{};

  /* ────────── INIT ────────── */
  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, 1);
    _futureFavorites = Future.value(<Recipe>[]);
    _initFuture = _initialize();
    _loadUnitMode(); // โหลดโหมดหน่วยที่เลือกไว้
  }

  Future<void> _loadUnitMode() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kUnitModeKey);
    if (!mounted) return;
    setState(() {
      _cartUnitMode =
          raw == 'grams' ? UnitDisplayMode.grams : UnitDisplayMode.original;
    });
  }

  Future<void> _saveUnitMode(UnitDisplayMode m) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      _kUnitModeKey,
      m == UnitDisplayMode.grams ? 'grams' : 'original',
    );
  }

  Future<void> _initialize({bool forceRefresh = false}) async {
    try {
      final results = await Future.wait([
        AuthService.isLoggedIn(),
        ApiService.fetchAllergyIngredients(),
      ]);

      if (mounted) {
        setState(() {
          _isLoggedIn = results[0] as bool;
          _allergyList = results[1] as List<Ingredient>;
        });
      }

      if (_selectedTab == 0) {
        await _loadFavorites();
      } else {
        await _loadCartData(force: forceRefresh);
      }
    } on UnauthorizedException {
      await _handleLogout();
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack('เกิดข้อผิดพลาดที่ไม่รู้จัก');
    }
  }

  Future<void> _handleLogout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ★ ป้องกัน cast ผิดชนิด (บางครั้ง ModalRoute ไม่ใช่ PageRoute)
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // ★ เรียก refresh เมื่อกลับมาหน้านี้
    setState(() {
      _initFuture = _initialize(forceRefresh: true);
    });
  }

  /* ────────── Favorites ────────── */
  Future<void> _loadFavorites() async {
    setState(() {
      _futureFavorites = ApiService.fetchFavorites();
    });
    await _futureFavorites;
  }

  /* ────────── Cart ────────── */
  Future<void> _loadCartData({bool force = false}) async {
    if (_loadingCart && _cartItems.isNotEmpty && !force) return;
    if (mounted) setState(() => _loadingCart = true);

    try {
      final results = await Future.wait([
        ApiService.fetchCartData(),
        ApiService.fetchCartIngredients(),
      ]);

      if (!mounted) return;
      setState(() {
        _cartItems = (results[0] as CartResponse).items;
        _cartIngredients = results[1] as List<CartIngredient>;
      });
    } finally {
      if (mounted) setState(() => _loadingCart = false);
    }
  }

  /* ────────── Bottom Nav ────────── */
  void _onNavItemTapped(int index) {
    if (index == 2) {
      setState(() {
        _initFuture = _initialize(forceRefresh: true);
      });
      return;
    }

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/search');
        break;
      case 3:
        final route = _isLoggedIn ? '/profile' : '/settings';
        Navigator.pushReplacementNamed(context, route);
        break;
    }
  }

  void _showSnack(String msg, {bool isError = true}) {
    if (!mounted) return;
    final theme = Theme.of(context);
    // ★ กัน SnackBar ซ้อน
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isError ? theme.colorScheme.error : Colors.green[600],
      ));
  }

  /* ────────── BUILD ────────── */
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // ★ ใช้ PopScope.onPopInvoked (เวอร์ชันเสถียร) แทน onPopInvokedWithResult
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_selectionMode) {
          _exitSelection();
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        floatingActionButton: _selectedTab == 1
            ? FloatingActionButton.extended(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                icon: const Icon(Icons.add),
                label: const Text('เพิ่มรายการใหม่'),
                onPressed: _addNewCartItem,
              )
            : null,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // ส่วนหัวเดิม + แท็บ  ❮คงไว้❯  แต่สลับเป็นแถบ “โหมดเลือก” เมื่อ _selectionMode=true
              if (!(_selectionMode && _selectedTab == 0)) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _kHeaderHPad),
                  child: Text(
                    'คลังของฉัน',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _kHeaderHPad),
                  child: Row(
                    children: [
                      _buildTabButton('สูตรโปรดของฉัน', 0, theme),
                      _buildTabButton('ตะกร้าวัตถุดิบ', 1, theme),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ] else ...[
                // ★★★ แถบเครื่องมือของโหมดเลือก
                _buildSelectionBar(theme),
              ],

              Expanded(
                child: FutureBuilder(
                  future: _initFuture,
                  builder: (_, snap) {
                    if (snap.connectionState == ConnectionState.waiting &&
                        _cartItems.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                          child: Text('เกิดข้อผิดพลาด: ${snap.error}'));
                    }

                    return RefreshIndicator(
                      onRefresh: () => _initialize(forceRefresh: true),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        // ⬇️ ใส่คีย์คงที่ให้ child ของแต่ละแท็บ (กัน remount ที่ทำให้ state ภายในหาย)
                        child: _selectedTab == 0
                            ? KeyedSubtree(
                                key: const ValueKey('tab-fav'),
                                child: _buildFavoritesView(),
                              )
                            : KeyedSubtree(
                                key: const ValueKey('tab-cart'),
                                child: _buildCartView(),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: CustomBottomNav(
          selectedIndex: 2,
          onItemSelected: _onNavItemTapped,
          isLoggedIn: _isLoggedIn,
        ),
      ),
    );
  }

  /* ────────── UI helpers ────────── */
  Widget _buildTabButton(String label, int index, ThemeData theme) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (_selectedTab == index) return;
          setState(() {
            _exitSelection(); // ออกจากโหมดเลือกเมื่อสลับแท็บ
            _selectedTab = index;
            _initFuture = _initialize();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: 2.5,
                color:
                    isSelected ? theme.colorScheme.primary : Colors.transparent,
              ),
            ),
          ),
          // ⬇️ FIX overflow: ย่อฟอนต์อัตโนมัติ + ellipsis
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // แถบเครื่องมือของโหมดเลือก (ปุ่ม: ยกเลิก / เลือกทั้งหมด / ลบ)
  Widget _buildSelectionBar(ThemeData theme) {
    return FutureBuilder<List<Recipe>>(
      future: _futureFavorites,
      builder: (context, snapshot) {
        final bool isLoading =
            snapshot.connectionState != ConnectionState.done ||
                !snapshot.hasData;
        final list = snapshot.data ?? const <Recipe>[];
        final bool isAllSelected =
            _selectedIds.length == list.length && list.isNotEmpty;

        return Padding(
          padding: const EdgeInsets.fromLTRB(
              12, 12, 12, 6), // ลด padding เพื่อกันล้น
          child: Row(
            children: [
              IconButton(
                tooltip: 'ยกเลิก',
                icon: const Icon(Icons.close),
                onPressed: _exitSelection,
              ),
              // ใช้ Flexible แทน Expanded เพื่อให้ Text ยืด/หดได้
              Flexible(
                child: Text(
                  isLoading
                      ? 'เลือกไว้ ${_selectedIds.length}'
                      : 'เลือกไว้ ${_selectedIds.length}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip:
                    isAllSelected ? 'ยกเลิกการเลือกทั้งหมด' : 'เลือกทั้งหมด',
                icon: Icon(isAllSelected ? Icons.clear : Icons.checklist),
                onPressed: isLoading ? null : () => _toggleSelectAll(list),
              ),
              IconButton(
                tooltip: 'ลบ',
                icon: const Icon(Icons.delete_outline),
                onPressed:
                    _selectedIds.isEmpty ? null : _deleteSelectedFavorites,
              ),
            ],
          ),
        );
      },
    );
  }

  /* ────────── FAVORITES VIEW ────────── */
  Widget _buildFavoritesView() {
    return FutureBuilder<List<Recipe>>(
      future: _futureFavorites,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'เกิดข้อผิดพลาด: ${snap.error is ApiException ? (snap.error as ApiException).message : snap.error}',
            ),
          );
        }

        final list = snap.data ?? [];
        if (list.isEmpty) {
          return const AlwaysScrollableScrollPhysicsWrapper(
            child: Center(child: Text('ยังไม่มีสูตรโปรด')),
          );
        }

        // ล็อค 2 คอลัมน์ + คำนวณสัดส่วนจริงให้การ์ด “เต็มพอดี” ไม่เหลือพื้นขาวล่าง
        final bottomSafe = MediaQuery.of(context).padding.bottom;
        final ratio = _calcCardAspectRatio(context);

        return Scrollbar(
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(
              _kGridHPad,
              8,
              _kGridHPad,
              10 + bottomSafe,
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            cacheExtent: 800,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _kGridColumns,
              mainAxisSpacing: _kGridSpacing,
              crossAxisSpacing: _kGridSpacing,
              childAspectRatio: ratio,
            ),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final r = list[i];
              final updatedRecipe = r.copyWith(
                hasAllergy: _checkIfRecipeHasAllergy(r),
              );

              // โหมดเลือกหลายรายการ
              final bool selected = _selectedIds.contains(updatedRecipe.id);

              final card = GestureDetector(
                onLongPress: () => _enterSelection(updatedRecipe),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: _selectionMode && !selected ? 0.6 : 1.0,
                  child: Semantics(
                    // ★ A11y
                    button: true,
                    label: 'สูตรอาหาร ${updatedRecipe.name}',
                    selected: selected,
                    child: MyRecipeCard(
                      recipe: updatedRecipe,
                      onTap: () {
                        if (_selectionMode) {
                          _toggleSelect(updatedRecipe.id);
                          return;
                        }
                        if (updatedRecipe.hasAllergy) {
                          _showAllergyDialog(updatedRecipe);
                          return;
                        }
                        Navigator.pushNamed(
                          context,
                          '/recipe_detail',
                          arguments: updatedRecipe,
                        );
                      },
                    ),
                  ),
                ),
              );

              return Stack(
                children: [
                  card,
                  if (_selectionMode)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _selectionTick(selected, Theme.of(context)),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // วิดเจ็ตติ๊กถูกมุมการ์ด
  Widget _selectionTick(bool selected, ThemeData theme) {
    final cs = theme.colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: selected ? cs.primary : cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? cs.primary : cs.outlineVariant,
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Icon(
        selected ? Icons.check : Icons.radio_button_unchecked,
        size: 20,
        color: selected ? cs.onPrimary : cs.onSurfaceVariant,
      ),
    );
  }

  /// คำนวณ childAspectRatio จากความกว้างการ์ดจริง
  double _calcCardAspectRatio(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final ts = Theme.of(context).textTheme;
    // ★ MediaQuery.textScaleFactorOf → TextScaler API ใหม่
    final scale = MediaQuery.of(context)
        .textScaler
        .clamp(maxScaleFactor: 1.30)
        .scale(1.0);

    // ความกว้างการ์ดจริง (2 คอลัมน์)
    final cardW =
        (size.width - (_kGridHPad * 2) - _kGridSpacing) / _kGridColumns;

    // สูงส่วนรูป (4:3) — ต้องตรงกับ MyRecipeCard (AspectRatio 4/3)
    final imageH = cardW * (3 / 4);

    double lineH(TextStyle? s, double fallback) =>
        ((s?.height ?? 1.22) * (s?.fontSize ?? fallback)) * scale;

    // สูงเนื้อหาใต้รูป: ชื่อ 2 บรรทัด (titleMedium), meta 1 แถว (bodyMedium), padding ภายในการ์ด
    final titleH = lineH(ts.titleMedium, 16) * 2;
    final metaH = lineH(ts.bodyMedium, 14);
    const innerPadding = 8 + 2 + 8;
    final contentH = titleH + metaH + innerPadding;

    final cardH = imageH + contentH;
    final ratio = cardW / cardH;

    // เผื่อกรณีปรับขนาดฟอนต์ระบบ → บีบให้อยู่ในช่วงที่ดูพอดี
    return ratio.clamp(0.76, 0.84);
  }

  /* ────────── CART VIEW ────────── */
  Widget _buildCartView() {
    if (_loadingCart) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_cartItems.isEmpty) {
      return const AlwaysScrollableScrollPhysicsWrapper(
        child: Center(child: Text('ยังไม่มีรายการในตะกร้า')),
      );
    }

    return Scrollbar(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ★ ใช้ความสูงคงที่ + ListView.separated แนวนอน เพื่อลดโอกาส overflow แนวตั้ง
            SizedBox(
              height: 256,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(16),
                itemCount: _cartItems.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (_, i) => CartRecipeCard(
                  cartItem: _cartItems[i],
                  onTapEditServings: () => _editServings(_cartItems[i]),
                  onDelete: () => _deleteItem(_cartItems[i]),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ส่งโหมด + callback ไปยัง Section
            CartIngredientListSection(
              key: const PageStorageKey(
                  'cart-ingredient-list'), // ★ กันรีสร้างและจำ state ภายใน
              ingredients: _cartIngredients,
              unitMode: _cartUnitMode,
              onUnitModeChanged: (m) async {
                setState(() => _cartUnitMode = m);
                await _saveUnitMode(m);
              },
            ),

            const SizedBox(height: 72), // ★ เผื่อพื้นที่ FAB/BottomNav
          ],
        ),
      ),
    );
  }

  /* ────────── Helpers ────────── */
  bool _checkIfRecipeHasAllergy(Recipe recipe) {
    final allergyIds = _allergyList.map((e) => e.id).toSet();
    return allergyIds.isNotEmpty &&
        recipe.ingredientIds.any(allergyIds.contains);
  }

  void _showAllergyDialog(Recipe recipe) {
    final allergyIds = _allergyList.map((e) => e.id).toSet();
    final badIds = recipe.ingredientIds.where(allergyIds.contains).toSet();
    final badNames = _allergyList
        .where((ing) => badIds.contains(ing.id))
        .map((ing) => ing.name)
        .toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AllergyWarningDialog(
        recipe: recipe,
        badIngredientNames: badNames,
        onConfirm: (r) {
          Navigator.of(ctx).pop();
          Navigator.of(ctx).pushNamed('/recipe_detail', arguments: r);
        },
      ),
    );
  }

  Future<void> _editServings(CartItem item) async {
    final int? newServings = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => ServingsPicker(initialServings: item.nServings.round()),
    );
    if (newServings == null || newServings == item.nServings.round()) return;

    try {
      await ApiService.updateCart(item.recipeId, newServings.toDouble());
      await _loadCartData(force: true);
    } on ApiException catch (e) {
      _showSnack('แก้ไขจำนวนไม่สำเร็จ: ${e.message}');
    }
  }

  Future<void> _deleteItem(CartItem item) async {
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันลบเมนู'),
        content: Text('ต้องการลบ "${item.name}" ออกจากตะกร้าใช่ไหม?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('ลบ', style: TextStyle(color: theme.colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ApiService.removeCartItem(item.recipeId);
      await _loadCartData(force: true);
    } on ApiException catch (e) {
      _showSnack('ลบเมนูไม่สำเร็จ: ${e.message}');
    }
  }

  Future<void> _addNewCartItem() async {
    List<Recipe> favs = [];
    try {
      favs = await ApiService.fetchFavorites();
    } on ApiException catch (e) {
      _showSnack(e.message);
      return;
    }

    if (favs.isEmpty) {
      _showSnack('ยังไม่มีสูตรโปรดให้เพิ่มลงตะกร้า', isError: false);
      return;
    }

    if (!mounted) return;
    final Recipe? selected = await showModalBottomSheet<Recipe>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          children: favs
              .map((r) => ListTile(
                    title: Text(r.name),
                    onTap: () => Navigator.of(ctx).pop(r),
                  ))
              .toList(),
        ),
      ),
    );
    if (!mounted) return;
    if (selected == null) return;

    final int? servings = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => const ServingsPicker(initialServings: 1),
    );
    if (!mounted) return;
    if (servings == null) return;

    try {
      await ApiService.addCartItem(selected.id, servings.toDouble());
      await _loadCartData(force: true);
      _showSnack('เพิ่ม "${selected.name}" ลงตะกร้าเรียบร้อย', isError: false);
    } on ApiException catch (e) {
      _showSnack('เพิ่มสูตรไม่สำเร็จ: ${e.message}');
    }
  }

  // ───────── Selection Mode helpers ─────────
  void _enterSelection(Recipe r) {
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..add(r.id);
    });
  }

  void _toggleSelect(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelectAll(List<Recipe> list) {
    final allIds = list.map((e) => e.id).toSet();
    setState(() {
      _selectionMode = true;
      if (_selectedIds.length == allIds.length) {
        // ★ เลือกครบอยู่แล้ว → เคลียร์เป็น “ยกเลิกทั้งหมด”
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(allIds);
      }
    });
  }

  Future<void> _deleteSelectedFavorites() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันลบรายการที่เลือก'),
        content: Text(
            'ต้องการเอาออกจาก “สูตรโปรดของฉัน” จำนวน ${_selectedIds.length} รายการหรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ลบ')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      // ยิง API ทีละ id (ถ้า backend ไม่มี batch)
      await Future.wait(
          _selectedIds.map((id) => ApiService.toggleFavorite(id, false)));

      if (!mounted) return;
      await context.read<FavoriteStore>().removeMany(_selectedIds);
      await _loadFavorites();
      _showSnack('ลบ ${_selectedIds.length} รายการแล้ว', isError: false);
    } catch (_) {
      if (!mounted) return;
      _showSnack('ลบรายการไม่สำเร็จ');
    } finally {
      _exitSelection();
    }
  }
}

/* ให้สกอร์ลได้เสมอ เผื่อรายการน้อย */
class AlwaysScrollableScrollPhysicsWrapper extends StatelessWidget {
  final Widget child;
  const AlwaysScrollableScrollPhysicsWrapper({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        // ★ บังคับให้สูงอย่างน้อย ~60% หน้าจอ เพื่อลาก Refresh ได้และกัน overflow แปลก ๆ
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height * .6,
        ),
        child: child,
      ),
    );
  }
}

/* ─────────────────── PICKER ─────────────────── */
class ServingsPicker extends StatelessWidget {
  final int initialServings;
  const ServingsPicker({super.key, required this.initialServings});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final maxHeight = MediaQuery.of(context).size.height * 0.5;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: 10,
            itemBuilder: (_, i) {
              final s = i + 1;
              final isSelected = s == initialServings;
              return ListTile(
                title: Text(
                  '$s คน',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onTap: () => Navigator.pop(context, s),
              );
            },
          ),
        ),
      ),
    );
  }
}
