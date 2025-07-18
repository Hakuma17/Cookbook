// lib/widgets/cart_ingredient_list_section.dart
//
// responsive-plus (2025-07-11)
// – logic เหมือนเดิม 100 %
// – ใช้ clamp(w * factor , min , max) ปรับฟอนต์-ระยะห่าง
// – when list.isEmpty → ข้อความอยู่กึ่งกลาง, padding สวยขึ้นทุกจอ
// ---------------------------------------------------------------

import 'package:flutter/material.dart';
import '../models/cart_ingredient.dart';
import 'cart_ingredient_tile.dart';

class CartIngredientListSection extends StatelessWidget {
  final List<CartIngredient> ingredients;

  const CartIngredientListSection({Key? key, required this.ingredients})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    /* ── responsive helpers ── */
    final w = MediaQuery.of(context).size.width;
    double clamp(double v, double min, double max) =>
        v < min ? min : (v > max ? max : v);

    final headF = clamp(w * .044, 14, 20); // หัวข้อ “วัตถุดิบ”
    final subF = clamp(w * .040, 13, 17); // “xx ชิ้น” & empty msg
    final padH = clamp(w * .040, 12, 24); // padding แนวนอน
    final padTop = clamp(w * .036, 10, 22); // padding ด้านบน
    final padBtm = clamp(w * .050, 16, 28); // padding ด้านล่าง

    /* ── ไม่มีวัตถุดิบ ── */
    if (ingredients.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: padBtm * .8),
        child: Center(
          child: Text('ยังไม่มีวัตถุดิบในตะกร้า',
              style: TextStyle(fontSize: subF, color: Colors.grey.shade600)),
        ),
      );
    }

    final count = ingredients.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: padTop),
        /* ── หัวข้อ ── */
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padH),
          child: Text(
            'วัตถุดิบ',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                  fontSize: headF,
                  color: const Color(0xFF0A2533),
                ),
          ),
        ),
        /* ── จำนวนชิ้น ── */
        Padding(
          padding: EdgeInsets.fromLTRB(padH, 4, padH, padTop * .75),
          child: Text(
            '$count ชิ้น',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w400,
                  fontSize: subF,
                  color: const Color(0xFFABABAB),
                ),
          ),
        ),
        /* ── รายการวัตถุดิบ ── */
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: padH),
          itemCount: ingredients.length,
          itemBuilder: (_, i) => CartIngredientTile(ingredient: ingredients[i]),
        ),
        SizedBox(height: padBtm),
      ],
    );
  }
}
