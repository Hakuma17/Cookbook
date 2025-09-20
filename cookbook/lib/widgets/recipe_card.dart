// lib/widgets/recipe_card.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../utils/format_utils.dart';
import '../stores/favorite_store.dart';
import '../services/auth_service.dart';
import 'rank_badge.dart';

// ★★★ [NEW] ใช้เรียก backend เพื่อรู้ผลจริงของการสลับหัวใจ
import '../services/api_service.dart';

// ★★★ [NEW] โหลดรูปให้ปลอดภัย (normalize URL + fallback asset)
import '../utils/safe_image.dart';

/* ════════════════════════════════════════════════════════ */

// ⬆️ ปรับความกว้างการ์ดแนวตั้งเพิ่มอีกนิด เพื่อให้แถว META (แบบที่ 1) โปร่งขึ้น
const double kRecipeCardVerticalWidth = 188;

// [NEW] อัตราส่วนรูปสำหรับการ์ดแนวตั้ง (ลดความสูงลงเล็กน้อย แต่คงอัตราส่วน)
// เดิมใช้ 1:1 → ตอนนี้ใช้ 4:3 เพื่อแก้ปัญหารูปสูงเกิน/overflow
const double kRecipeCardVerticalImageAspectRatio = 4 / 3;

// (removed) in-flight tracking handled at API/store level

class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
    this.compact = false,
    this.expanded = false,
  });

  final Recipe recipe;
  final VoidCallback? onTap;
  final bool compact;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompactCard(context);
    if (expanded) return _buildExpandedCard(context);
    return _buildVerticalCard(context);
  }

  // (removed) legacy _handleToggleFavorite (optimistic handled in _MetaOneLine)

  /* ───────────────────── VERTICAL ───────────────────── */
  Widget _buildVerticalCard(BuildContext context) {
    final theme = Theme.of(context);
    final favStore = context.watch<FavoriteStore>();
    final isFav = favStore.contains(recipe.id);

    // ★★★ [CHANGED] เลิกสูตรชดเชยเลขหัวใจ (±1/−1) เพื่อกัน desync
    // ใช้ค่าที่มากับ recipe ตรง ๆ; ถ้าต้องการเลขสดใหม่ ให้ parent รีเฟรชข้อมูล
    final favCount = recipe.favoriteCount;

    return SizedBox(
      width: kRecipeCardVerticalWidth,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  // [FIX] เดิมเป็น aspectRatio: 1 → ปรับเป็น 4:3
                  AspectRatio(
                    aspectRatio: kRecipeCardVerticalImageAspectRatio,
                    child: _RecipeImage(imageUrl: recipe.imageUrl),
                  ),
                  // [NEW] รวม Badge อันดับ + ป้ายเตือนแพ้ (วาง overlay แบบกินเต็มพื้นที่ภาพ)
                  _buildBadges(recipe),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Text(
                  recipe.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium, // อ่านชัด
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: _MetaOneLine(
                  //   แบบที่ 1 (ค่าเริ่มต้น)
                  key: ValueKey('v:${recipe.id}:$favCount'), // ★★★ [FIX]
                  recipeId: recipe.id, // [NEW]
                  rating: recipe.averageRating,
                  reviewCount: recipe.reviewCount,
                  favoriteCount: favCount,
                  isFavorited: isFav,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* ───────────────────── COMPACT ───────────────────── */
  Widget _buildCompactCard(BuildContext context) {
    final theme = Theme.of(context);
    final favStore = context.watch<FavoriteStore>();
    final isFav = favStore.contains(recipe.id);

    // ★★★ [CHANGED] ไม่ชดเชยเลขหัวใจ
    final favCount = recipe.favoriteCount;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _RecipeImage(imageUrl: recipe.imageUrl),
                ),
                _buildBadges(recipe),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Text(
                recipe.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: _MetaOneLine(
                key: ValueKey('c:${recipe.id}:$favCount'), // ★★★ [FIX]
                recipeId: recipe.id, // [NEW]
                rating: recipe.averageRating,
                reviewCount: recipe.reviewCount,
                favoriteCount: favCount,
                isFavorited: isFav,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ───────────────────── EXPANDED ───────────────────── */
  Widget _buildExpandedCard(BuildContext context) {
    final theme = Theme.of(context);
    final favStore = context.watch<FavoriteStore>();
    final isFav = favStore.contains(recipe.id);

    // ★★★ [CHANGED] ไม่ชดเชยเลขหัวใจ
    final favCount = recipe.favoriteCount;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _RecipeImage(imageUrl: recipe.imageUrl),
                ),
                _buildBadges(recipe),
              ],
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
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _MetaOneLine(
                    key: ValueKey('e:${recipe.id}:$favCount'), // ★★★ [FIX]
                    recipeId: recipe.id, // [NEW]
                    rating: recipe.averageRating,
                    reviewCount: recipe.reviewCount,
                    favoriteCount: favCount,
                    isFavorited: isFav,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ───────────────── helpers ───────────────── */

  // [NEW] แยก Badge อันดับซ้ายบน + ป้ายเตือนแพ้ขวาบน
  //   แก้สำคัญ: ใช้ Positioned.fill + IgnorePointer เพื่อให้ overlay มีขนาด finite เท่ารูป
  Widget _buildBadges(Recipe recipe) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            if (recipe.rank != null)
              Positioned(
                top: 8,
                left: 8,
                child: RankBadge(
                  rank: recipe.rank,
                  // ไม่ให้ RankBadge แสดง warning อีก เพื่อไม่ซ้ำกับป้ายขวาบน
                  showWarning: false,
                ),
              ),
            if (recipe.hasAllergy)
              const Positioned(
                top: 8,
                right: 8,
                child: _AllergyIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

/* ───────────── แยกรูปออกมาอ่านง่าย ───────────── */
class _RecipeImage extends StatelessWidget {
  const _RecipeImage({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    //   ใช้ SafeImage (จะ normalize URL และแก้ localhost ให้เอง)
    return SafeImage(
      url: imageUrl,
      fit: BoxFit.cover,
      fallbackAsset: 'assets/images/default_recipe.png',
    );
  }
}

/* ═════════ META: แบบที่ 1 (แถวเดียว) ปรับระยะให้หัวใจอยู่ใกล้ ─═════════
   รูปแบบ:  ⭐ 0.0 (3)   ❤ 12
   - กันพื้นที่ด้านขวาไว้พอสำหรับ ❤ + ตัวเลข ด้วย ConstrainedBox
   - ข้อความดาวใช้ FittedBox(scaleDown) → ไม่ขึ้น ... และไม่ดันหัวใจไปไกล
   - [NEW] ทำ Optimistic UI: เด้งเลข+สีทันที ระหว่างรอ API แล้ว sync/rollback ตามผล
*/
class _MetaOneLine extends StatefulWidget {
  const _MetaOneLine({
    Key? key,
    required this.recipeId, // [NEW]
    required this.rating,
    required this.reviewCount,
    required this.favoriteCount,
    required this.isFavorited,
  }) : super(key: key);

  final int recipeId; // [NEW]
  final double? rating;
  final int? reviewCount;
  final int? favoriteCount;
  final bool isFavorited;

  @override
  State<_MetaOneLine> createState() => _MetaOneLineState();
}

class _MetaOneLineState extends State<_MetaOneLine> {
  late bool _isFav; // สถานะหัวใจเฉพาะแถวนี้
  late int _favCnt; // จำนวนหัวใจเฉพาะแถวนี้
  bool _busy = false; // กันกดซ้อน

  @override
  void initState() {
    super.initState();
    _isFav = widget.isFavorited;
    _favCnt = widget.favoriteCount ?? 0;
  }

  // [NEW] ซิงค์ state ภายในเมื่อ parent ส่งค่ามาใหม่ (เช่น กลับจากหน้าอื่น/หลัง login)
  @override
  void didUpdateWidget(covariant _MetaOneLine oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 1) ถ้าเป็น "การ์ดคนละเมนู" → reset ตามค่าที่พ่อส่งมา
    if (widget.recipeId != oldWidget.recipeId) {
      setState(() {
        _isFav = widget.isFavorited;
        _favCnt = widget.favoriteCount ?? 0;
      });
      return;
    }

    // 2) ★★★ [FIX] ถ้าเลข favorite จากพาเรนต์ "เปลี่ยน" และไม่ได้กำลังกดอยู่ → รับเลขใหม่
    if (!_busy &&
        (widget.favoriteCount ?? 0) != (oldWidget.favoriteCount ?? 0)) {
      setState(() => _favCnt = widget.favoriteCount ?? _favCnt);
    }

    // 3) ★★★ [FIX] ถ้าเลขจากพาเรนต์ "ไม่เปลี่ยน" แต่สถานะหัวใจจากพาเรนต์เปลี่ยน
    // (เช่น กลับจากหน้า Detail ที่ไม่ได้ป้อนเลขกลับมา) → ปรับเลขตาม delta
    if (!_busy && widget.isFavorited != _isFav) {
      final becameFav = widget.isFavorited && !_isFav;
      final becameUnfav = !widget.isFavorited && _isFav;
      final nextCnt = _favCnt + (becameFav ? 1 : 0) - (becameUnfav ? 1 : 0);
      setState(() {
        _isFav = widget.isFavorited;
        _favCnt = nextCnt < 0 ? 0 : nextCnt; // กันติดลบ
      });
    } else if (widget.isFavorited != _isFav) {
      // สีหัวใจต้องตามพาเรนต์เสมอ
      setState(() => _isFav = widget.isFavorited);
    }
  }

  Future<void> _toggle() async {
    if (_busy) return;

    // ต้องล็อกอินก่อน
    if (!await AuthService.isLoggedIn()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อน')),
      );
      Navigator.pushNamed(context, '/login');
      return;
    }

    final desired = !_isFav;

    // [FIX] Optimistic UI: คิดเลขไว้ก่อน แล้วกันติดลบ
    final optimistic = desired ? _favCnt + 1 : (_favCnt > 0 ? _favCnt - 1 : 0);

    setState(() {
      _busy = true;
      _isFav = desired;
      _favCnt = optimistic; // เด้งทันที
    });

    try {
      final r = await ApiService.toggleFavorite(widget.recipeId, desired);

      // [FIX] Sync เฉพาะสถานะหัวใจตามผลจริง แต่ "คงเลข optimistic"
      if (!mounted) return;
      setState(() {
        _isFav = r.isFavorited; // สีไอคอนเชื่อผลจริง
        _favCnt = optimistic; // ไม่ใช้ r.favoriteCount ที่อาจยังไม่อัปเดตทัน
      });

      // แจ้ง Store กลาง ให้การ์ด/หน้าอื่น ๆ เปลี่ยนตาม
      await context.read<FavoriteStore>().set(widget.recipeId, r.isFavorited);
    } on UnauthorizedException {
      if (!mounted) return;
      // rollback
      setState(() {
        _isFav = !desired;
        _favCnt = _favCnt + (desired ? -1 : 1);
        if (_favCnt < 0) _favCnt = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session หมดอายุ กรุณาเข้าสู่ระบบใหม่')),
      );
      Navigator.pushNamed(context, '/login');
    } catch (_) {
      if (!mounted) return;
      // rollback
      setState(() {
        _isFav = !desired;
        _favCnt = _favCnt + (desired ? -1 : 1);
        if (_favCnt < 0) _favCnt = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกเมนูโปรดไม่สำเร็จ')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme.bodyMedium!;
    final cs = Theme.of(context).colorScheme;

    final double safeRating = (widget.rating ?? 0).toDouble();
    final int safeReview = widget.reviewCount ?? 0;
    final ratingText =
        '${safeRating.toStringAsFixed(1)}  (${formatCount(safeReview)})';

    // กันพื้นที่ด้านขวาประมาณนี้ (ไอคอนหัวใจ 16 + ช่องไฟ + ตัวเลข 3–4 หลัก)
    const double kRightMetaReserve = 64; // ปรับได้ 56–72 ตามธีม/ฟอนต์

    return LayoutBuilder(
      builder: (context, c) {
        final maxTextW =
            (c.maxWidth - kRightMetaReserve).clamp(40.0, c.maxWidth);

        return Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(Icons.star, size: 16, color: Colors.amber.shade700),
            const SizedBox(width: 6),

            // ข้อความดาว: จำกัดความกว้างสูงสุดไว้ ไม่ปล่อยให้กินพื้นที่ทั้งแถว
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxTextW),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  ratingText,
                  style: ts.copyWith(fontWeight: FontWeight.w700, height: 1.1),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // กลุ่มหัวใจ + จำนวน (อยู่ “ใกล้” เพราะด้านซ้ายไม่ขยายเต็ม)
            InkWell(
              onTap: _busy ? null : _toggle, // ← กดแล้วเด้งทันที
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isFav ? Icons.favorite : Icons.favorite_border,
                      size: 16,
                      color: _isFav ? cs.primary : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      formatCount(_favCnt),
                      style: ts.copyWith(
                        color: _isFav ? cs.primary : cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/* ─────────────────────────────────────────────────────────────
 * Small allergy indicator — ป้ายเตือนขนาดเล็กที่มุมขวาบน
 * - ใช้ไอคอน warning พร้อม Tooltip
 * - มี Semantics สำหรับผู้อ่านหน้าจอ
 * - สีสอดคล้องกับธีม แต่คงอ่านได้ชัดบนภาพ
 * ──────────────────────────────────────────────────────────── */
class _AllergyIndicator extends StatelessWidget {
  const _AllergyIndicator();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: 'มีส่วนผสมที่คุณแพ้',
      child: Tooltip(
        message: 'มีส่วนผสมที่คุณแพ้',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: cs.errorContainer.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: cs.error.withValues(alpha: .6), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 14, color: cs.onErrorContainer),
              const SizedBox(width: 4),
              Text(
                'ระวังแพ้',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.0,
                  fontWeight: FontWeight.w700,
                  color: cs.onErrorContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
