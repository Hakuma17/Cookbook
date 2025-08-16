// lib/screens/my_recipes_screen.dart
//
// ปรับกริดการ์ดให้เท่ากันทุกใบ + ลดพื้นที่ขาวล่าง
// - ล็อค 2 คอลัมน์
// - คำนวณ childAspectRatio ตามความกว้างการ์ดจริง (สอดคล้อง MyRecipeCard)
// - ปรับช่องไฟ/ขอบให้พอดีตา
//
// ★★★ [NEW] เพิ่ม “โหมดเลือกหลายรายการ” ในแท็บ “สูตรโปรดของฉัน”
// - กดค้างที่การ์ดเพื่อเข้าโหมดเลือก
// - แตะที่การ์ดเพื่อเลือก/ยกเลิกเลือก
// - มีแถบเครื่องมือ (ยกเลิก, เลือกทั้งหมด, ลบ)
// - โค้ดเดิมยังคงไว้ทั้งหมด (เฉพาะส่วนที่ต้องเพิ่มมีคอมเมนต์ [NEW])

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  // ────────────────────────────────────────────────────────
  // ★★★ [NEW] Selection Mode (เลือกหลายใบใน “สูตรโปรดของฉัน”)
  bool _selectionMode = false; // อยู่ในโหมดเลือกหรือไม่
  final Set<int> _selectedIds = <int>{}; // ids ที่ถูกเลือก
  // ────────────────────────────────────────────────────────

  /* ────────── INIT ────────── */
  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, 1);
    _futureFavorites = Future.value(<Recipe>[]);
    _initFuture = _initialize(); // โหลดรอบแรก
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
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
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
    // ★ [NEW] กัน SnackBar ซ้อน
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

    // ★ [NEW] Back = ออกจากโหมดเลือกก่อน
    return WillPopScope(
      onWillPop: () async {
        if (_selectionMode) {
          _exitSelection();
          return false;
        }
        return true;
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

              // ─────────────────────────────────────────────────────────
              // ส่วนหัวเดิม + แท็บ  ❮คงไว้❯  แต่สลับเป็นแถบ “โหมดเลือก” เมื่อ _selectionMode=true
              // ─────────────────────────────────────────────────────────
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
                const SizedBox(height: 18),
                Row(
                  children: [
                    _buildTabButton('สูตรโปรดของฉัน', 0, theme),
                    _buildTabButton('ตะกร้าวัตถุดิบ', 1, theme),
                  ],
                ),
                const SizedBox(height: 6),
              ] else ...[
                // ★★★ [NEW] แถบเครื่องมือของโหมดเลือก
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
                        child: _selectedTab == 0
                            ? _buildFavoritesView()
                            : _buildCartView(),
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
            // ★★ ออกจากโหมดเลือกเมื่อสลับแท็บ
            _exitSelection();
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
          child: Text(
            label,
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
    );
  }

  // ★★★ [NEW] แถบเครื่องมือตอนโหมดเลือก (ปุ่ม: ยกเลิก / เลือกทั้งหมด / ลบ)
  Widget _buildSelectionBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_kHeaderHPad, 12, _kHeaderHPad, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'ยกเลิก',
            icon: const Icon(Icons.close),
            onPressed: _exitSelection,
          ),
          Text(
            'เลือกไว้ ${_selectedIds.length}',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'เลือกทั้งหมด',
            icon: const Icon(Icons.select_all),
            onPressed: () async {
              final list = await _futureFavorites;
              _toggleSelectAll(
                  list); // ★ NEW: เลือกทั้งหมด/ยกเลิกทั้งหมด ตามสถานะ
            },
          ),
          IconButton(
            tooltip: 'ลบ',
            icon: const Icon(Icons.delete_outline),
            onPressed: _selectedIds.isEmpty
                ? null // ★ NEW: disabled ถ้าไม่มีที่เลือก
                : _deleteSelectedFavorites,
          ),
        ],
      ),
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

        // ✅ ล็อค 2 คอลัมน์ + คำนวณสัดส่วนจริงให้การ์ด “เต็มพอดี” ไม่เหลือพื้นขาวล่าง
        final bottomSafe = MediaQuery.of(context).padding.bottom;
        final ratio = _calcCardAspectRatio(context);

        return Scrollbar(
          // ★ NEW: เพิ่ม Scrollbar
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(
              _kGridHPad,
              8,
              _kGridHPad,
              10 + bottomSafe, // NEW: ลดพื้นที่ขาวล่างลง
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            cacheExtent: 800,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _kGridColumns,
              mainAxisSpacing: _kGridSpacing,
              crossAxisSpacing: _kGridSpacing,
              childAspectRatio: ratio, // ~0.76–0.82 ตามจอ/ฟอนต์
            ),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final r = list[i];
              final updatedRecipe = r.copyWith(
                hasAllergy: _checkIfRecipeHasAllergy(r),
              );

              // ★★★ [NEW] โหมดเลือกหลายรายการ
              final bool selected = _selectedIds.contains(updatedRecipe.id);

              final card = GestureDetector(
                onLongPress: () => _enterSelection(updatedRecipe),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: _selectionMode && !selected ? 0.6 : 1.0,
                  child: Semantics(
                    // ★ NEW: A11y
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

  // ★★★ [NEW] วิดเจ็ตติ๊กถูกมุมการ์ด
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
            color: Colors.black.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Icon(
        selected ? Icons.check : Icons.radio_button_unchecked,
        size: 18,
        color: selected ? cs.onPrimary : cs.onSurfaceVariant,
      ),
    );
  }

  /// คำนวณ childAspectRatio จาก “ความกว้างจริงของการ์ด”
  /// สอดคล้องกับ MyRecipeCard: รูป 4:3 + ชื่อ 2 บรรทัด + meta 1 แถว + padding
  double _calcCardAspectRatio(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final ts = Theme.of(context).textTheme;
    final scale = MediaQuery.textScaleFactorOf(context);

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
    const innerPadding = 8 + 2 + 8; // fromLTRB(12,8,12,2) + meta bottom 8
    final contentH = titleH + metaH + innerPadding;

    final cardH = imageH + contentH;
    final ratio = cardW / cardH;

    // NEW: เผื่อกรณีปรับขนาดฟอนต์ระบบ → บีบให้อยู่ในช่วงที่ดูพอดี
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
      // ★ NEW: Scrollbar
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 256, // NEW: เผื่อชื่อ 2 บรรทัด ดูโปร่งไม่อัด
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
            CartIngredientListSection(ingredients: _cartIngredients),
            const SizedBox(height: 72),
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
      builder: (_) => AllergyWarningDialog(
        recipe: recipe,
        badIngredientNames: badNames,
        onConfirm: (r) {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/recipe_detail', arguments: r);
        },
      ),
    );
  }

  Future<void> _editServings(CartItem item) async {
    final int? newServings = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => ServingsPicker(initialServings: item.nServings.round()),
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
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันลบเมนู'),
        content: Text('ต้องการลบ "${item.name}" ออกจากตะกร้าใช่ไหม?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
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

    final Recipe? selected = await showModalBottomSheet<Recipe>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          children: favs
              .map((r) => ListTile(
                    title: Text(r.name),
                    onTap: () => Navigator.pop(_, r),
                  ))
              .toList(),
        ),
      ),
    );
    if (selected == null) return;

    final int? servings = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => const ServingsPicker(initialServings: 1),
    );
    if (servings == null) return;

    try {
      await ApiService.addCartItem(selected.id, servings.toDouble());
      await _loadCartData(force: true);
      _showSnack('เพิ่ม "${selected.name}" ลงตะกร้าเรียบร้อย', isError: false);
    } on ApiException catch (e) {
      _showSnack('เพิ่มสูตรไม่สำเร็จ: ${e.message}');
    }
  }

  // ────────────────────────────────────────────────────────
  // ★★★ [NEW] Selection Mode helpers
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
        // ★ NEW: เลือกครบอยู่แล้ว → เคลียร์เป็น “ยกเลิกทั้งหมด”
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
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันลบรายการที่เลือก'),
        content: Text(
            'ต้องการเอาออกจาก “สูตรโปรดของฉัน” จำนวน ${_selectedIds.length} รายการหรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ลบ')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      // ยิง API ทีละ id (ถ้า backend ไม่มี batch)
      await Future.wait(
          _selectedIds.map((id) => ApiService.toggleFavorite(id, false)));

      // 🔴 สำคัญ: แจ้งให้ทุกหน้าทราบว่ารายการโปรดเปลี่ยนแล้ว
      await context.read<FavoriteStore>().removeMany(_selectedIds); // ⬅️ สำคัญ

      await _loadFavorites(); // รีเฟรชลิสต์ในหน้านี้
      _showSnack('ลบ ${_selectedIds.length} รายการแล้ว', isError: false);
    } catch (_) {
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
