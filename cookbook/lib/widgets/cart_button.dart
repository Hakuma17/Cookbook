// lib/widgets/cart_button.dart
//
// responsive-plus 2025-07-11
// – sizing / padding / font ปรับตามความกว้างจอด้วย clamp()
// – ป้องกัน overflow ทุกขนาดจอ
// – logic ใส่ตะกร้า & picker จำนวนเสิร์ฟ เหมือนเดิม 100 %
// -------------------------------------------------------------

import 'package:flutter/material.dart';

/// CartButton
/// ปุ่มใส่ตะกร้า + ปุ่มเลือกจำนวนเสิร์ฟ
class CartButton extends StatelessWidget {
  final int recipeId;
  final int currentServings;
  final ValueChanged<int>? onServingsChanged;
  final VoidCallback? onAddToCart;

  const CartButton({
    Key? key,
    required this.recipeId,
    this.currentServings = 1,
    this.onServingsChanged,
    this.onAddToCart,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFFCC09C);
    const accentColor = Color(0xFFFF9B05);

    /* ───────── responsive metrics ───────── */
    final w = MediaQuery.of(context).size.width;
    double clamp(double v, double min, double max) =>
        v < min ? min : (v > max ? max : v);

    final radius = clamp(w * .035, 10, 20); // มุมโค้ง
    final iconSize = clamp(w * .060, 18, 28); // ไอคอน
    final padCart = clamp(w * .022, 6, 12); // padding ปุ่มตะกร้า
    final padServH = clamp(w * .038, 10, 18); // padding pill-H
    final padServV = clamp(w * .020, 4, 10); // padding pill-V
    final textF = clamp(w * .038, 13, 17); // ฟอนต์ตัวเลข
    final gap = clamp(w * .030, 8, 16); // ช่องว่างระหว่างปุ่ม

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        /* ── ปุ่มตะกร้า ── */
        InkWell(
          onTap: onAddToCart,
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            padding: EdgeInsets.all(padCart),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: borderColor, width: 1.5),
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Icon(Icons.shopping_cart_outlined,
                size: iconSize, color: borderColor),
          ),
        ),
        SizedBox(width: gap),

        /* ── ปุ่มเลือกจำนวนเสิร์ฟ ── */
        InkWell(
          onTap: () async {
            final selected = await showModalBottomSheet<int>(
              context: context,
              isScrollControlled: true,
              builder: (_) => _ServingsPicker(initialServings: currentServings),
            );
            if (selected != null) onServingsChanged?.call(selected);
          },
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            padding:
                EdgeInsets.symmetric(horizontal: padServH, vertical: padServV),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: borderColor, width: 1.5),
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_outline, size: iconSize * .8),
                const SizedBox(width: 4),
                Text(
                  '$currentServings',
                  style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: textF,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 2),
                Icon(Icons.keyboard_arrow_down,
                    size: iconSize * .8, color: accentColor),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/*──────────────── picker จำนวนเสิร์ฟ (1–10) ────────────────*/
class _ServingsPicker extends StatelessWidget {
  final int initialServings;

  const _ServingsPicker({Key? key, required this.initialServings})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scrW = MediaQuery.of(context).size.width;
    final maxH = MediaQuery.of(context).size.height * .55;
    final fSize = (scrW * .044).clamp(14, 18).toDouble();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: ListView.builder(
            itemCount: 10,
            shrinkWrap: true,
            itemBuilder: (_, i) {
              final s = i + 1;
              return ListTile(
                title: Text(
                  '$s คน',
                  style: TextStyle(
                    fontSize: fSize,
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
