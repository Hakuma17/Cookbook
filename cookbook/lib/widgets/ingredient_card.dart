import 'package:flutter/material.dart';
import '../models/ingredient.dart';
import '../services/api_service.dart';

class IngredientCard extends StatelessWidget {
  final Ingredient ingredient;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const IngredientCard({
    super.key,
    required this.ingredient,
    this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final w = width ?? 95.0;
    final h = height ?? 130.0;
    final imgH = h - 38;
    const br = 12.0;

    final path = ingredient.imageUrl.trim();
    final imgUrl = path.isNotEmpty ? '${ApiService.baseUrl}$path' : '';

    Widget fallback = Image.asset(
      'assets/images/default_ingredients.png',
      width: w,
      height: imgH,
      fit: BoxFit.cover,
    );

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: w,
        height: h,
        child: Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(br),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(br)),
                child: imgUrl.isNotEmpty
                    ? Image.network(
                        imgUrl,
                        width: w,
                        height: imgH,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => fallback,
                      )
                    : fallback,
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  ingredient.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0A2533),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
