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

  // 🗑️ 1. ลบ Helper สำหรับสร้าง Style และ Responsive ทั้งหมด
  //    เพราะจะเปลี่ยนไปใช้ Theme จาก context โดยตรง

  /* ───────────────────────── build ───────────────────────── */
  @override
  Widget build(BuildContext context) {
    // ✅ 2. ลบ LayoutBuilder และการคำนวณทั้งหมด
    //    เลือก build method ที่เหมาะสมตาม flag ที่ได้รับมา
    if (compact) {
      return _buildCompactCard(context);
    }
    if (expanded) {
      return _buildExpandedCard(context);
    }
    return _buildVerticalCard(context);
  }

  /* ╔═══════════════════ 1. Vertical Card ═══════════════════╗ */
  /// การ์ดแนวตั้งขนาดเล็ก สำหรับใช้ใน Horizontal ListView
  Widget _buildVerticalCard(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return SizedBox(
      width: 145, // กำหนดความกว้างคงที่
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.0, // ทำให้รูปเป็นสี่เหลี่ยมจัตุรัส
                    child: _buildImage(),
                  ),
                  _buildBadge(),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Text(
                  recipe.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: _buildRatingRow(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* ╔═══════════════════ 2. Compact Card ════════════════════╗ */
  /// การ์ดแนวนอน สำหรับใช้ใน Vertical ListView (เช่น หน้าผลการค้นหา)
  Widget _buildCompactCard(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9, // สัดส่วนรูปภาพยอดนิยม
                  child: _buildImage(),
                ),
                _buildBadge(),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Text(
                recipe.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium,
              ),
            ),
            if (recipe.shortIngredients.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  recipe.shortIngredients,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: _buildRatingRow(context),
            ),
          ],
        ),
      ),
    );
  }

  /* ╔═══════════════════ 3. Expanded Card ═══════════════════╗ */
  /// การ์ดแนวนอนแบบมีรายละเอียดมากขึ้น
  Widget _buildExpandedCard(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _buildImage(),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  if (recipe.shortIngredients.isNotEmpty)
                    Text(
                      recipe.shortIngredients,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (recipe.prepTime > 0) ...[
                        Icon(Icons.access_time,
                            size: 16, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text('${recipe.prepTime} นาที',
                            style: textTheme.bodySmall),
                        const SizedBox(width: 12),
                      ],
                      Icon(Icons.star, size: 16, color: Colors.amber.shade700),
                      const SizedBox(width: 4),
                      Text(recipe.averageRating.toStringAsFixed(1),
                          style: textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      Icon(Icons.comment_outlined,
                          size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(formatCount(recipe.reviewCount),
                          style: textTheme.bodySmall),
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

  /* ───────────────────── secondary widgets ───────────────────── */
  Widget _buildBadge() {
    if (recipe.rank == null && !recipe.hasAllergy)
      return const SizedBox.shrink();
    return Positioned(
      top: 8,
      left: 8,
      child: RankBadge(rank: recipe.rank, showWarning: recipe.hasAllergy),
    );
  }

  Widget _buildRatingRow(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(Icons.star_rounded, size: 18, color: Colors.amber.shade700),
        const SizedBox(width: 4),
        Text(recipe.averageRating.toStringAsFixed(1),
            style: textTheme.bodyMedium),
        const SizedBox(width: 6),
        Text('${recipe.reviewCount} รีวิว', style: textTheme.bodySmall),
      ],
    );
  }

  Widget _buildImage() {
    if (recipe.imageUrl.isNotEmpty) {
      return Image.network(
        recipe.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackImage(),
      );
    }
    return _fallbackImage();
  }

  Widget _fallbackImage() => Image.asset(
        'assets/images/default_recipe.png',
        fit: BoxFit.cover,
      );
}
