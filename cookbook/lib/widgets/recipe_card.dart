// lib/widgets/recipe_card.dart

import 'package:flutter/material.dart';
import '../models/recipe.dart';

/// การ์ดแสดงข้อมูลสูตรอาหาร (รูป · ชื่อ · คะแนน · รีวิว)
class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onTap;

  const RecipeCard({
    Key? key,
    required this.recipe,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const cardWidth = 116.0;
    const cardHeight = 177.0;
    const imageSize = 116.0;
    const borderRadius = 16.0;

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── รูปภาพสูตรอาหาร ─────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(borderRadius),
              ),
              child: (recipe.imageUrl?.isNotEmpty ?? false)
                  ? Image.network(
                      recipe.imageUrl!,
                      width: imageSize,
                      height: imageSize,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallbackImage(imageSize),
                    )
                  : _fallbackImage(imageSize),
            ),

            // ── ชื่อสูตรอาหาร ─────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Text(
                recipe.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF0A2533),
                ),
              ),
            ),

            // ── คะแนนและจำนวนรีวิว ─────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.star, size: 15, color: Color(0xFFFF9B05)),
                  const SizedBox(width: 4),
                  Text(
                    recipe.averageRating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFA6A6A6),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${recipe.reviewCount} รีวิว',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFA6A6A6),
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

  /// รูป fallback จาก assets เมื่อไม่มีภาพจริง
  Widget _fallbackImage(double size) {
    return Image.asset(
      'lib/assets/images/default_recipe.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
  }
}
