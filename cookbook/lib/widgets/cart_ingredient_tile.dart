import 'package:flutter/material.dart';
import '../models/cart_ingredient.dart';

class CartIngredientTile extends StatelessWidget {
  final CartIngredient ingredient;

  const CartIngredientTile({super.key, required this.ingredient});

  // Helper สำหรับจัดรูปแบบตัวเลขทศนิยม
  String _formatQuantity(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }
    return quantity.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    // 1. ลบ Manual Responsive Calculation และใช้ Theme
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    final quantityText = _formatQuantity(ingredient.quantity);
    final unitText = ingredient.unit;

    // 2. เปลี่ยนมาใช้ Card -> ListTile ซึ่งเป็นโครงสร้างที่เหมาะสมและจัดการง่าย
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      // Card จะใช้สไตล์จาก CardTheme ใน main.dart โดยอัตโนมัติ
      child: ListTile(
        // --- ส่วนรูปภาพ ---
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Image.network(
            ingredient.imageUrl,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            // แสดง Placeholder ขณะโหลดรูป
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 56,
                height: 56,
                color: colorScheme.surfaceVariant,
                child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
              );
            },
            // แสดง Placeholder เมื่อโหลดรูปไม่สำเร็จ
            errorBuilder: (_, __, ___) {
              return Container(
                width: 56,
                height: 56,
                color: colorScheme.surfaceVariant,
                child: Icon(Icons.image_not_supported_outlined,
                    color: colorScheme.onSurfaceVariant),
              );
            },
          ),
        ),
        // --- ชื่อวัตถุดิบ ---
        title: Text(
          ingredient.name,
          style: textTheme.titleMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        // --- ปริมาณ + หน่วย ---
        trailing: RichText(
          text: TextSpan(
            //  3. ใช้สไตล์จาก Theme ส่วนกลาง
            style: textTheme.bodyMedium,
            children: [
              TextSpan(
                text: quantityText,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: ' $unitText',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      ),
    );
  }
}
