// lib/widgets/cart_recipe_card.dart
//
// responsive-plus  (2025-07-11)
// – ไม่ยุ่ง logic onTapEditServings / onDelete / navigator
// – ไม่มี overflow / analyzer warning
// -------------------------------------------------------------

import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../screens/recipe_detail_screen.dart';

/// การ์ดสูตรในตะกร้า
class CartRecipeCard extends StatelessWidget {
  final CartItem cartItem;
  final VoidCallback onTapEditServings;
  final VoidCallback onDelete;

  const CartRecipeCard({
    Key? key,
    required this.cartItem,
    required this.onTapEditServings,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    /* ── responsive metrics ── */
    final w = MediaQuery.of(context).size.width;
    double clamp(double v, double min, double max) =>
        v < min ? min : (v > max ? max : v);

    final cardW = clamp(w * .44, 150, 240);
    final radius = clamp(w * .04, 12, 20);
    final imgH = cardW * (140 / 180); // ratio จาก mock-up
    final padIn = clamp(w * .030, 10, 16);
    final nameF = clamp(w * .045, 14, 19);
    final badgeF = clamp(w * .035, 11, 15);
    final badgePad = clamp(w * .018, 5, 9);
    final delSz = clamp(w * .048, 16, 24);
    final delPad = delSz * .35;
    final gapName = clamp(w * .020, 6, 12);

    return SizedBox(
      width: cardW,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          /* ───────── การ์ด ───────── */
          ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Container(
              color: Theme.of(context).cardColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /* ───── รูป + badge ───── */
                  SizedBox(
                    height: imgH,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        // รูป (คลิกเปิดรายละเอียด)
                        InkWell(
                          onTap: () => _openDetail(context),
                          child: Image.network(
                            cartItem.imageUrl,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, ev) => ev == null
                                ? child
                                : Image.asset(
                                    'assets/images/default_recipe.png',
                                    fit: BoxFit.cover),
                            errorBuilder: (_, __, ___) => Image.asset(
                                'assets/images/default_recipe.png',
                                fit: BoxFit.cover),
                          ),
                        ),

                        // Badge จำนวนเสิร์ฟ
                        Positioned(
                          bottom: badgePad,
                          right: badgePad,
                          child: GestureDetector(
                            onTap: onTapEditServings,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: badgePad * 1.6,
                                vertical: badgePad,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(radius * .6),
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
                                  Icon(Icons.person,
                                      size: badgeF + 3, color: Colors.black54),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${cartItem.nServings} คน',
                                    style: TextStyle(
                                      fontSize: badgeF,
                                      fontWeight: FontWeight.w600,
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

                  /* ───── ชื่อเมนู ───── */
                  Padding(
                    padding: EdgeInsets.fromLTRB(padIn, gapName, padIn, padIn),
                    child: InkWell(
                      onTap: () => _openDetail(context),
                      child: Text(
                        cartItem.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w600,
                          fontSize: nameF,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          /* ───────── ปุ่มลบ ───────── */
          Positioned(
            top: -delPad,
            right: -delPad,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: EdgeInsets.all(delPad),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete, size: delSz, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(recipeId: cartItem.recipeId),
      ),
    );
  }
}

/*───────────────── BottomSheet picker ─────────────────*/
class ServingsPicker extends StatelessWidget {
  final int initialServings;
  const ServingsPicker({Key? key, required this.initialServings})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scr = MediaQuery.of(context).size;
    final maxH = scr.height * .50;
    final fz = clamp(scr.width * .044, 13, 18);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: 10,
          itemBuilder: (_, i) {
            final s = i + 1;
            return ListTile(
              title: Text(
                '$s คน',
                style: TextStyle(
                  fontSize: fz,
                  fontWeight:
                      s == initialServings ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
              onTap: () => Navigator.of(context).pop(s),
            );
          },
        ),
      ),
    );
  }

  double clamp(double v, double min, double max) =>
      v < min ? min : (v > max ? max : v);
}
