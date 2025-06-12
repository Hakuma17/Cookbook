import 'package:flutter/material.dart';
import '../models/nutrition.dart';

/// NutritionSummary - แสดงโภชนาการแบบ 4 ช่อง พร้อมปรับ label ยาวขึ้น 2 บรรทัด
class NutritionSummary extends StatelessWidget {
  final Nutrition? nutrition;
  final int baseServings;
  final int currentServings;

  const NutritionSummary({
    Key? key,
    this.nutrition,
    required this.baseServings,
    required this.currentServings,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (nutrition == null || baseServings <= 0) return const SizedBox.shrink();

    final portionRatio = currentServings / baseServings;

    final items = <_NutItem>[
      _NutItem(label: 'แคลอรี่', value: nutrition!.calories * portionRatio),
      _NutItem(label: 'ไขมัน', value: nutrition!.fat * portionRatio),
      _NutItem(label: 'โปรตีน', value: nutrition!.protein * portionRatio),
      _NutItem(label: 'คาร์โบไฮเดรต', value: nutrition!.carbs * portionRatio),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        itemCount: items.length,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 8,
          childAspectRatio: 1.0, // ปรับให้เป็นสี่เหลี่ยมจัตุรัส
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          final v = item.value;
          final s = v >= 10000
              ? '${(v / 1000).toStringAsFixed(1)}K'
              : v % 1 == 0
                  ? v.toStringAsFixed(0)
                  : v.toStringAsFixed(1);

          return IntrinsicHeight(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFFF9B05), width: 1.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.label == 'คาร์โบไฮเดรต'
                        ? 'คาร์โบ\nไฮเดรต'
                        : item.label,
                    textAlign: TextAlign.center,
                    softWrap: true,
                    maxLines: 2,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Color(0xFFFF9B05),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$s g',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w700,
                        fontSize: 13.0,
                        color: Color(0xFF000000),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NutItem {
  final String label;
  final double value;
  const _NutItem({required this.label, required this.value});
}
