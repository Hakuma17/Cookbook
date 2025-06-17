import 'package:flutter/material.dart';
import '../models/cart_ingredient.dart';
import 'cart_ingredient_tile.dart';

class CartIngredientListSection extends StatelessWidget {
  final List<CartIngredient> ingredients;

  const CartIngredientListSection({
    Key? key,
    required this.ingredients,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // กรณียังไม่มีวัตถุดิบ
    if (ingredients.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Text(
            'ยังไม่มีวัตถุดิบในตะกร้า',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    // จำนวนรายการทั้งหมด
    final count = ingredients.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // หัวเรื่อง "วัตถุดิบ"
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'วัตถุดิบ',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: const Color(0xFF0A2533),
                ),
          ),
        ),

        // จำนวนชิ้น เช่น "15 ชิ้น"
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(
            '$count ชิ้น',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                  color: const Color(0xFFABABAB),
                ),
          ),
        ),

        // รายการวัตถุดิบ
        ListView.builder(
          shrinkWrap: true, // ให้ปรับความสูงตามจำนวน item
          physics:
              const NeverScrollableScrollPhysics(), // ปิด scroll ซ้อนกับ parent
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: ingredients.length,
          itemBuilder: (context, index) {
            return CartIngredientTile(
              ingredient: ingredients[index],
            );
          },
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}
