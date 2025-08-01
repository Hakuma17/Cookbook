// lib/widgets/search_recipe_card.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../stores/favorite_store.dart'; // ✅ ใช้ store กลาง
import '../utils/format_utils.dart';
import '../utils/highlight_span.dart';
import 'rank_badge.dart';

// ★★★ [NEW] กันยิงคำขอซ้ำตอนผู้ใช้กดหัวใจรัว ๆ ต่อเมนูเดียวกัน
// [NOTE] หลังย้ายไปทำ Optimistic UI ใน _MetaRow แล้ว ตัวแปรนี้ไม่จำเป็นต้องใช้ในไฟล์นี้
final Set<int> _favInFlightSearch = <int>{};

class SearchRecipeCard extends StatelessWidget {
  final Recipe recipe;
  final List<String> highlightTerms;
  final int? rankOverride;
  final bool compact;
  final bool expanded;
  final VoidCallback? onTap;
  final bool highlightEnabled;

  const SearchRecipeCard({
    super.key,
    required this.recipe,
    this.highlightTerms = const [],
    this.rankOverride,
    this.compact = false,
    this.expanded = false,
    this.onTap,
    this.highlightEnabled = true,
  });

  // ★★★ [NEW] รวมลอจิก toggle หัวใจไว้ที่เดียว (รอผลจริง + กันซ้อน)
  // [NOTE] เวอร์ชัน Optimistic UI จะจัดการภายใน _MetaRow แทน ฟังก์ชันนี้คงไว้เพื่อความเข้ากันได้
  Future<void> _handleToggleFavorite(BuildContext context) async {
    if (!await AuthService.isLoggedIn()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('กรุณาเข้าสู่ระบบก่อน'),
          ),
        );
        Navigator.pushNamed(context, '/login');
      }
      return;
    }

    // กันยิงซ้ำเมนูเดียวกัน
    if (_favInFlightSearch.contains(recipe.id)) return;
    _favInFlightSearch.add(recipe.id);

    final favStore = context.read<FavoriteStore>();
    final bool desired = !favStore.contains(recipe.id);

    try {
      // ★★★ [CHANGED] เดิมเป็น Optimistic + unawaited → ตอนนี้รอผลจริงจาก backend
      final result = await ApiService.toggleFavorite(recipe.id, desired);

      // ★★★ [CHANGED] อัปเดต store ตาม "ผลจริง" เพื่อลด desync
      await favStore.set(recipe.id, result.isFavorited);

      // หมายเหตุ: ถ้าต้อง "ลบการ์ดออกจากหน้า Favorites" ทันที
      // ให้จัดการที่หน้าแม่ (screen) ด้วย callback/removeWhere เมื่อ result.isFavorited == false
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกเมนูโปรดไม่สำเร็จ')),
        );
      }
    } finally {
      _favInFlightSearch.remove(recipe.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ⭐ ดึงสถานะ favorite แบบ reactive
    final favStore = context.watch<FavoriteStore>();
    final isFavorited = favStore.contains(recipe.id);

    // [CHANGED] ปรับตัวเลข favorite: เลิกสูตรชดเชย ±1/−1 เพื่อกัน desync
    // เดิม: favCountAdj = (recipe.favoriteCount) + (ชดเชยจาก isFavorited/recipe.isFavorited)
    // ตอนนี้ใช้ค่าจาก recipe โดยตรง (ถ้าต้องการเลขสดใหม่ แนะนำรีเฟรชจาก backend)
    final favCountAdj = (recipe.favoriteCount ?? 0);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- ภาพ 4:3 ---
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImage(),
                  _buildBadge(),
                ],
              ),
            ),

            // --- เนื้อหา ---
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitle(theme),
                    const SizedBox(height: 4),
                    _buildIngredient(theme),
                    const Spacer(),
                    _MetaRow(
                      // [NEW] ส่ง recipeId เข้าไปให้ _MetaRow ทำ Optimistic UI
                      recipeId: recipe.id,
                      rating: recipe.averageRating,
                      reviewCount: recipe.reviewCount,
                      favoriteCount: favCountAdj,
                      isFavorited: isFavorited,
                      // [CHANGED] ตัด onToggle แบบเดิมออก (ย้ายลอจิกไป _MetaRow)
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ── Sub‑Widgets ─────────────────────────────────────────── */

  Widget _buildTitle(ThemeData theme) {
    final style = theme.textTheme.titleMedium!; // ⬆️ ฟอนต์ใหญ่ขึ้น
    return highlightEnabled
        ? RichText(
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            text: highlightSpan(recipe.name, highlightTerms, style),
          )
        : Text(
            recipe.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: style,
          );
  }

  Widget _buildIngredient(ThemeData theme) {
    if (recipe.shortIngredients.isEmpty) return const SizedBox.shrink();
    final style = theme.textTheme.bodySmall!
        .copyWith(color: theme.colorScheme.onSurfaceVariant);

    return highlightEnabled
        ? RichText(
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            text: highlightSpan(
              recipe.shortIngredients,
              highlightTerms,
              style,
            ),
          )
        : Text(
            recipe.shortIngredients,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: style,
          );
  }

  Widget _buildBadge() {
    final rank = rankOverride ?? recipe.rank;
    if (rank == null && !recipe.hasAllergy) return const SizedBox.shrink();
    return Positioned(
      top: 8,
      left: 8,
      child: RankBadge(rank: rank, showWarning: recipe.hasAllergy),
    );
  }

  Widget _buildImage() => recipe.imageUrl.isNotEmpty
      ? Image.network(
          recipe.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackImage(),
        )
      : _fallbackImage();

  Widget _fallbackImage() =>
      Image.asset('assets/images/default_recipe.png', fit: BoxFit.cover);
}

/* ═══════════════════════════════════════════════════════════
   Meta Row  (⭐ 4.0 (1.2K)  |  ❤  1.0K  |  💬  120 )
════════════════════════════════════════════════════════════ */

// [CHANGED] เปลี่ยนเป็น Stateful + Optimistic UI (เด้งเลข/สีทันที)
// และ sync/rollback ตามผลจริงจาก backend + อัปเดต FavoriteStore
class _MetaRow extends StatefulWidget {
  const _MetaRow({
    required this.recipeId, // [NEW]
    required this.rating,
    required this.reviewCount,
    required this.favoriteCount,
    required this.isFavorited,
    this.onToggle, // [NOTE] คงพารามิเตอร์ไว้เพื่อความเข้ากันได้ แต่ไม่ใช้แล้ว
  });

  final int recipeId; // [NEW]
  final double? rating; // ✅ รองรับ null
  final int? reviewCount; // ✅ รองรับ null
  final int? favoriteCount; // ✅ รองรับ null
  final bool isFavorited;

  // เดิมมี onToggle; เวอร์ชันนี้ไม่ใช้ (ย้ายลอจิกเข้าเมธอดภายใน)
  final VoidCallback? onToggle;

  @override
  State<_MetaRow> createState() => _MetaRowState();
}

class _MetaRowState extends State<_MetaRow> {
  late bool _isFav;
  late int _favCnt;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _isFav = widget.isFavorited;
    _favCnt = widget.favoriteCount ?? 0;
  }

  Future<void> _toggle() async {
    if (_busy) return;

    if (!await AuthService.isLoggedIn()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อน')),
      );
      Navigator.pushNamed(context, '/login');
      return;
    }

    final desired = !_isFav;

    // Optimistic: เด้งทันที
    setState(() {
      _busy = true;
      _isFav = desired;
      // ป้องกันตัวเลขติดลบในกรณีที่เริ่มจาก 0
      _favCnt = desired ? _favCnt + 1 : (_favCnt > 0 ? _favCnt - 1 : 0);
    });

    try {
      final r = await ApiService.toggleFavorite(widget.recipeId, desired);

      if (!mounted) return;
      // Sync ตามผลจริง (กัน desync)
      setState(() {
        _isFav = r.isFavorited;
        _favCnt = r.favoriteCount;
      });

      // แจ้ง Store กลาง ให้การ์ด/หน้าอื่น ๆ เปลี่ยนตาม
      await context.read<FavoriteStore>().set(widget.recipeId, r.isFavorited);
    } on UnauthorizedException {
      if (!mounted) return;
      // Rollback
      setState(() {
        _isFav = !desired;
        _favCnt = desired ? (_favCnt > 0 ? _favCnt - 1 : 0) : _favCnt + 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session หมดอายุ กรุณาเข้าสู่ระบบใหม่')),
      );
      Navigator.pushNamed(context, '/login');
    } catch (_) {
      if (!mounted) return;
      // Rollback
      setState(() {
        _isFav = !desired;
        _favCnt = desired ? (_favCnt > 0 ? _favCnt - 1 : 0) : _favCnt + 1;
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
    final ts = Theme.of(context).textTheme.bodySmall!;
    final cs = Theme.of(context).colorScheme;

    final double safeRating = widget.rating ?? 0;
    final int safeReview = widget.reviewCount ?? 0;

    return Row(
      children: [
        Icon(Icons.star, size: 16, color: Colors.amber.shade700),
        const SizedBox(width: 4),
        Text(
          '${safeRating.toStringAsFixed(1)}  (${formatCount(safeReview)})',
          style: ts.copyWith(fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        InkWell(
          onTap: _busy ? null : _toggle, // ← กดแล้วเลข/สีเด้งทันที
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            child: Row(
              children: [
                Icon(
                  _isFav ? Icons.favorite : Icons.favorite_border,
                  size: 14,
                  color: _isFav ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  formatCount(_favCnt),
                  style: ts.copyWith(
                    color: _isFav ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.comment_outlined, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(formatCount(safeReview), style: ts),
      ],
    );
  }
}
