import 'package:flutter/material.dart';
import '../models/cart_ingredient.dart';
import 'cart_ingredient_tile.dart';

class CartIngredientListSection extends StatelessWidget {
  final List<CartIngredient> ingredients;

  const CartIngredientListSection({super.key, required this.ingredients});

  @override
  Widget build(BuildContext context) {
    //  1. ลบ Manual Responsive Calculation และใช้ Theme
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // --- กรณีไม่มีวัตถุดิบ ---
    if (ingredients.isEmpty) {
      return _buildEmptyState(textTheme, theme);
    }

    final count = ingredients.length;

    // --- กรณีมีวัตถุดิบ ---
    return Padding(
      //  2. ใช้ Padding แบบคงที่ ทำให้ Layout คาดเดาได้ง่าย
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // --- หัวข้อ ---
          Text(
            'วัตถุดิบทั้งหมด',
            //  3. ใช้สไตล์จาก Theme ส่วนกลาง
            style: textTheme.titleLarge,
          ),
          // --- จำนวนชิ้น ---
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              '$count รายการ',
              style: textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          // --- รายการวัตถุดิบ ---
          // ListView.builder ถูกต้องแล้วสำหรับการแสดงรายการ
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

  /// ✅ 4. แยก Widget ของ Empty State ออกมาเพื่อความสะอาด
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
