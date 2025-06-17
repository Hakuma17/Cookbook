// lib/screens/my_recipes_screen.dart

import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../models/cart_item.dart';
import '../models/cart_response.dart';
import '../models/cart_ingredient.dart';
import '../services/api_service.dart';

import '../widgets/my_recipe_card.dart'; // สูตรโปรด
import '../widgets/cart_recipe_card.dart'; // การ์ดในตะกร้า
import '../widgets/cart_ingredient_list_section.dart'; // รายการวัตถุดิบ
import '../widgets/custom_bottom_nav.dart'; // bottom bar

/// หน้าจอ “คลังของฉัน”
/// - แท็บ 0: สูตรโปรดของฉัน (GridView)
//   - แตะการ์ด → รายละเอียด
/// - แท็บ 1: ตะกร้าวัตถุดิบ
///   - เลื่อนการ์ดสูตร (horizontal)
///   - รายการวัตถุดิบ (widget แยก)
class MyRecipesScreen extends StatefulWidget {
  final int initialTab;
  const MyRecipesScreen({Key? key, this.initialTab = 0}) : super(key: key);

  @override
  State<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends State<MyRecipesScreen> {
  late int _selectedTab;
  late Future<List<Recipe>> _futureFavorites;

  List<CartItem> _cartItems = [];
  List<CartIngredient> _cartIngredients = [];
  int _totalCartItems = 0;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _loadData();
  }

  /// ดึงสูตรโปรด (FutureBuilder) และข้อมูลตะกร้า (items + ingredients)
  Future<void> _loadData() async {
    try {
      _futureFavorites = ApiService.fetchFavorites();
      final CartResponse cartData = await ApiService.fetchCartData();
      final List<CartIngredient> ings = await ApiService.fetchCartIngredients();
      setState(() {
        _cartItems = cartData.items;
        _totalCartItems = cartData.totalItems;
        _cartIngredients = ings;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดตะกร้าไม่สำเร็จ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // FAB แสดงเฉพาะแท็บ Cart
      floatingActionButton: _selectedTab == 1
          ? FloatingActionButton.extended(
              onPressed: _addNewCartItem,
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มรายการใหม่'),
              backgroundColor: const Color(0xFFFF9B05),
            )
          : null,

      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'คลังของฉัน',
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Tab buttons
            Row(
              children: [
                _buildTabButton('สูตรโปรดของฉัน', 0),
                _buildTabButton('ตะกร้าวัตถุดิบ', 1),
              ],
            ),
            const SizedBox(height: 12),

            // Content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _selectedTab == 0
                    ? _buildFavoritesView()
                    : _buildCartView(),
              ),
            ),
          ],
        ),
      ),

      // Bottom nav
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: 2,
        onItemSelected: (_) {},
        isLoggedIn: true,
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final bool isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color:
                    isSelected ? const Color(0xFFFF9B05) : Colors.transparent,
                width: 2,
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
              color: isSelected ? const Color(0xFFFF9B05) : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  /// แท็บ “สูตรโปรดของฉัน”
  Widget _buildFavoritesView() {
    return FutureBuilder<List<Recipe>>(
      future: _futureFavorites,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? [];
        if (list.isEmpty) return const Center(child: Text('ยังไม่มีสูตรโปรด'));
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          itemCount: list.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 180.91 / 220,
          ),
          itemBuilder: (context, i) {
            final r = list[i];
            return MyRecipeCard(
              recipe: r,
              onTap: () =>
                  Navigator.pushNamed(context, '/recipe_detail', arguments: r),
            );
          },
        );
      },
    );
  }

  /// แท็บ “ตะกร้าวัตถุดิบ”
  Widget _buildCartView() {
    if (_cartItems.isEmpty) {
      return const Center(child: Text('ยังไม่มีรายการในตะกร้า'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── การ์ดสูตร (horizontal) ─────────────────
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _cartItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (ctx, i) {
                final item = _cartItems[i];
                return CartRecipeCard(
                  cartItem: item,

                  // edit servings via badge
                  onTapEditServings: () async {
                    final int? newS = await showModalBottomSheet<int>(
                      context: context,
                      builder: (_) => ServingsPicker(
                        initialServings: item.nServings.round(),
                      ),
                    );
                    if (newS != null && newS != item.nServings.round()) {
                      await ApiService.updateCart(
                          item.recipeId, newS.toDouble());
                      await _loadData();
                    }
                  },

                  // ลบรายการเดี่ยว พร้อม confirm
                  onDelete: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('ยืนยันลบเมนู'),
                        content: Text('ต้องการลบ "${item.name}" ไหม?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('ยกเลิก'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('ลบ',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ApiService.removeCartItem(item.recipeId);
                      await _loadData();
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // ─── รายการวัตถุดิบ ทั้ง header + count + list ──────
          CartIngredientListSection(ingredients: _cartIngredients),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// เพิ่มสูตรใหม่ลงตะกร้า
  Future<void> _addNewCartItem() async {
    final favs = await ApiService.fetchFavorites();
    if (favs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยังไม่มีสูตรโปรดให้เพิ่ม')),
      );
      return;
    }
    final Recipe? selected = await showModalBottomSheet<Recipe>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          children: favs
              .map((r) => ListTile(
                    title: Text(r.name),
                    onTap: () => Navigator.pop(ctx, r),
                  ))
              .toList(),
        ),
      ),
    );
    if (selected == null) return;

    final int? servings = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => ServingsPicker(initialServings: 1),
    );
    if (servings == null) return;

    try {
      await ApiService.addCartItem(selected.id, servings.toDouble());
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เพิ่มสูตรลงตะกร้าเรียบร้อย')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }
}

/// BottomSheet เลือกจำนวนเสิร์ฟ (1–10 คน)
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
            itemBuilder: (ctx, i) {
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
                onTap: () => Navigator.of(context).pop(s),
              );
            },
          ),
        ),
      ),
    );
  }
}
