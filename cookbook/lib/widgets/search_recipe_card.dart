// lib/widgets/search_recipe_card.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../stores/favorite_store.dart'; // ใช้ store กลาง
import '../utils/format_utils.dart';
import '../utils/highlight_span.dart';
import 'rank_badge.dart';

// กันยิงคำขอซ้ำตอนผู้ใช้กดหัวใจรัว ๆ ต่อเมนูเดียวกัน
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

  // เวอร์ชันนี้เราให้ _MetaRow จัดการ optimistic เอง ฟังก์ชันนี้คงไว้เพื่อความเข้ากันได้
  Future<void> _handleToggleFavorite(BuildContext context) async {
    if (!await AuthService.isLoggedIn()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อน')),
        );
        Navigator.pushNamed(context, '/login');
      }
      return;
    }
    if (_favInFlightSearch.contains(recipe.id)) return;
    _favInFlightSearch.add(recipe.id);

    final favStore = context.read<FavoriteStore>();
    final desired = !favStore.contains(recipe.id);

    try {
      final result = await ApiService.toggleFavorite(recipe.id, desired);
      await favStore.set(recipe.id, result.isFavorited);
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

    // อ่านสถานะ favorite ปัจจุบัน (non-reactive)
    final isFavorited = context.read<FavoriteStore>().contains(recipe.id);
    final favCountAdj = (recipe.favoriteCount ?? 0);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // รูป 4:3
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImage(),
                  _buildBadges(),
                ],
              ),
            ),

            // เนื้อหา
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitle(theme),
                    const SizedBox(height: 4),
                    _buildIngredient(theme),
                    const SizedBox(height: 6), // แทน Spacer() กันล้น
                    _MetaRow(
                      key: ValueKey('s:${recipe.id}:${favCountAdj}'),
                      recipeId: recipe.id,
                      rating: recipe.averageRating,
                      reviewCount: recipe.reviewCount,
                      favoriteCount: favCountAdj,
                      isFavorited: isFavorited,
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

  /* ── Sub-Widgets ─────────────────────────────────────────── */

  Widget _buildTitle(ThemeData theme) {
    final style = theme.textTheme.titleMedium!;
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

  // แยก Badge อันดับซ้ายบน + ป้ายเตือนแพ้ขวาบน
  Widget _buildBadges() {
    final rank = rankOverride ?? recipe.rank;
    return Stack(
      children: [
        if (rank != null)
          Positioned(
            top: 8,
            left: 8,
            child: RankBadge(rank: rank, showWarning: false),
          ),
        if (recipe.hasAllergy)
          const Positioned(
            top: 8,
            right: 8,
            child: _AllergyIndicator(),
          ),
      ],
    );
  }

  Widget _buildImage() => recipe.imageUrl.isNotEmpty
      ? Image.network(
          recipe.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Image.asset(
              'assets/images/default_recipe.png',
              fit: BoxFit.cover),
        )
      : Image.asset('assets/images/default_recipe.png', fit: BoxFit.cover);
}

/* ═══════════════════════════════════════════════════════════
   META row — ให้เหมือนการ์ดหน้า Home:
   ⭐ 4.5 (2)   ❤ 12
════════════════════════════════════════════════════════════ */

class _MetaRow extends StatefulWidget {
  const _MetaRow({
    Key? key,
    required this.recipeId,
    required this.rating,
    required this.reviewCount,
    required this.favoriteCount,
    required this.isFavorited,
    this.onToggle,
  }) : super(key: key);

  final int recipeId;
  final double? rating;
  final int? reviewCount;
  final int? favoriteCount;
  final bool isFavorited;
  final VoidCallback? onToggle;

  @override
  State<_MetaRow> createState() => _MetaRowState();
}

class _MetaRowState extends State<_MetaRow> {
  late bool _isFav;
  late int _favCnt;
  bool _busy = false;

  FavoriteStore? _favStore;
  void _onStoreChanged() {
    if (!mounted || _favStore == null) return;
    final favNow = _favStore!.contains(widget.recipeId);
    if (favNow != _isFav) {
      setState(() => _isFav = favNow);
    }
  }

  @override
  void initState() {
    super.initState();
    _isFav = widget.isFavorited;
    _favCnt = widget.favoriteCount ?? 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = context.read<FavoriteStore>();
    if (!identical(s, _favStore)) {
      _favStore?.removeListener(_onStoreChanged);
      _favStore = s..addListener(_onStoreChanged);
      final favNow = _favStore!.contains(widget.recipeId);
      if (favNow != _isFav) {
        setState(() => _isFav = favNow);
      }
    }
  }

  @override
  void didUpdateWidget(covariant _MetaRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.recipeId != oldWidget.recipeId) {
      setState(() {
        _isFav = widget.isFavorited;
        _favCnt = widget.favoriteCount ?? 0;
      });
      return;
    }
    if (widget.isFavorited != _isFav) {
      setState(() => _isFav = widget.isFavorited);
    }
    if (!_busy &&
        (widget.favoriteCount ?? 0) != (oldWidget.favoriteCount ?? 0)) {
      setState(() => _favCnt = widget.favoriteCount ?? _favCnt);
    }
  }

  @override
  void dispose() {
    _favStore?.removeListener(_onStoreChanged);
    super.dispose();
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
    final optimistic = desired ? _favCnt + 1 : (_favCnt > 0 ? _favCnt - 1 : 0);

    setState(() {
      _busy = true;
      _isFav = desired;
      _favCnt = optimistic;
    });

    try {
      final r = await ApiService.toggleFavorite(widget.recipeId, desired);
      if (!mounted) return;
      setState(() {
        _isFav = r.isFavorited; // เชื่อผลจริงเรื่อง “สถานะ”
        _favCnt = optimistic; // คงเลขก่อนหน้าไว้
      });
      await _favStore?.set(widget.recipeId, r.isFavorited);
    } on UnauthorizedException {
      if (!mounted) return;
      setState(() {
        _isFav = !desired;
        _favCnt = (_favCnt + (desired ? -1 : 1)).clamp(0, 1 << 31);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session หมดอายุ กรุณาเข้าสู่ระบบใหม่')),
      );
      Navigator.pushNamed(context, '/login');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isFav = !desired;
        _favCnt = (_favCnt + (desired ? -1 : 1)).clamp(0, 1 << 31);
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

    final double safeRating = (widget.rating ?? 0).toDouble();
    final int safeReview = widget.reviewCount ?? 0;
    final ratingText =
        '${safeRating.toStringAsFixed(1)}  (${formatCount(safeReview)})';

    // กันพื้นที่ด้านขวาสำหรับ ❤ + ตัวเลข (แบบหน้า Home)
    const double kRightMetaReserve = 64;

    return LayoutBuilder(
      builder: (context, c) {
        final maxTextW =
            (c.maxWidth - kRightMetaReserve).clamp(40.0, c.maxWidth);

        return Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(Icons.star, size: 16, color: Colors.amber.shade700),
            const SizedBox(width: 6),

            // ข้อความดาว: จำกัดความกว้างสูงสุดไว้ ไม่ให้ดันหัวใจ
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

            // ปุ่มหัวใจ + จำนวน (เหมือนหน้า Home)
            InkWell(
              onTap: _busy ? null : _toggle,
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
            color: cs.errorContainer.withOpacity(0.92),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: cs.error.withOpacity(.6), width: 1),
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
