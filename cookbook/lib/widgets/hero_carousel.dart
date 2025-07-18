// lib/widgets/hero_carousel.dart
//
// 1-Row Carousel 1–3 cards (เมนูแนะนำ) – responsive
// • 2025-07-13 v2: ใช้ Row.mainAxisAlignment.center → การ์ดอยู่กลางแถวเสมอ
// ---------------------------------------------------------------------------
import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../utils/highlight_span.dart';
import 'rank_badge.dart';

/// แคโรเซล 1 แถว (สูงสุด 3 การ์ด) ใช้โชว์ “เมนูแนะนำ”
class HeroCarousel extends StatelessWidget {
  final List<Recipe> recipes;
  final double? itemSize; // ขนาดกำหนดเอง (ถ้ามี)
  final ValueChanged<Recipe>? onTap;
  final List<String> highlightTerms;

  const HeroCarousel({
    super.key,
    required this.recipes,
    this.itemSize,
    this.onTap,
    this.highlightTerms = const [],
  });

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(builder: (context, box) {
      /* ── responsive metrics ── */
      final slotW = box.maxWidth; // พื้นที่ทั้งแถว
      double clamp(double v, double min, double max) =>
          v < min ? min : (v > max ? max : v);

      final itemCnt = recipes.length.clamp(1, 3); // 1–3 การ์ด
      final gap = clamp(slotW * .02, 8, 14); // ช่องไฟระหว่างการ์ด
      final avail = slotW - gap * (itemCnt - 1);
      final autoSz = avail / itemCnt;
      final size = clamp(itemSize ?? autoSz, 90, 170);
      final radius = clamp(size * .14, 10, 22);
      final font14 = clamp(size * .12, 12, 17);

      final top = recipes.take(3).toList();

      return Row(
        mainAxisAlignment: MainAxisAlignment.center, // ★ ให้อยู่กลางแถว
        children: List.generate(top.length, (i) {
          final r = top[i];

          return Padding(
            padding: EdgeInsets.only(right: i == top.length - 1 ? 0 : gap),
            child: GestureDetector(
              onTap: () => onTap?.call(r),
              child: Column(
                children: [
                  /* ── รูป + Badge ── */
                  Stack(
                    children: [
                      _recipeImage(r.imageUrl, size, radius),
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
                        TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w700,
                          fontSize: font14,
                          height: 1.28,
                          color: const Color(0xFF0A2533),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      );
    });
  }

  /* ───────────────────── helpers ───────────────────── */
  Widget _recipeImage(String url, double sz, double radius) {
    final img = url.isNotEmpty
        ? Image.network(
            url,
            width: sz,
            height: sz,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback(sz),
          )
        : _fallback(sz);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: img,
    );
  }

  Widget _fallback(double sz) => Image.asset(
        'assets/images/default_recipe.png',
        width: sz,
        height: sz,
        fit: BoxFit.cover,
      );
}
