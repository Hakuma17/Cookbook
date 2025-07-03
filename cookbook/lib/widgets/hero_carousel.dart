// lib/widgets/hero_carousel.dart

import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../utils/highlight_span.dart';
import 'rank_badge.dart';

class HeroCarousel extends StatelessWidget {
  /// รายการ Recipe (สูงสุด 3)
  final List<Recipe> recipes;

  /// ขนาดกรอบสี่เหลี่ยมรูปภาพ (px)
  final double itemSize;

  /// callback เมื่อแตะการ์ด
  final ValueChanged<Recipe>? onTap;

  /// คำที่จะเน้น (case-insensitive)
  final List<String> highlightTerms;

  const HeroCarousel({
    super.key,
    required this.recipes,
    this.itemSize = 115, // ให้พอดี 3 ใบบนจอกว้าง~360px
    this.onTap,
    this.highlightTerms = const [],
  });

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) return const SizedBox.shrink();

    final top3 = recipes.take(3).toList();
    final size = itemSize;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(top3.length, (i) {
          final r = top3[i];

          return GestureDetector(
            onTap: () => onTap?.call(r),
            child: Column(
              children: [
                /* ── รูป + Badge ── */
                Stack(
                  children: [
                    _recipeImage(r.imageUrl, size),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: RankBadge(rank: r.rank ?? (i + 1)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                /* ── ชื่อเมนู ── */
                SizedBox(
                  width: size,
                  child: RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    text: highlightSpan(
                      r.name,
                      highlightTerms,
                      const TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF0A2533),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  /* ───────────────────────── helpers ───────────────────── */
  Widget _recipeImage(String url, double size) {
    final img = url.isNotEmpty
        ? Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback(size),
          )
        : _fallback(size);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: img,
    );
  }

  Widget _fallback(double size) => Image.asset(
        'assets/images/default_recipe.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
}
