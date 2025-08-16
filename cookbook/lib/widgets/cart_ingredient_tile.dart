import 'package:flutter/material.dart';
import '../models/cart_ingredient.dart';

class CartIngredientTile extends StatelessWidget {
  final CartIngredient ingredient;
  const CartIngredientTile({super.key, required this.ingredient});

  // จัดรูปแบบจำนวนให้สวย (จำนวนเต็มไม่โชว์จุดทศนิยม)
  String _formatQuantity(double q) =>
      (q == q.roundToDouble()) ? q.toInt().toString() : q.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final cs = theme.colorScheme;

    final quantityText = _formatQuantity(ingredient.quantity);
    final unitText = ingredient.unit;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: ListTile(
        // รูปตัวอย่างวัตถุดิบ
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            ingredient.imageUrl,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            // ขณะโหลดรูป
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 56,
                height: 56,
                color: cs.surfaceVariant,
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            // โหลดพลาด → แสดงไอคอนแทน
            errorBuilder: (_, __, ___) => Container(
              width: 56,
              height: 56,
              color: cs.surfaceVariant,
              alignment: Alignment.center,
              child: Icon(Icons.image_not_supported_outlined,
                  color: cs.onSurfaceVariant),
            ),
          ),
        ),

        // ชื่อวัตถุดิบ: “ไม่หนา” แต่ขนาดเดิม (titleMedium)
        title: Text(
          ingredient.name,
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w400),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        // จำนวน + หน่วย: “ไม่หนา” แต่ขนาดเดิม (bodyMedium)
        trailing: Text.rich(
          TextSpan(
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w400),
            children: [
              TextSpan(text: quantityText), // ตัวเลข (ไม่หนา)
              TextSpan(
                // เว้นวรรค + หน่วย
                text: ' $unitText',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          textAlign: TextAlign.right,
        ),

        // ช่องไฟภายใน tile
        contentPadding:
            const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      ),
    );
  }
}
