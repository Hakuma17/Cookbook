import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // [NEW] สำหรับ FavoriteStore (เฉพาะตอนใช้หัวใจ)
import '../models/recipe.dart';
import '../utils/format_utils.dart'; // formatCount: 1200 -> 1.2K
import '../utils/safe_image.dart';

// [NEW] ใช้เมื่อเปิดหัวใจ (เวอร์ชัน MyRecipeCardHeart)
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../stores/favorite_store.dart';

/* ═══════════════════════════════════════════════════════════
   เวอร์ชันเดิม (ดาวอย่างเดียว) — ใช้อยู่ในหน้า “ของฉัน”
   ไม่เปลี่ยนพฤติกรรมเดิมเพื่อความเข้ากันได้
════════════════════════════════════════════════════════════ */
class MyRecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onTap;

  // ─────────────────────────────────────────────────────────
  // ⭐ [OPTIONAL PARAMS] สำหรับ “หัวใจ (ปิดไว้ก่อน)”
  // หมายเหตุ: ตัวแปรด้านล่างถูกคอมเมนต์ไว้ เพื่อไม่ให้มีผลกับ
  // พฤติกรรมเดิม จนกว่าคุณจะ “เปิดใช้งานหัวใจ” เอง
  //
  // 1) ยกเลิกคอมเมนต์บรรทัด 1–3 ด้านล่าง
  // 2) ดูส่วน build() ด้านล่างหัวข้อ:
  //    // ⭐ [OPTIONAL] ช่องหัวใจ (ปิดไว้ก่อน)
  //    แล้วสลับจาก _MetaStarOnly เป็น _MetaStarPlusHeart
  //
  // final VoidCallback? onHeartTap;   // ถ้าส่งมา จะทำให้หัวใจกดได้
  // final bool? isFavoritedOverride;  // ถ้าต้องการบังคับสถานะจากภายนอก
  // final int? favoriteCountOverride; // ถ้าต้องการบังคับยอดจากภายนอก
  // ─────────────────────────────────────────────────────────

  // ─────────────────────────────────────────────────────────
  //   [NEW] พารามิเตอร์สำหรับ “โหมดเลือกหลายรายการ”
  // - ไม่ส่ง/ปล่อยดีฟอลต์ → พฤติกรรมเดิมทั้งหมด
  // - หากส่ง selectionMode=true → onTap จะกลายเป็น onSelectToggle
  //   และจะแสดงติ๊กมุมขวาบน + กรอบเปลี่ยนสีเมื่อ selected=true
  final bool selectionMode; // อยู่ในโหมดเลือกหรือไม่
  final bool selected; // ใบนี้ถูกเลือกอยู่ไหม
  final VoidCallback? onSelectToggle; // แตะเพื่อเลือก/ยกเลิกเลือก
  final VoidCallback? onLongPress; // กดค้างเพื่อ “เข้าโหมดเลือก”
  // ─────────────────────────────────────────────────────────

  const MyRecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
    // this.onHeartTap,               // ← เปิดหัวใจ: ยกเลิกคอมเมนต์เมื่อพร้อมใช้งาน
    // this.isFavoritedOverride,      // ← (ตัวเลือก)
    // this.favoriteCountOverride,    // ← (ตัวเลือก)

    // [NEW] selection mode defaults
    this.selectionMode = false,
    this.selected = false,
    this.onSelectToggle,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final cs = theme.colorScheme;

    // ค่าเริ่มต้นของหัวใจ (สำหรับกรณีเปิดใช้งานในอนาคต)
    // final bool isFav = isFavoritedOverride ?? (recipe.isFavorited ?? false);
    // final int favCount = favoriteCountOverride ?? (recipe.favoriteCount ?? 0);

    // [NEW] สีกรอบเปลี่ยนตามสถานะเลือก
    final borderColor =
        selected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.95);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: borderColor, // [NEW]
          width: 1.25,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // [NEW] ถ้าอยู่ในโหมดเลือก ให้แตะเพื่อ toggle เลือกแทนการเปิดรายละเอียด
        onTap: selectionMode ? onSelectToggle : onTap,
        // [NEW] กดค้างเพื่อ “เข้าโหมดเลือก”
        onLongPress: onLongPress,
        child: Stack(
          children: [
            // ───────── เนื้อการ์ดเดิม ─────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // รูปสูงเท่ากันทุกใบ
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildImage(recipe.imageUrl),
                      if (recipe.hasAllergy) _AllergyBadge(),
                    ],
                  ),
                ),
                // ชื่อ
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                  child: Text(
                    recipe.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.22,
                    ),
                  ),
                ),

                // ─────────────────────────────────────────────────────────
                // META ZONE
                // ─────────────────────────────────────────────────────────

                // (A) เวอร์ชันเดิม: ดาวอย่างเดียว (แสดงผลปัจจุบัน)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: _MetaStarOnly(
                    rating: recipe.averageRating,
                    reviewCount: recipe.reviewCount,
                  ),
                ),

                // ─────────────────────────────────────────────────────────
                // ⭐ [OPTIONAL] ช่องหัวใจ (ปิดไว้ก่อน)
                //
                // หากต้องการ “เปิดใช้งานหัวใจ” ในการ์ดนี้:
                // 1) คอมเมนต์บล็อก _MetaStarOnly ด้านบน (A)
                // 2) ยกเลิกคอมเมนต์บล็อกด้านล่าง (B)
                // 3) (ตัวเลือก) ส่ง onHeartTap / isFavoritedOverride / favoriteCountOverride
                //    มายังการ์ดนี้เพื่อควบคุมการทำงาน (หรือปล่อยให้ใช้ค่าใน recipe)
                //
                // หมายเหตุ: ถ้าต้องการ “เด้งเลขทันที + ยิง API ให้อัตโนมัติ”
                // แนะนำใช้คลาส MyRecipeCardHeart ด้านล่าง ซึ่งทำ Optimistic UI ให้เรียบร้อย
                //
                // (B) เวอร์ชันใหม่: ดาว + หัวใจ (ยกเลิกคอมเมนต์เพื่อใช้งาน)
                /*
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: _MetaStarPlusHeart(
                    rating: recipe.averageRating,
                    reviewCount: recipe.reviewCount,
                    favoriteCount: favCount,
                    isFavorited: isFav,
                    onHeartTap: onHeartTap, // ถ้า null = ดูอย่างเดียว
                  ),
                ),
                */
                // ─────────────────────────────────────────────────────────
              ],
            ),

            // ───────── [NEW] ติ๊กถูกมุมขวาบน เมื่ออยู่ในโหมดเลือก ─────────
            if (selectionMode)
              Positioned(
                top: 8,
                right: 8,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: selected ? cs.primary : cs.surface,
                    border: Border.all(
                      color: selected ? cs.primary : cs.outlineVariant,
                      width: 1.1,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    selected ? Icons.check : Icons.radio_button_unchecked,
                    size: 18,
                    color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/* ═══════════════════════════════════════════════════════════
   เวอร์ชันใหม่ (มีหัวใจ) — ใช้เมื่ออยากโชว์ ❤ และจำนวน
   - onHeartTap = null จะเป็น “ดูอย่างเดียว”
   - isFavorited จะเปลี่ยนสีไอคอน/เลข
   - [NEW] เวอร์ชันนี้ทำ Optimistic UI ภายใน: เด้งเลข/สีทันที + ยิง API + sync Store
════════════════════════════════════════════════════════════ */
class MyRecipeCardHeart extends StatefulWidget {
  final Recipe recipe;
  final VoidCallback? onTap;

  /// ถ้าอยากให้กดหัวใจได้ ให้ส่ง callback มาด้วย (เช่น toggle)
  /// ถ้าไม่ส่ง (null) จะใช้ handler ภายในที่ทำ Optimistic UI ให้
  final VoidCallback? onHeartTap;

  // [NEW] (ตัวเลือก) รองรับโหมดเลือกเหมือน MyRecipeCard
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onLongPress;

  const MyRecipeCardHeart({
    super.key,
    required this.recipe,
    this.onTap,
    this.onHeartTap,
    // [NEW] defaults
    this.selectionMode = false,
    this.selected = false,
    this.onSelectToggle,
    this.onLongPress,
  });

  @override
  State<MyRecipeCardHeart> createState() => _MyRecipeCardHeartState();
}

class _MyRecipeCardHeartState extends State<MyRecipeCardHeart> {
  // [NEW] เก็บสถานะหัวใจภายใน เพื่อให้เด้งทันที
  late bool _isFav;
  late int _favCount;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _isFav = widget.recipe.isFavorited;
    _favCount = widget.recipe.favoriteCount;
  }

  Future<void> _toggleFavorite() async {
    if (_busy) return;

    // ถ้ามี callback จากภายนอก ให้เรียกใช้แล้วจบ (โหมด custom)
    if (widget.onHeartTap != null) {
      widget.onHeartTap!();
      return;
    }

    // ถ้าไม่มี callback → ใช้ handler ภายใน (Optimistic UI)
    if (!await AuthService.isLoggedIn()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อน')),
      );
      Navigator.pushNamed(context, '/login');
      return;
    }

    final desired = !_isFav;

    setState(() {
      _busy = true;
      _isFav = desired; // เด้งทันที
      _favCount += desired ? 1 : -1; // เด้งทันที
    });

    try {
      final r = await ApiService.toggleFavorite(widget.recipe.id, desired);

      if (!mounted) return;
      setState(() {
        _isFav = r.isFavorited; // sync ตามผลจริง
        _favCount = r.favoriteCount; // sync ตามผลจริง
      });

      await context.read<FavoriteStore>().set(widget.recipe.id, r.isFavorited);
    } catch (_) {
      if (!mounted) return;
      // rollback
      setState(() {
        _isFav = !desired;
        _favCount += desired ? -1 : 1;
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
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final cs = theme.colorScheme;

    final borderColor = widget.selected
        ? cs.primary
        : cs.outlineVariant.withValues(alpha: 0.95);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: borderColor, // [NEW]
          width: 1.25,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // [NEW] รองรับโหมดเลือก
        onTap: widget.selectionMode ? widget.onSelectToggle : widget.onTap,
        onLongPress: widget.onLongPress,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildImage(widget.recipe.imageUrl),
                      if (widget.recipe.hasAllergy) _AllergyBadge(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                  child: Text(
                    widget.recipe.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.22,
                    ),
                  ),
                ),
                // META: ดาว + หัวใจ (แถวเดียวแบบชิด ๆ)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: _MetaStarPlusHeart(
                    rating: widget.recipe.averageRating,
                    reviewCount: widget.recipe.reviewCount,
                    favoriteCount: _favCount, // [CHANGED] ใช้ state ภายใน
                    isFavorited: _isFav, // [CHANGED] ใช้ state ภายใน
                    onHeartTap:
                        _busy ? null : _toggleFavorite, // [NEW] กดแล้วเด้งทันที
                  ),
                ),
              ],
            ),

            // [NEW] ติ๊กถูกมุมขวาบน เมื่ออยู่ในโหมดเลือก
            if (widget.selectionMode)
              Positioned(
                top: 8,
                right: 8,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: widget.selected ? cs.primary : cs.surface,
                    border: Border.all(
                      color: widget.selected ? cs.primary : cs.outlineVariant,
                      width: 1.1,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    widget.selected
                        ? Icons.check
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: widget.selected ? cs.onPrimary : cs.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/* ─────────────────── common helpers ─────────────────── */
class _AllergyBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      top: 8,
      left: 8,
      child: Tooltip(
        message: 'มีวัตถุดิบที่คุณอาจแพ้',
        child: CircleAvatar(
          radius: 14,
          backgroundColor: cs.error,
          child: const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

Widget _buildImage(String imageUrl) {
  return SafeImage(
    url: imageUrl.isNotEmpty ? imageUrl : 'assets/images/default_recipe.png',
    fit: BoxFit.cover,
  );
}

/* ───────────── META: ดาวอย่างเดียว ───────────── */
class _MetaStarOnly extends StatelessWidget {
  const _MetaStarOnly({required this.rating, required this.reviewCount});
  final double? rating;
  final int? reviewCount;

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme.bodyMedium!;
    final double safeRating = (rating ?? 0).toDouble();
    final int safeReview = reviewCount ?? 0;

    final text =
        '${safeRating.toStringAsFixed(1)}  (${formatCount(safeReview)})';

    return Row(
      children: [
        Icon(Icons.star_rounded, size: 18, color: Colors.amber.shade700),
        const SizedBox(width: 6),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              maxLines: 1,
              style: ts.copyWith(fontWeight: FontWeight.w700, height: 1.1),
            ),
          ),
        ),
      ],
    );
  }
}

/* ─────────── META: ดาว + หัวใจ (แถวเดียวแบบชิด) ───────────
   รูปแบบ:  ⭐ 4.5 (2)   ❤ 1.2K
   - ส่วนดาวใช้ Expanded + FittedBox → ไม่ดันสูงและไม่ชนหัวใจ
   - ส่วนหัวใจคลิกได้เมื่อมี onHeartTap; ถ้า null จะเป็นดูอย่างเดียว
*/
class _MetaStarPlusHeart extends StatelessWidget {
  const _MetaStarPlusHeart({
    required this.rating,
    required this.reviewCount,
    required this.favoriteCount,
    required this.isFavorited,
    this.onHeartTap,
  });

  final double? rating;
  final int? reviewCount;
  final int favoriteCount;
  final bool isFavorited;
  final VoidCallback? onHeartTap;

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme.bodyMedium!;
    final cs = Theme.of(context).colorScheme;

    final double safeRating = (rating ?? 0).toDouble();
    final int safeReview = reviewCount ?? 0;

    final ratingText =
        '${safeRating.toStringAsFixed(1)}  (${formatCount(safeReview)})';

    final heartColor = isFavorited ? cs.primary : cs.onSurfaceVariant;

    final heartView = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(isFavorited ? Icons.favorite : Icons.favorite_border,
            size: 16, color: heartColor),
        const SizedBox(width: 6),
        Text(
          formatCount(favoriteCount),
          style: ts.copyWith(
            color: heartColor,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
      ],
    );

    return Row(
      children: [
        Icon(Icons.star_rounded, size: 18, color: Colors.amber.shade700),
        const SizedBox(width: 6),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              ratingText,
              maxLines: 1,
              style: ts.copyWith(fontWeight: FontWeight.w700, height: 1.1),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (onHeartTap == null)
          heartView
        else
          InkWell(
            onTap: onHeartTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: heartView,
            ),
          ),
      ],
    );
  }
}
