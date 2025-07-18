// lib/widgets/cart_ingredient_tile.dart
//
// responsive-plus (2025-07-11)
//
// – logic onTap / model ไม่เปลี่ยน
// – ใช้ clamp(screenW * factor, min, max) ตลอด
// – เปลี่ยน FadeInImage → Image.network + loading/error builder
//   เพื่อลด popping ของ placeholder
// – ไม่มี overflow บนจอเล็ก รวมถึงภาษาไทยยาว ๆ 1 บรรทัด
// -----------------------------------------------------------------

import 'package:flutter/material.dart';
import '../models/cart_ingredient.dart';

class CartIngredientTile extends StatelessWidget {
  final CartIngredient ingredient;

  const CartIngredientTile({Key? key, required this.ingredient})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    /* ── responsive metrics ── */
    final w = MediaQuery.of(context).size.width;
    double clamp(double v, double min, double max) =>
        v < min ? min : (v > max ? max : v);

    final imgSz = clamp(w * .17, 48, 80); // ด้านยาวรูป
    final padCard = clamp(w * .030, 10, 18); // padding card
    final radius = clamp(w * .040, 12, 20); // border radius
    final gapH = clamp(w * .040, 12, 24); // ช่องว่างระหว่างรูป-ข้อความ
    final nameF = clamp(w * .050, 15, 22); // ฟอนต์ชื่อ
    final qtyF = clamp(w * .042, 13, 18); // ฟอนต์ปริมาณ
    final marginV = clamp(w * .020, 6, 14); // margin vertical

    final qty = _fmt(ingredient.quantity);
    final unit = ingredient.unit;

    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: marginV),
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: EdgeInsets.all(padCard),
        child: Row(
          children: [
            /* ── ภาพวัตถุดิบ ── */
            ClipRRect(
              borderRadius: BorderRadius.circular(radius * .6),
              child: Image.network(
                ingredient.imageUrl,
                width: imgSz,
                height: imgSz,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, ev) => ev == null
                    ? child
                    : Image.asset('assets/images/default_ingredients.png',
                        width: imgSz, height: imgSz, fit: BoxFit.cover),
                errorBuilder: (_, __, ___) => Image.asset(
                    'assets/images/default_ingredients.png',
                    width: imgSz,
                    height: imgSz,
                    fit: BoxFit.cover),
              ),
            ),
            SizedBox(width: gapH),
            /* ── ชื่อวัตถุดิบ ── */
            Expanded(
              child: Text(
                ingredient.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: nameF,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF0A2533),
                ),
              ),
            ),
            SizedBox(width: gapH * .8),
            /* ── ปริมาณ + หน่วย ── */
            RichText(
              text: TextSpan(
                style: const TextStyle(fontFamily: 'Montserrat'),
                children: [
                  TextSpan(
                    text: qty,
                    style: TextStyle(
                      fontSize: qtyF,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0A2533),
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontSize: qtyF,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF908F8F),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double q) =>
      q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(2);
}
