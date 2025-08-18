// lib/widgets/hero_carousel.dart
import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../utils/highlight_span.dart';
import '../utils/safe_image.dart'; // ⬅️ ใช้ SafeImage แทน Image.network
import 'rank_badge.dart';

/// แคโรเซล 1 แถวสำหรับเมนูเด่น (สูงสุด 3 ใบ)
/// - การ์ดทั้งสามกว้างเท่ากัน ด้วย Row + Expanded
/// - ส่วนรูปเป็นสี่เหลี่ยมจัตุรัส “มุมฉาก”
/// - ชื่อเมนู 2 บรรทัด จัดชิดบนให้แนวบรรทัดแรกตรงกันทุกใบ
class HeroCarousel extends StatelessWidget {
  const HeroCarousel({
    super.key,
    required this.recipes,
    this.onTap,
    this.highlightTerms = const [],
  });

  final List<Recipe> recipes;
  final ValueChanged<Recipe>? onTap;
  final List<String> highlightTerms;

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) return const SizedBox.shrink();

    final topRecipes = recipes.take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        // เปลี่ยนมาใช้ .expand และแทรก SizedBox เพื่อสร้างระยะห่าง
        children: topRecipes.expand((recipe) {
          final index = topRecipes.indexOf(recipe);
          return [
            Expanded(
              child: _CardItem(
                recipe: recipe,
                rank: recipe.rank ?? (index + 1),
                highlightTerms: highlightTerms,
                onTap: onTap,
                edgeCropPct: 0.05, // ครอปขอบรูปเล็กน้อยเพื่อลบกรอบในไฟล์
              ),
            ),
            // เพิ่ม SizedBox คั่นกลาง ยกเว้นการ์ดใบสุดท้าย
            if (index < topRecipes.length - 1) const SizedBox(width: 12.0),
          ];
        }).toList(),
      ),
    );
  }
}

class _CardItem extends StatelessWidget {
  const _CardItem({
    required this.recipe,
    required this.rank,
    required this.highlightTerms,
    this.onTap,
    this.edgeCropPct = 0.0,
  });

  final Recipe recipe;
  final int rank;
  final List<String> highlightTerms;
  final ValueChanged<Recipe>? onTap;
  final double edgeCropPct;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // กล่องชื่อสูงประมาณ 2 บรรทัด (สเกลตามระบบ)
    final double titleBoxHeight =
        MediaQuery.textScalerOf(context).scale(46.0); // ≈ 18sp * 1.3 * 2

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap?.call(recipe),
        borderRadius: BorderRadius.circular(8),
        child: LayoutBuilder(
          builder: (context, cons) {
            final double side = cons.maxWidth; // ให้รูปเป็นสี่เหลี่ยมจัตุรัส
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: side,
                  height: side,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _recipeImage(recipe.imageUrl, cropPct: edgeCropPct),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: RankBadge(rank: rank),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // เปลี่ยนจาก Center -> Align(topCenter) ให้บรรทัดแรกตรงกันทุกใบ
                SizedBox(
                  height: titleBoxHeight,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: RichText(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      // ทำให้ line height คงที่และไม่ดันขอบบน/ล่างต่างกัน
                      strutStyle: StrutStyle(
                        forceStrutHeight: true,
                        height: 1.3,
                        leading: 0,
                        fontSize: textTheme.bodyMedium?.fontSize ?? 16,
                        fontFamily: textTheme.bodyMedium?.fontFamily,
                        fontWeight: textTheme.bodyMedium?.fontWeight,
                      ),
                      textHeightBehavior: const TextHeightBehavior(
                        applyHeightToFirstAscent: false,
                        applyHeightToLastDescent: false,
                      ),
                      text: highlightSpan(
                        recipe.name,
                        highlightTerms,
                        textTheme.bodyMedium!.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// ใช้ SafeImage เพื่อให้มี fallback เป็น asset เสมอ
  Widget _recipeImage(String url, {double cropPct = 0.0}) {
    final img = SafeImage(
      url: url,
      fit: BoxFit.cover,
      // ถ้าอยากเปลี่ยนไฟล์ fallback ที่การ์ดนี้ใช้ ให้ระบุที่นี่
      fallbackAsset: 'assets/images/default_recipe.png',
    );

    if (cropPct <= 0) return img;

    final double scale = 1.0 / (1.0 - cropPct); // 0.05 -> ~1.0526
    return ClipRect(
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.center,
        child: img,
      ),
    );
  }
}
