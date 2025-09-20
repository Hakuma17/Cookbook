import 'package:flutter/material.dart';
import '../utils/safe_image.dart';
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: .7), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: _leadingImage(),
        title: Text(
          ingredient.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        trailing: Text(
          amountText,
          textAlign: TextAlign.right,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
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
    return SafeImage(
      url: url,
      width: 48,
      height: 48,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(10),
      error: Container(
        width: 48,
        height: 48,
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Icon(Icons.no_photography_outlined),
      ),
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
