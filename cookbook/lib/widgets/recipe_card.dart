// lib/widgets/recipe_card.dart

import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../utils/format_utils.dart';
import 'rank_badge.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onTap;
  final bool compact;
  final bool expanded;

  const RecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
    this.compact = false,
    this.expanded = false,
  });

  /* ────────────────── responsive helpers ────────────────── */
  double _rs(double w, double base, double min, double max) =>
      base.clamp(min, max).toDouble();

  TextStyle _title(double sz) => TextStyle(
        fontFamily: 'Montserrat',
        fontWeight: FontWeight.w600,
        fontSize: sz,
        height: 1.25,
        color: const Color(0xFF0A2533),
      );

  TextStyle _body(double sz, {Color c = const Color(0xFFA6A6A6)}) => TextStyle(
        fontFamily: 'Roboto',
        fontSize: sz,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: c,
      );

  BoxDecoration _dec(double br) => BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFFBFBFB)),
        borderRadius: BorderRadius.circular(br),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF063336).withOpacity(.10),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      );

  Widget _img(String url, double w, double h, double br) {
    final child = url.isNotEmpty
        ? Image.network(
            url,
            width: w,
            height: h,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback(w, h),
          )
        : _fallback(w, h);

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(br)),
      child: child,
    );
  }

  Widget _fallback(double w, double h) => Image.asset(
        'assets/images/default_recipe.png',
        width: w,
        height: h,
        fit: BoxFit.cover,
      );

  /* ───────────────────────── build ───────────────────────── */
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      // `w` คือพื้นที่กว้างสุดที่ card จะได้รับใน layout นั้น ๆ
      final w =
          c.maxWidth.isFinite ? c.maxWidth : MediaQuery.of(context).size.width;

      // base-width 360 ⇒ scale = w/360 (คุมในช่วง 0.8-1.3)
      final scale = (w / 360).clamp(0.8, 1.3);
      double px(double v) => v * scale;

      /* ---- ตัวเลขหลักที่ใช้ทุกโหมด ---- */
      final radius = _rs(w, px(14), 12, 22);
      final titleF = _rs(w, px(14), 13, 18);
      final bodyF = _rs(w, titleF * .9, 12, 16);
      final starSize = _rs(w, px(15), 13, 18);

      if (compact) {
        return _compact(radius, titleF, bodyF, starSize, px);
      }
      if (expanded) {
        return _expanded(radius, titleF, bodyF, starSize, px);
      }
      return _vertical(radius, titleF, bodyF, starSize, px);
    });
  }

  /* ╔═══════════════════ 1. Vertical Card ═══════════════════╗ */
  Widget _vertical(
      double r, double t, double b, double star, double Function(double) px) {
    final cardW = _rs(px(116), px(116), 110, 145);
    final imgH = cardW;
    final cardH = cardW * 1.55;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardW,
        height: cardH,
        margin: const EdgeInsets.only(right: 12),
        decoration: _dec(r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(children: [
              _img(recipe.imageUrl, cardW, imgH, r),
              _badge(),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Text(
                recipe.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _title(t),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: _rating(bodyF: b, iconSz: star),
            ),
          ],
        ),
      ),
    );
  }

  /* ╔═══════════════════ 2. Compact Card ════════════════════╗ */
  Widget _compact(
      double r, double t, double b, double star, double Function(double) px) {
    final imgH = _rs(px(170), px(170), 150, 220);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: _dec(r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(children: [
              _img(recipe.imageUrl, double.infinity, imgH, r),
              _badge(),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Text(
                recipe.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _title(t),
              ),
            ),
            if (recipe.shortIngredients.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  recipe.shortIngredients,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _body(b, c: const Color(0xFF818181)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: _rating(bodyF: b, iconSz: star),
            ),
          ],
        ),
      ),
    );
  }

  /* ╔═══════════════════ 3. Expanded Card ═══════════════════╗ */
  Widget _expanded(
      double r, double t, double b, double star, double Function(double) px) {
    final imgH = _rs(px(180), px(180), 160, 240);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: _dec(r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _img(recipe.imageUrl, double.infinity, imgH, r),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _title(t),
                  ),
                  const SizedBox(height: 4),
                  if (recipe.shortIngredients.isNotEmpty)
                    Text(
                      recipe.shortIngredients,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _body(b, c: const Color(0xFF818181)),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (recipe.prepTime > 0) ...[
                        Icon(Icons.access_time,
                            size: star, color: const Color(0xFF888888)),
                        const SizedBox(width: 4),
                        Text('${recipe.prepTime} นาที',
                            style: _body(b, c: const Color(0xFF888888))),
                        const SizedBox(width: 12),
                      ],
                      Icon(Icons.star,
                          size: star, color: const Color(0xFFFF9B05)),
                      const SizedBox(width: 4),
                      Text(recipe.averageRating.toStringAsFixed(1),
                          style: _body(b)),
                      const SizedBox(width: 6),
                      Icon(Icons.comment,
                          size: star, color: const Color(0xFFA6A6A6)),
                      const SizedBox(width: 4),
                      Text(formatCount(recipe.reviewCount), style: _body(b)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ───────────── secondary widgets ───────────── */
  Widget _badge() {
    if (recipe.rank == null && !recipe.hasAllergy)
      return const SizedBox.shrink();
    return Positioned(
      top: 8,
      left: 8,
      child: RankBadge(rank: recipe.rank, showWarning: recipe.hasAllergy),
    );
  }

  Widget _rating({required double bodyF, required double iconSz}) => Row(
        children: [
          Icon(Icons.star, size: iconSz, color: const Color(0xFFFF9B05)),
          const SizedBox(width: 4),
          Text(recipe.averageRating.toStringAsFixed(1), style: _body(bodyF)),
          const SizedBox(width: 6),
          Text('${recipe.reviewCount} รีวิว', style: _body(bodyF)),
        ],
      );
}
