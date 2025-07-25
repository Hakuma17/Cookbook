import 'dart:async';

import 'package:flutter/material.dart';
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

class MyRecipesScreen extends StatefulWidget {
  final int initialTab;
  const MyRecipesScreen({super.key, this.initialTab = 0});

  @override
  State<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends State<MyRecipesScreen> with RouteAware {
  // ────────── view/state ──────────
  late int _selectedTab;

  // State for Favorites Tab
  late Future<List<Recipe>> _futureFavorites;

  // State for Cart Tab
  List<CartItem> _cartItems = [];
  List<CartIngredient> _cartIngredients = [];
  bool _loadingCart = true;

  // State for Allergy data
  List<Ingredient> _allergyList = [];

  // ✅ 1. จัดการ State การโหลดเริ่มต้นด้วย Future เดียว
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, 1);
    _futureFavorites = Future.value(<Recipe>[]); // ค่าเริ่มต้น
    _initFuture = _initialize();
  }

  // ✅ 2. รวม Logic การโหลดข้อมูลเริ่มต้นไว้ในที่เดียว
  Future<void> _initialize({bool forceRefresh = false}) async {
    try {
      // โหลดข้อมูลที่จำเป็นเสมอ (เช่น ข้อมูลแพ้)
      final allergies = await ApiService.fetchAllergyIngredients();
      if (mounted) setState(() => _allergyList = allergies);

      // โหลดข้อมูลตาม Tab ที่เลือก
      if (_selectedTab == 0) {
        await _loadFavorites();
      } else {
        await _loadCartData();
      }
    } on UnauthorizedException {
      await _handleLogout();
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (e) {
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
    // เมื่อกลับมาหน้านี้ ให้โหลดข้อมูลใหม่
    setState(() {
      _initFuture = _initialize(forceRefresh: true);
    });
  }

  // ──────────── favorite ────────────
  Future<void> _loadFavorites() async {
    setState(() {
      // ✅ 3. ปรับปรุง Error Handling ให้รองรับ Custom Exception
      _futureFavorites = ApiService.fetchFavorites();
    });
    // ให้ FutureBuilder จัดการ Error เอง
    await _futureFavorites;
  }

  // ──────────── cart ────────────
  Future<void> _loadCartData() async {
    if (_loadingCart && _cartItems.isNotEmpty) return;
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

  void _showSnack(String msg, {bool isError = true}) {
    if (!mounted) return;
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? theme.colorScheme.error : Colors.green[600],
    ));
  }

  // ─────────── build ───────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      floatingActionButton: _selectedTab == 1
          ? FloatingActionButton.extended(
              // ✅ 4. ใช้สีจาก Theme ส่วนกลาง
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
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'คลังของฉัน',
                // ✅ ใช้สไตล์จาก Theme ส่วนกลาง
                style: textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildTabButton('สูตรโปรดของฉัน', 0, theme),
                _buildTabButton('ตะกร้าวัตถุดิบ', 1, theme),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder(
                  future: _initFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        _cartItems.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                          child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
                    }

                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _selectedTab == 0
                          ? _buildFavoritesView()
                          : _buildCartView(),
                    );
                  }),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: 2,
        onItemSelected: (i) {
          if (i == 2) {
            setState(() {
              _initFuture = _initialize(forceRefresh: true);
            });
            return;
          }
          const routes = ['/home', '/search', null, '/profile'];
          if (routes[i] != null)
            Navigator.pushReplacementNamed(context, routes[i]!);
        },
      ),
    );
  }

  Widget _buildTabButton(String label, int index, ThemeData theme) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (_selectedTab == index) return;
          setState(() {
            _selectedTab = index;
            // เมื่อสลับ Tab ให้โหลดข้อมูลใหม่
            _initFuture = _initialize();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
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

  // ✅ 5. ปรับปรุง Grid View ให้เป็น Responsive อัตโนมัติ
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
                'เกิดข้อผิดพลาด: ${snap.error is ApiException ? (snap.error as ApiException).message : snap.error}'),
          );
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return const Center(child: Text('ยังไม่มีสูตรโปรด'));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.74,
          ),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final r = list[i];

            // ---  จุดที่แก้ไข  ---
            // ของเดิมที่ Error:
            // r.hasAllergy = _checkIfRecipeHasAllergy(r);

            // ของใหม่ที่ถูกต้อง:
            // สร้าง object ใหม่ด้วย copyWith
            final updatedRecipe = r.copyWith(
              hasAllergy: _checkIfRecipeHasAllergy(r),
            );
            // -------------------------

            return MyRecipeCard(
              // ใช้ object ใหม่ที่อัปเดตแล้ว
              recipe: updatedRecipe,
              onTap: () {
                // ใช้ object ใหม่ในการเช็ค
                if (updatedRecipe.hasAllergy) {
                  _showAllergyDialog(updatedRecipe);
                  return;
                }
                Navigator.pushNamed(context, '/recipe_detail',
                    arguments: updatedRecipe);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCartView() {
    if (_loadingCart) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_cartItems.isEmpty) {
      return const Center(child: Text('ยังไม่มีรายการในตะกร้า'));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 240, // กำหนดความสูงที่เหมาะสม
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
          const SizedBox(height: 24),
          CartIngredientListSection(ingredients: _cartIngredients),
          const SizedBox(height: 80), // เว้นที่สำหรับ FAB
        ],
      ),
    );
  }

  // ─────────── helpers ──────────
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
      await _loadCartData();
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
      await _loadCartData();
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
                  title: Text(r.name), onTap: () => Navigator.pop(_, r)))
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
      await _loadCartData();
      _showSnack('เพิ่ม "${selected.name}" ลงตะกร้าเรียบร้อย', isError: false);
    } on ApiException catch (e) {
      _showSnack('เพิ่มสูตรไม่สำเร็จ: ${e.message}');
    }
  }
}

// ─────────────────── picker ──────────────────────────
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
                  '$s ที่',
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
