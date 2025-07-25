import 'package:flutter/material.dart';
import '../models/nutrition.dart';

/*──────────────── helper ───────────────*/
class _NutItem {
  final String label;
  final double value;
  const _NutItem(this.label, this.value);
}

/*──────────────── widget ───────────────*/
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
    if (nutrition == null || baseServings <= 0) {
      return const SizedBox.shrink();
    }

    final ratio = currentServings / baseServings;
    final items = [
      _NutItem('แคลอรี่', nutrition!.calories * ratio),
      _NutItem('ไขมัน', nutrition!.fat * ratio),
      _NutItem('โปรตีน', nutrition!.protein * ratio),
      _NutItem('คาร์โบไฮเดรต', nutrition!.carbs * ratio),
    ];

    /* ปรับ childAspectRatio = 0.95 (+ความสูง ~1‑2px) แก้ overflow */
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.95, // ← เดิม 1.0
      ),
      itemBuilder: (_, i) => _buildCell(context, items[i]),
    );
  }

  /*───────── cell ─────────*/
  Widget _buildCell(BuildContext context, _NutItem item) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final num = item.value;
    final v = num >= 10000
        ? '${(num / 1000).toStringAsFixed(1)}K'
        : num % 1 == 0
            ? num.toInt().toString()
            : num.toStringAsFixed(1);

    final label = item.label == 'คาร์โบไฮเดรต' ? 'คาร์โบ\nไฮเดรต' : item.label;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withOpacity(.7), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.bold,
                height: 1.2,
              )),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              item.label == 'แคลอรี่' ? v : '$v g',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
