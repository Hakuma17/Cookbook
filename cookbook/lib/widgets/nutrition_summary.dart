// lib/widgets/nutrition_summary.dart

import 'package:flutter/material.dart';
import '../models/nutrition.dart';

/// NutritionSummary
/// แสดงสรุปโภชนาการ 4 ค่าหลัก (calories, fat, protein, carbs)
/// ถ้า nutrition เป็น null จะไม่แสดงอะไร
class NutritionSummary extends StatelessWidget {
  final Nutrition? nutrition;

  const NutritionSummary({Key? key, this.nutrition}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (nutrition == null) return const SizedBox.shrink();

    final items = <_NutItem>[
      _NutItem(label: 'แคลอรี่', value: nutrition!.calories),
      _NutItem(label: 'ไขมัน', value: nutrition!.fat),
      _NutItem(label: 'โปรตีน', value: nutrition!.protein),
      _NutItem(label: 'คาร์โบไฮเดรต', value: nutrition!.carbs),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // คำนวณความกว้างของแต่ละกล่องให้พอดี 4 ต่อแถว
          final totalSpacing = 10.96 * (items.length - 1);
          final itemWidth =
              (constraints.maxWidth - totalSpacing) / items.length;

          return Wrap(
            spacing: 10.96, // horizontal gap
            runSpacing: 4.38, // vertical gap
            children: items.map((item) {
              final v = item.value;
              final s =
                  v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

              return SizedBox(
                width: itemWidth,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.96,
                    vertical: 4.38,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: const Color(0xFFFF9B05),
                      width: 1.09067,
                    ),
                    borderRadius: BorderRadius.circular(13.088),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.label,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w600,
                          fontSize: 13.088,
                          height: 16 / 13.088,
                          color: Color(0xFFFF9B05),
                        ),
                      ),
                      const SizedBox(height: 4.38),
                      Text(
                        '$s g',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w700,
                          fontSize: 15.2693,
                          height: 24 / 15.2693,
                          color: Color(0xFF000000),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
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
