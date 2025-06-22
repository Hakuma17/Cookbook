import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cookbook/services/auth_service.dart';
import 'package:cookbook/services/api_service.dart';
import 'package:cookbook/widgets/custom_bottom_nav.dart';
import 'package:cookbook/widgets/my_recipe_card.dart';
import 'package:cookbook/widgets/cart_recipe_card.dart';
import 'package:cookbook/widgets/cart_ingredient_list_section.dart';
import '../models/recipe.dart';
import '../models/cart_item.dart';
import '../models/cart_response.dart';
import '../models/cart_ingredient.dart';
import '../main.dart';

class MyRecipesScreen extends StatefulWidget {
  final int initialTab;
  const MyRecipesScreen({Key? key, this.initialTab = 0}) : super(key: key);

  @override
  State<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends State<MyRecipesScreen> with RouteAware {
  // ─────────────────── view-state ────────────────────
  late int _selectedTab; // 0 = favs, 1 = cart
  late Future<List<Recipe>> _futureFavorites;
  List<CartItem> _cartItems = [];
  List<CartIngredient> _cartIngredients = [];
  int _totalCartItems = 0;
  bool _loadingCart = false;

  // ─────────────────── init / dispose ────────────────
  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, 1);
    _futureFavorites = Future.value(<Recipe>[]);
    _refreshFavorites();
    _checkLoginThenLoadCart();
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

  // ─────────────────── route lifecycle ───────────────
  @override
  void didPopNext() {
    if (_selectedTab == 0) {
      _refreshFavorites();
    } else {
      _reloadCartIfLoggedIn();
    }
  }

  // ─────────────────── data loaders ──────────────────
  void _refreshFavorites() {
    setState(() {
      _futureFavorites = _fetchFavoritesSafe();
    });
  }

  Future<List<Recipe>> _fetchFavoritesSafe() async {
    try {
      return await ApiService.fetchFavorites()
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      _showSnack('เซิร์ฟเวอร์ไม่ตอบสนอง ลองใหม่ภายหลัง');
    } on SocketException {
      _showSnack('ไม่มีการเชื่อมต่ออินเทอร์เน็ต');
    } catch (e) {
      _showSnack('โหลดสูตรโปรดไม่สำเร็จ: $e');
    }
    return [];
  }

  Future<void> _checkLoginThenLoadCart() async {
    final ok = await AuthService.checkAndRedirectIfLoggedOut(context);
    if (ok) await _loadCartData();
  }

  Future<void> _reloadCartIfLoggedIn() async {
    final ok = await AuthService.isLoggedIn();
    if (ok) await _loadCartData();
  }

  Future<void> _loadCartData() async {
    if (_loadingCart) return;
    setState(() => _loadingCart = true);

    try {
      final CartResponse cartData =
          await ApiService.fetchCartData().timeout(const Duration(seconds: 10));
      final List<CartIngredient> ings = await ApiService.fetchCartIngredients()
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      setState(() {
        _cartItems = cartData.items;
        _totalCartItems = cartData.totalItems;
        _cartIngredients = ings;
      });
    } on TimeoutException {
      _showSnack('เซิร์ฟเวอร์ไม่ตอบสนอง ลองใหม่ภายหลัง');
    } on SocketException {
      _showSnack('ไม่มีการเชื่อมต่ออินเทอร์เน็ต');
    } catch (e) {
      _showSnack('โหลดตะกร้าไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _loadingCart = false);
    }
  }

  // ─────────────────── helpers ───────────────────────
  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─────────────────── build ─────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _selectedTab == 1
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFFFF9B05),
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'คลังของฉัน',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildTabButton('สูตรโปรดของฉัน', 0),
                _buildTabButton('ตะกร้าวัตถุดิบ', 1),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _selectedTab == 0
                    ? _buildFavoritesView()
                    : _buildCartView(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: 2,
        isLoggedIn: true,
        onItemSelected: (i) async {
          if (i == 2) {
            _selectedTab == 0
                ? _refreshFavorites()
                : await _reloadCartIfLoggedIn();
            return;
          }
          if (i == 1) {
            Navigator.pushReplacementNamed(context, '/search');
          } else if (i == 3) {
            Navigator.pushReplacementNamed(context, '/profile');
          } else {
            Navigator.pushReplacementNamed(context, '/home');
          }
        },
      ),
    );
  }

  // ─────────────────── widgets ───────────────────────
  Widget _buildTabButton(String label, int index) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedTab == index) return;
          setState(() => _selectedTab = index);
          index == 0 ? _refreshFavorites() : _reloadCartIfLoggedIn();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: 2,
                color: selected ? const Color(0xFFFF9B05) : Colors.transparent,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: selected ? const Color(0xFFFF9B05) : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFavoritesView() {
    return FutureBuilder<List<Recipe>>(
      future: _futureFavorites,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดสูตรโปรด'));
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return const Center(child: Text('ยังไม่มีสูตรโปรด'));
        }
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.74,
          ),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final r = list[i];
            return MyRecipeCard(
              recipe: r,
              onTap: () async {
                if (r.hasAllergy) {
                  final confirm = await _confirmAllergy(r.name);
                  if (confirm != true) return;
                }
                if (!mounted) return;
                Navigator.pushNamed(context, '/recipe_detail', arguments: r);
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
      padding: const EdgeInsets.only(top: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─────────────────── cart helpers ──────────────────
  Future<void> _editServings(CartItem item) async {
    final int? newS = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => ServingsPicker(initialServings: item.nServings.round()),
    );
    if (newS == null || newS == item.nServings.round()) return;

    try {
      await ApiService.updateCart(item.recipeId, newS.toDouble());
      await _loadCartData();
    } catch (e) {
      _showSnack('แก้ไขจำนวนไม่สำเร็จ: $e');
    }
  }

  Future<void> _deleteItem(CartItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันลบเมนู'),
        content: Text('ต้องการลบ "${item.name}" ไหม?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ApiService.removeCartItem(item.recipeId);
      await _loadCartData();
    } catch (e) {
      _showSnack('ลบเมนูไม่สำเร็จ: $e');
    }
  }

  Future<void> _addNewCartItem() async {
    final logged = await AuthService.checkAndRedirectIfLoggedOut(context);
    if (!logged) return;

    List<Recipe> favs = [];
    try {
      favs = await ApiService.fetchFavorites()
          .timeout(const Duration(seconds: 10));
    } catch (_) {}

    if (favs.isEmpty) {
      _showSnack('ยังไม่มีสูตรโปรดให้เพิ่ม');
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
      _showSnack('เพิ่มสูตรลงตะกร้าเรียบร้อย');
    } catch (e) {
      _showSnack('เพิ่มไม่สำเร็จ: $e');
    }
  }

  Future<bool?> _confirmAllergy(String recipeName) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('ข้อควรระวัง'),
          ],
        ),
        content: Text(
            'เมนู "$recipeName" มีวัตถุดิบที่คุณกำหนดว่าแพ้\n\nยืนยันที่จะเลือกเมนูนี้หรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ตกลง')),
        ],
      ),
    );
  }
}

// ─────────────────── picker ──────────────────────────
class ServingsPicker extends StatelessWidget {
  final int initialServings;
  const ServingsPicker({Key? key, required this.initialServings})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
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
              return ListTile(
                title: Text(
                  '$s คน',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: s == initialServings
                        ? FontWeight.w700
                        : FontWeight.w400,
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
