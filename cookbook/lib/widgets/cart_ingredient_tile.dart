import 'package:flutter/material.dart';
import '../models/cart_ingredient.dart';

class CartIngredientTile extends StatelessWidget {
  final CartIngredient ingredient;

  const CartIngredientTile({
    Key? key,
    required this.ingredient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final qty = _formatQuantity(ingredient.quantity);
    final unit = ingredient.unit;

    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FadeInImage.assetNetwork(
                placeholder: 'assets/images/default_ingredients.png',
                image: ingredient.imageUrl,
                width: 62,
                height: 62,
                fit: BoxFit.cover,
                imageErrorBuilder: (_, __, ___) => Image.asset(
                  'assets/images/default_ingredients.png',
                  width: 62,
                  height: 62,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                ingredient.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0A2533),
                ),
              ),
            ),
            const SizedBox(width: 16),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontFamily: 'Montserrat'),
                children: [
                  TextSpan(
                    text: qty,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0A2533),
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF908F8F),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatQuantity(double q) {
    return q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(2);
  }
}
