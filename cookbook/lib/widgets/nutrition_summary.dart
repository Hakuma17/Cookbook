// lib/widgets/nutrition_summary.dart

import 'package:flutter/material.dart';
import '../models/nutrition.dart';

/// NutritionSummary - แสดงโภชนาการแบบ 4 ช่อง พร้อมปรับ label ยาวขึ้น 2 บรรทัด
class NutritionSummary extends StatelessWidget {
  final Nutrition? nutrition;
  final int baseServings;
  final int currentServings;

  const NutritionSummary({
    super.key,
    this.nutrition,
    required this.baseServings,
    required this.currentServings,
  });

  @override
  Widget build(BuildContext context) {
    if (nutrition == null || baseServings <= 0) return const SizedBox.shrink();

    // ------------------------------------------------------------------
    // 1) เตรียมข้อมูลหลังปรับ servings
    // ------------------------------------------------------------------
    final portionRatio = currentServings / baseServings;
    final items = <_NutItem>[
      _NutItem('แคลอรี่', nutrition!.calories * portionRatio),
      _NutItem('ไขมัน', nutrition!.fat * portionRatio),
      _NutItem('โปรตีน', nutrition!.protein * portionRatio),
      _NutItem('คาร์โบไฮเดรต', nutrition!.carbs * portionRatio),
    ];

    // ------------------------------------------------------------------
    // 2) UI – ใช้ LayoutBuilder >>> responsive scale ตามพื้นที่จริง
    // ------------------------------------------------------------------
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth; // กว้างของวิดเจ็ต
        final scale = (w / 360).clamp(0.80, 1.30); // safe-range

        double px(double v) => v * scale;

        final gap = px(10); // ช่องว่างกริด
        final radius = px(14); // มุมโค้ง
        final stroke = px(1.3); // เส้นขอบ
        final labelF = px(13);
        final valueF = labelF + 1;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: px(16)),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: gap,
              mainAxisSpacing: gap,
              // square-ish cell แต่ยืดตาม scale
              childAspectRatio: 1.03,
            ),
            itemBuilder: (_, i) {
              final it = items[i];
              final v = it.value;
              final s = v >= 10000
                  ? '${(v / 1000).toStringAsFixed(1)}K'
                  : v % 1 == 0
                      ? v.toStringAsFixed(0)
                      : v.toStringAsFixed(1);

              return Container(
                padding: EdgeInsets.all(px(8)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: const Color(0xFFFF9B05),
                    width: stroke,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── LABEL ────────────────────────────────────────
                    FittedBox(
                      child: Text(
                        it.label == 'คาร์โบไฮเดรต'
                            ? 'คาร์โบ\nไฮเดรต'
                            : it.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w600,
                          fontSize: labelF,
                          color: const Color(0xFFFF9B05),
                          height: 1.25,
                        ),
                      ),
                    ),
                    SizedBox(height: px(6)),
                    // ── VALUE ───────────────────────────────────────
                    FittedBox(
                      child: Text(
                        '$s g',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w700,
                          fontSize: valueF,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/*──────────────────────────────────────────────────────────────*/
class _NutItem {
  final String label;
  final double value;
  const _NutItem(this.label, this.value);
}
