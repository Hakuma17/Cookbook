// lib/widgets/ingredient_card.dart

import 'package:flutter/material.dart';
import '../models/ingredient.dart';
import '../services/api_service.dart';

/// การ์ดแสดงวัตถุดิบแต่ละชนิด (รูป + ชื่อวัตถุดิบ)
class IngredientCard extends StatelessWidget {
  final Ingredient ingredient;
  final VoidCallback? onTap;

  const IngredientCard({
    Key? key,
    required this.ingredient,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const cardWidth = 100.0;
    const cardHeight = 136.0;
    const imageHeight = 92.0;
    const borderRadius = 16.0;

    // Path จากฐานข้อมูล
    final String imagePath = ingredient.imageUrl.trim();
    final bool hasImage = imagePath.isNotEmpty;
    final String fullImageUrl =
        hasImage ? '${ApiService.baseUrl}$imagePath' : '';

    Widget _buildFallback() {
      return Image.asset(
        'assets/images/default_ingredients.png',
        width: cardWidth,
        height: imageHeight,
        fit: BoxFit.cover,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth,
        height: cardHeight,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFFBFBFB)),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF063336).withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // รูปภาพวัตถุดิบ
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(borderRadius),
              ),
              child: hasImage
                  ? Image.network(
                      fullImageUrl,
                      width: cardWidth,
                      height: imageHeight,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildFallback(),
                    )
                  : _buildFallback(),
            ),

            // ชื่อวัตถุดิบ
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    ingredient.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.45,
                      color: Color(0xFF0A2533),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
