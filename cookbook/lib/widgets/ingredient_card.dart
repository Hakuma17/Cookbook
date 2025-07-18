// lib/widgets/ingredient_card.dart
//
// responsive-plus 2025-07-xx  ♦ overflow-safe
// – หาก parent กำหนด maxHeight (เช่น SizedBox/ConstrainedBox ใน HomeScreen)
//   การ์ดจะยึดความสูงนั้นเป็นอันดับแรก จึงไม่ BOTTOM OVERFLOWED
// – ยังคงรองรับการส่ง width/height แบบ override ได้เหมือนเดิม ✅
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import '../models/ingredient.dart';
import '../services/api_service.dart';

class IngredientCard extends StatelessWidget {
  final Ingredient ingredient;
  final VoidCallback? onTap;

  /// ถ้า caller ส่งมาก่อนจะใช้ค่านั้นตรง ๆ; ถ้า null จะคำนวณแบบ responsive
  final double? width;
  final double? height;

  const IngredientCard({
    super.key,
    required this.ingredient,
    this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    /* ── LayoutBuilder → scale จาก “ช่องว่าง” ที่ parent ให้ ── */
    return LayoutBuilder(builder: (context, box) {
      // พื้นที่กว้างสุดที่ parent อนุญาต (แนวนอน)
      final slotW = box.maxWidth.isFinite
          ? box.maxWidth
          : MediaQuery.of(context).size.width;

      // พื้นที่สูงสุดที่ parent อนุญาต (แนวตั้ง) — สำคัญสำหรับกัน overflow
      final slotH = box.maxHeight.isFinite
          ? box.maxHeight
          : MediaQuery.of(context).size.height;

      double clamp(double v, double min, double max) =>
          v < min ? min : (v > max ? max : v);

      /* ── 1) คำนวณความสูงการ์ด ───────────────────────────────
         ลำดับความสำคัญ:
         ① caller ส่ง height → ใช้เลย
         ② parent กำหนด maxHeight → ยึดเป็นเพดาน (clamp 110-260)
         ③ fallback: ใช้อัตราส่วนจากความกว้าง                       */
      final double cardH = clamp(
        height ?? (box.maxHeight.isFinite ? slotH : (width ?? slotW) * 1.37),
        110,
        260,
      );

      /* ── 2) คำนวณความกว้างการ์ด ──────────────────────────────
         ถ้า caller ส่ง width → ใช้เลย
         ไม่งั้นคำนวณจาก cardH / อัตราส่วนเดิม (≈ 95×130)           */
      final double cardW = width ?? clamp(cardH / 1.37, 80, 160);

      /* ── ค่าอนุพันธ์ ── */
      final imgH = cardH - 38; // พื้นที่รูป
      final radius = clamp(cardW * .12, 10, 18);
      final font12 = clamp(cardW * .13, 11, 14);

      /* ── โหลด / fallback รูป ── */
      final path = ingredient.imageUrl.trim();
      final imgUrl = path.isNotEmpty ? '${ApiService.baseUrl}$path' : '';
      final placeholder = Image.asset(
        'assets/images/default_ingredients.png',
        width: cardW,
        height: imgH,
        fit: BoxFit.cover,
      );

      /* ── UI ── */
      return GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: cardW,
          height: cardH,
          child: Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(radius)),
                  child: imgUrl.isNotEmpty
                      ? Image.network(
                          imgUrl,
                          width: cardW,
                          height: imgH,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => placeholder,
                        )
                      : placeholder,
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    // ⭐ ป้องกันชื่อยาวล้น
                    fit: BoxFit.scaleDown,
                    child: Text(
                      ingredient.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: font12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF0A2533),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
