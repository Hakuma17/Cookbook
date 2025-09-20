// lib/widgets/cart_recipe_card.dart
import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../utils/safe_image.dart';

// ── ปรับค่าได้ง่าย ๆ ตรงนี้ ────────────────────────────
const double kCartCardWidth = 196; // ความกว้างการ์ดในลิสต์แนวนอน
const double kCartImageAspect = 1.44; // อัตราส่วนกว้าง/สูงของรูป (เดิม ~1.33)
//   ↑ 1.44 จะเตี้ยกว่ารูปเดิมเล็กน้อย → เหลือที่ให้ "ชื่อ" มากขึ้น
//     ถ้าอยากเตี้ยลงอีกลอง 1.48–1.52 ได้

class CartRecipeCard extends StatelessWidget {
  final CartItem cartItem;
  final VoidCallback onTapEditServings;
  final VoidCallback onDelete;

  const CartRecipeCard({
    super.key,
    required this.cartItem,
    required this.onTapEditServings,
    required this.onDelete,
  });

  void _openDetail(BuildContext context) {
    Navigator.pushNamed(context, '/recipe_detail',
        arguments: cartItem.recipeId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ts = theme.textTheme;

    return SizedBox(
      width: kCartCardWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            color: cs.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.outline, width: 1.6), //   กรอบชัด
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openDetail(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── รูปภาพเตี้ยลงเล็กน้อย ──
                  AspectRatio(
                    aspectRatio: kCartImageAspect, //   ลดความสูงรูป
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        SafeImage(
                          url: cartItem.imageUrl,
                          fit: BoxFit.cover,
                          error: Container(
                            color: cs.surfaceContainerHighest,
                            child: const Icon(Icons.no_photography_outlined),
                          ),
                          fallbackAsset: 'assets/images/default_recipe.png',
                        ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: InkWell(
                            onTap: onTapEditServings,
                            borderRadius: BorderRadius.circular(20),
                            child: Chip(
                              labelPadding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              avatar: Icon(Icons.person,
                                  size: 16, color: cs.onSecondaryContainer),
                              label: Text(
                                '${cartItem.nServings.round()} คน',
                                // ฟอนต์อ่านชัดขึ้น
                                style: ts.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.05,
                                  color: cs.onSecondaryContainer,
                                ),
                              ),
                              backgroundColor: cs.secondaryContainer,
                              side: BorderSide(
                                color: cs.outlineVariant.withValues(alpha: .7),
                              ),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── ชื่อเมนู (ใหญ่ขึ้น + ไม่ overflow) ──
                  Padding(
                    // ขยับให้มีลมหายใจ และไม่ชนขอบล่างของการ์ด
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Text(
                      cartItem.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ts.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.22,
                        fontSize: (ts.titleMedium?.fontSize ?? 16) + 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── ปุ่มลบ ──
          Positioned(
            top: -6,
            right: -6,
            child: IconButton(
              tooltip: 'ลบออกจากตะกร้า',
              onPressed: onDelete,
              icon: const Icon(Icons.close, size: 16),
              style: IconButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
                padding: const EdgeInsets.all(6),
                visualDensity: VisualDensity.compact,
                shape: const CircleBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ───── โค้ดเวอร์ชันเดิม (เผื่อย้อนกลับ)
  // SizedBox(height: 120) + ClipRRect ...
  // หรือ AspectRatio: 4/3 (1.333) ที่รูปสูงกว่า
──────────────────────────────────────── */
