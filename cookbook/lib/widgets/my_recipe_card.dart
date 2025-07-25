import 'package:flutter/material.dart';
import '../models/recipe.dart';

class MyRecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onTap;

  const MyRecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ 1. ลบ Manual Responsive Calculation และใช้ Theme
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    // ✅ 2. ใช้ Card -> InkWell -> Column เป็นโครงสร้างหลักที่สะอาดและเป็นมาตรฐาน
    return Card(
      clipBehavior: Clip.antiAlias, // ทำให้ ClipRRect ทำงานกับ Shape ของ Card
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- รูปภาพและ Allergy Badge ---
            // ✅ 3. ใช้ Expanded เพื่อให้รูปภาพยืดหยุ่นตามพื้นที่ที่เหลือ
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImage(),
                  if (recipe.hasAllergy)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Tooltip(
                        message: 'มีวัตถุดิบที่คุณอาจแพ้',
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: colorScheme.error,
                          child: Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: colorScheme.onError,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // --- ชื่อเมนู ---
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Text(
                recipe.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(height: 1.3),
              ),
            ),

            // --- คะแนน / รีวิว ---
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Icon(Icons.star_rounded,
                      size: 18, color: Colors.amber.shade700),
                  const SizedBox(width: 4),
                  Text(
                    recipe.averageRating.toStringAsFixed(1),
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${recipe.reviewCount} รีวิว)',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
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

  /* ───────────────────── helpers ───────────────────── */
  /// ✅ 4. ทำให้ Helper ง่ายขึ้นโดยไม่ต้องรับขนาด
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
