import 'package:flutter/material.dart';
import '../models/cart_ingredient.dart';
import 'cart_ingredient_tile.dart';

class CartIngredientListSection extends StatelessWidget {
  final List<CartIngredient> ingredients;
  const CartIngredientListSection({super.key, required this.ingredients});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // ── 1) ลิสต์ว่าง → แสดง Empty State แล้วจบ ──────────────────────────────
    if (ingredients.isEmpty) {
      return _buildEmptyState(textTheme, theme);
    }

    final count = ingredients.length;

    // ── 2) ลิสต์มีข้อมูล ────────────────────────────────────────────────────
    // ใช้สไตล์หัวข้อเดียวกันทั้งซ้าย/ขวา เพื่อให้ "หนาเท่ากัน"
    final headerStyle = textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700, // ชัดและเท่ากันทั้งคู่
      color: theme.colorScheme.onSurface,
    );

    return Padding(
      // เว้นขอบคงที่เพื่อเลย์เอาต์คาดเดาได้
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // ── 3) แถบหัวข้อ: ซ้าย=ข้อความ, ขวา=จำนวน (บรรทัดเดียว ชิดขอบ) ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline:
                TextBaseline.alphabetic, // ให้ตัวหนังสือ “เสมอเส้นฐาน”
            children: [
              // ซ้าย: "วัตถุดิบทั้งหมด" กินพื้นที่ที่เหลือ
              Expanded(
                child: Text('วัตถุดิบทั้งหมด', style: headerStyle),
              ),
              // ขวา: "xx รายการ" หนา/ขนาดเท่ากัน
              Text('$count รายการ', style: headerStyle),
            ],
          ),

          const SizedBox(height: 8),

          // ── 4) รายการวัตถุดิบ ────────────────────────────────────────────
          // ใช้ ListView.builder (ไม่สกอร์ลซ้อน) เพื่อให้สกอร์ลตามหน้าหลัก
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ingredients.length,
            itemBuilder: (_, i) =>
                CartIngredientTile(ingredient: ingredients[i]),
          ),
        ],
      ),
    );
  }

  // ── 5) วิดเจ็ตสถานะว่าง: ไอคอน + ข้อความสีอ่อน ────────────────────────
  Widget _buildEmptyState(TextTheme textTheme, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48.0),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shopping_basket_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'ยังไม่มีวัตถุดิบในตะกร้า',
            style: textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
