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

/* ════════════════════════════════════════════════════════ */

// ⬆️ ปรับความกว้างการ์ดแนวตั้งเพิ่มอีกนิด เพื่อให้แถว META (แบบที่ 1) โปร่งขึ้น
const double kRecipeCardVerticalWidth = 188;

// ★★★ [NEW] กันยิงคำขอซ้ำตอนผู้ใช้กดหัวใจรัว ๆ ต่อเมนูเดียวกัน
// [NOTE] หลังปรับไปใช้ Optimistic UI ใน _MetaOneLine แล้ว ตัวแปรนี้ไม่ถูกใช้ในไฟล์นี้
final Set<int> _favInFlight = <int>{};

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

  // ★★★ [NEW] รวมลอจิก toggle หัวใจไว้ที่เดียว (รอผลจริง + กันซ้อน)
  // [NOTE] เวอร์ชัน Optimistic UI ย้ายไปจัดการภายใน _MetaOneLine แล้ว
  // ฟังก์ชันนี้คงไว้เพื่อความเข้ากันได้ (เผื่อเรียกใช้จากที่อื่น)
  Future<void> _handleToggleFavorite(BuildContext context) async {
    // เช็กล็อกอินตามเดิม
    if (!await AuthService.isLoggedIn()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อน')),
        );
        Navigator.pushNamed(context, '/login');
      }
      return;
    }

    // กันยิงซ้ำเมนูเดียวกัน
    if (_favInFlight.contains(recipe.id)) return;
    _favInFlight.add(recipe.id);

    final favStore = context.read<FavoriteStore>();
    final bool desired = !favStore.contains(recipe.id);

    try {
      // ★★★ [CHANGED] เดิม fire-and-forget → ตอนนี้รอผลจริงจาก backend
      final result = await ApiService.toggleFavorite(recipe.id, desired);

      // ★★★ [CHANGED] อัปเดต store ตาม "ผลจริง" เพื่อลด desync
      await favStore.set(recipe.id, result.isFavorited);

      // หมายเหตุ: ถ้าต้องลบการ์ดในหน้า Favorites ทันที
      // ให้หน้าแม่ (screen) ส่ง callback มาที่การ์ด หรือจัดการ removeWhere ที่หน้าลิสต์
      // เมื่อ result.isFavorited == false
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกเมนูโปรดไม่สำเร็จ')),
        );
      }
    } finally {
      _favInFlight.remove(recipe.id);
    }
  }

  /* ───────────────────── VERTICAL ───────────────────── */
  Widget _buildVerticalCard(BuildContext context) {
    final theme = Theme.of(context);
    final favStore = context.watch<FavoriteStore>();
    final isFav = favStore.contains(recipe.id);

    // ★★★ [CHANGED] เลิกสูตรชดเชยเลขหัวใจ (±1/−1) เพื่อกัน desync
    // ใช้ค่าที่มากับ recipe ตรง ๆ; ถ้าต้องการเลขสดใหม่ ให้ parent รีเฟรชข้อมูล
    final favCount = (recipe.favoriteCount ?? 0);

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
                  AspectRatio(
                    aspectRatio: 1,
                    child: _RecipeImage(imageUrl: recipe.imageUrl),
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
                  style: theme.textTheme.titleMedium, // อ่านชัด
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: _MetaOneLine(
                  // ✅ แบบที่ 1 (ค่าเริ่มต้น)
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
    final favCount = (recipe.favoriteCount ?? 0);

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
                _buildBadge(),
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
    final favCount = (recipe.favoriteCount ?? 0);

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
                _buildBadge(),
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
  Widget _buildBadge() {
    if (recipe.rank == null && !recipe.hasAllergy) {
      return const SizedBox.shrink();
    }
    return Positioned(
      top: 8,
      left: 8,
      child: RankBadge(
        rank: recipe.rank,
        showWarning: recipe.hasAllergy,
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
    if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Image.asset('assets/images/default_recipe.png', fit: BoxFit.cover),
      );
    }
    return Image.asset('assets/images/default_recipe.png', fit: BoxFit.cover);
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
    required this.recipeId, // [NEW]
    required this.rating,
    required this.reviewCount,
    required this.favoriteCount,
    required this.isFavorited,
  });

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

    // Optimistic: เปลี่ยนทันที
    setState(() {
      _busy = true;
      _isFav = desired;
      _favCnt += desired ? 1 : -1;
    });

    try {
      final r = await ApiService.toggleFavorite(widget.recipeId, desired);

      // Sync ตามผลจริง (กัน desync เมื่อผู้ใช้กดเร็ว/หลายครั้ง)
      if (!mounted) return;
      setState(() {
        _isFav = r.isFavorited;
        _favCnt = r.favoriteCount;
      });

      // แจ้ง Store กลาง ให้การ์ด/หน้าอื่น ๆ เปลี่ยนตาม
      await context.read<FavoriteStore>().set(widget.recipeId, r.isFavorited);
    } on UnauthorizedException {
      if (!mounted) return;
      // rollback
      setState(() {
        _isFav = !desired;
        _favCnt += desired ? -1 : 1;
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
        _favCnt += desired ? -1 : 1;
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
            // *** [OPTIONAL] ปิดหัวใจชั่วคราว: คอมเมนต์ InkWell ทั้งก้อน แล้วแทนด้วย heartView เฉย ๆ ***
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

/* ───────────────────────────────
   // แบบที่ 2 (สองแถว) — เก็บไว้ก่อน เผื่อสลับใช้
   //
   // ดาว 0.0 (3)
   // หัวใจ 2
   //
   // ใช้แทน _MetaOneLine ได้ทันทีโดยเปลี่ยนชื่อที่จุดเรียก
   class _MetaTwoLines extends StatelessWidget {
     const _MetaTwoLines({
       required this.rating,
       required this.reviewCount,
       required this.favoriteCount,
       required this.isFavorited,
       required this.onToggle,
     });

     final double? rating;
     final int? reviewCount;
     final int? favoriteCount;
     final bool isFavorited;
     final VoidCallback onToggle;

     @override
     Widget build(BuildContext context) {
       final ts = Theme.of(context).textTheme.bodyMedium!;
       final cs = Theme.of(context).colorScheme;

       final double safeRating = (rating ?? 0).toDouble();
       final int safeReview = reviewCount ?? 0;
       final int safeFav = favoriteCount ?? 0;

       return Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Row(
             children: [
               Icon(Icons.star, size: 16, color: Colors.amber.shade700),
               const SizedBox(width: 6),
               Text('${safeRating.toStringAsFixed(1)}  (${formatCount(safeReview)})',
                    style: ts.copyWith(fontWeight: FontWeight.w700)),
             ],
           ),
           const SizedBox(height: 4),
           Row(
             children: [
               Icon(Icons.favorite, size: 14, color: isFavorited ? cs.primary : cs.onSurfaceVariant),
               const SizedBox(width: 6),
               Text(formatCount(safeFav), style: ts),
             ],
           ),
         ],
       );
     }
   }
   ─────────────────────────────── */
