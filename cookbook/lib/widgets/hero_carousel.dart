import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../utils/highlight_span.dart';
import 'rank_badge.dart';

/// แคโรเซล 1 แถว (สูงสุด 3 การ์ด) ใช้โชว์ “เมนูแนะนำ”
class HeroCarousel extends StatelessWidget {
  final List<Recipe> recipes;
  final ValueChanged<Recipe>? onTap;
  final List<String> highlightTerms;

  const HeroCarousel({
    super.key,
    required this.recipes,
    this.onTap,
    this.highlightTerms = const [],
  });

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return const SizedBox.shrink();
    }

    // ✅ 1. ลบ Manual Responsive Calculation ทั้งหมด
    // เราจะใช้ Row + Expanded เพื่อให้ Flutter จัดการการแบ่งพื้นที่ให้เอง

    // แสดงผลสูงสุด 3 การ์ด
    final topRecipes = recipes.take(3).toList();

    return Padding(
      // ✅ 2. ใช้ Padding แบบคงที่
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: Row(
        // ใช้ MainAxisAlignment.center เพื่อจัดกลางกรณีมีการ์ดไม่เต็มแถว
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(topRecipes.length, (index) {
          final recipe = topRecipes[index];

          return Expanded(
            child: Padding(
              // เพิ่มช่องว่างระหว่างการ์ด (ยกเว้นการ์ดแรก)
              padding: EdgeInsets.only(left: index == 0 ? 0 : 8.0),
              child: _buildRecipeCard(context, recipe, index),
            ),
          );
        }),
      ),
    );
  }

  /// ✅ 3. แยก UI ของการ์ดแต่ละใบออกมาเป็น Helper Function และใช้ Theme
  Widget _buildRecipeCard(BuildContext context, Recipe recipe, int index) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return GestureDetector(
      onTap: () => onTap?.call(recipe),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- รูป + Badge ---
          Stack(
            children: [
              // ✅ 4. ใช้ AspectRatio เพื่อรักษาสัดส่วนของรูปให้เป็นสี่เหลี่ยมจัตุรัสเสมอ
              AspectRatio(
                aspectRatio: 1.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _recipeImage(recipe.imageUrl),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: RankBadge(rank: recipe.rank ?? (index + 1)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // --- ชื่อเมนู ---
          RichText(
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            text: highlightSpan(
              recipe.name,
              highlightTerms,
              // ✅ 5. ใช้ TextStyle จาก Theme ส่วนกลาง
              textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recipeImage(String url) {
    return url.isNotEmpty
        ? Image.network(
            url,
            fit: BoxFit.cover,
            // เพิ่ม loadingBuilder เพื่อ UX ที่ดีขึ้น
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2));
            },
            errorBuilder: (_, __, ___) => _fallbackImage(),
          )
        : _fallbackImage();
  }

  Widget _fallbackImage() => Image.asset(
        'assets/images/default_recipe.png',
        fit: BoxFit.cover,
      );
}
