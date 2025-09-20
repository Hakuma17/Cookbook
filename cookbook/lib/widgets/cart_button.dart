import 'package:flutter/material.dart';

/// CartButton
/// ปุ่มใส่ตะกร้า + ปุ่มเลือกจำนวนเสิร์ฟ
class CartButton extends StatelessWidget {
  final int recipeId;
  final int currentServings;
  final ValueChanged<int>? onServingsChanged;
  final VoidCallback? onAddToCart;

  const CartButton({
    super.key,
    required this.recipeId,
    this.currentServings = 1,
    this.onServingsChanged,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    //   1. ลบ Manual Responsive Calculation และใช้ Theme
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        //   2. เปลี่ยนมาใช้ IconButton มาตรฐาน
        // IconButton สามารถกำหนดสไตล์ได้หลากหลายและจัดการ state ได้ดีกว่า
        IconButton(
          onPressed: onAddToCart,
          icon: const Icon(Icons.shopping_cart_outlined),
          tooltip: 'เพิ่มลงตะกร้า',
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.primary,
            side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(width: 8),

        //   3. เปลี่ยนมาใช้ OutlinedButton มาตรฐาน
        // OutlinedButton เหมาะสำหรับปุ่มที่มีลักษณะเป็นกรอบ
        OutlinedButton(
          onPressed: () async {
            final selected = await showModalBottomSheet<int>(
              context: context,
              builder: (_) => _ServingsPicker(initialServings: currentServings),
            );
            if (selected != null) onServingsChanged?.call(selected);
          },
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_outline,
                  size: 20, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                '$currentServings',
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 2),
              Icon(Icons.keyboard_arrow_down, color: colorScheme.primary),
            ],
          ),
        ),
      ],
    );
  }
}

/*──────────────── picker จำนวนเสิร์ฟ (1–10) ────────────────*/
///   4. ปรับปรุง Picker ให้ใช้ Theme ด้วย
class _ServingsPicker extends StatelessWidget {
  final int initialServings;

  const _ServingsPicker({required this.initialServings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final maxHeight = MediaQuery.of(context).size.height * 0.55;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ListView.builder(
            itemCount: 10,
            shrinkWrap: true,
            itemBuilder: (_, i) {
              final servings = i + 1;
              final isSelected = servings == initialServings;

              return ListTile(
                title: Text(
                  '$servings คน',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? theme.colorScheme.primary : null,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check, color: theme.colorScheme.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(servings),
              );
            },
          ),
        ),
      ),
    );
  }
}
