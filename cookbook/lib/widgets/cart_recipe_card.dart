import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../screens/recipe_detail_screen.dart';

/// การ์ดสูตรในตะกร้า (เหมือน MyRecipeCard แก้ไขตาม mock-up)
/// - แตะบนรูปหรือชื่อ → ไปหน้า Detail
/// - Badge จำนวนคน (แตะได้เพื่อแก้ servings)
/// - ปุ่ม “แก้ไขจำนวนเสิร์ฟ” ใต้ชื่อ
/// - ปุ่มลบเมนู (มุมบนขวา)
class CartRecipeCard extends StatelessWidget {
  /// ข้อมูลเมนูจากตะกร้า
  final CartItem cartItem;

  /// Callback เมื่อผู้ใช้แตะ badge หรือปุ่ม “แก้ไขจำนวนเสิร์ฟ”
  final VoidCallback onTapEditServings;

  /// Callback เมื่อผู้ใช้กดปุ่มลบเมนู
  final VoidCallback onDelete;

  const CartRecipeCard({
    Key? key,
    required this.cartItem,
    required this.onTapEditServings,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // บังคับความกว้างให้คงที่ เท่ากับขนาดการ์ดใน ListView
      width: 180,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ─── การ์ดหลัก ─────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: Theme.of(context).cardColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── รูปภาพ + Badge จำนวนคน ───────────────
                  AspectRatio(
                    aspectRatio: 180 / 140,
                    child: Stack(
                      children: [
                        // รูปหลัก (InkWell คลุมทั้งรูป เพื่อให้แตะรูปได้)
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RecipeDetailScreen(
                                  recipeId: cartItem.recipeId,
                                ),
                              ),
                            );
                          },
                          child: FadeInImage.assetNetwork(
                            placeholder: 'assets/images/default_recipe.png',
                            image: cartItem.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            imageErrorBuilder: (_, __, ___) => Image.asset(
                              'assets/images/default_recipe.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),

                        // Badge จำนวนคน (แตะเพื่อแก้ servings)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: onTapEditServings,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.person,
                                    size: 16,
                                    color: Colors.black54,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${cartItem.nServings.toInt()} คน',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ─── ชื่อเมนูใต้รูป + ปุ่ม “แก้ไขจำนวนเสิร์ฟ” ────
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ชื่อ (InkWell คลุมให้แตะชื่อก็ไป Detail)
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RecipeDetailScreen(
                                  recipeId: cartItem.recipeId,
                                ),
                              ),
                            );
                          },
                          child: Text(
                            cartItem.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        /* ปุ่ม “แก้ไขจำนวนเสิร์ฟ”
                        ///GestureDetector(
                          onTap: onTapEditServings,
                          child: Text(
                            'แก้ไขจำนวนเสิร์ฟ',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).primaryColor,
                                      decoration: TextDecoration.underline,
                                    ),
                          ),
                        ),*/
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── ปุ่มลบเมนู (มุมบนขวา หลุดออกนิด ๆ) ─────────────
          Positioned(
            top: -8,
            right: -8,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(6),
                child: const Icon(
                  Icons.delete,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// BottomSheet เลือกจำนวนเสิร์ฟ (1–10 คน)
class ServingsPicker extends StatelessWidget {
  final int initialServings;
  const ServingsPicker({Key? key, required this.initialServings})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: 10,
        itemBuilder: (ctx, index) {
          final s = index + 1;
          return ListTile(
            title: Text(
              '$s คน',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    s == initialServings ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            onTap: () => Navigator.of(context).pop(s),
          );
        },
      ),
    );
  }
}
