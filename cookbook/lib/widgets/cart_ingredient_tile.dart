import 'package:flutter/material.dart';
import '../models/cart_ingredient.dart';
import '../models/unit_display_mode.dart';
import '../utils/unit_convert.dart';

class CartIngredientTile extends StatelessWidget {
  final CartIngredient ingredient;

  /// โหมดแสดงผลหน่วย
  final UnitDisplayMode unitMode;

  const CartIngredientTile({
    super.key,
    required this.ingredient,
    this.unitMode = UnitDisplayMode.original,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final amountText = _formatAmount();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: _leadingImage(),
        title: Text(
          ingredient.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium,
        ),
        trailing: Text(
          amountText,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _leadingImage() {
    final url = ingredient.imageUrl;
    if (url.isEmpty) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Icon(Icons.image_outlined),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(url, width: 48, height: 48, fit: BoxFit.cover),
    );
  }

  String _formatAmount() {
    switch (unitMode) {
      case UnitDisplayMode.original:
        return '${UnitConvert.fmtNum(ingredient.quantity)} ${ingredient.unit}';
      case UnitDisplayMode.grams:
        // 1) ถ้ามี gramsActual ใช้เลย
        if ((ingredient.gramsActual ?? 0) > 0) {
          return UnitConvert.fmtGrams(ingredient.gramsActual!);
        }
        // 2) ลองประมาณค่าจาก unit ที่รู้จัก
        final g = UnitConvert.approximateGrams(
          ingredient.quantity,
          ingredient.unit,
        );
        if (g != null) return '≈ ${UnitConvert.fmtGrams(g)}';
        // 3) แปลงไม่ได้ → หน่วยเดิม
        return '${UnitConvert.fmtNum(ingredient.quantity)} ${ingredient.unit}';
    }
  }
}
