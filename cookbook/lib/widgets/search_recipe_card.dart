// lib/widgets/search_recipe_card.dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/format_utils.dart';
import '../utils/highlight_span.dart';
import 'rank_badge.dart';

class SearchRecipeCard extends StatefulWidget {
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

  @override
  State<SearchRecipeCard> createState() => _SearchRecipeCardState();
}

class _SearchRecipeCardState extends State<SearchRecipeCard> {
  late bool _isFavorited;
  late int _favoriteCount;

  @override
  void initState() {
    super.initState();
    _isFavorited = widget.recipe.isFavorited;
    _favoriteCount = widget.recipe.favoriteCount;
  }

  @override
  void didUpdateWidget(covariant SearchRecipeCard old) {
    super.didUpdateWidget(old);
    if (widget.recipe.isFavorited != old.recipe.isFavorited ||
        widget.recipe.favoriteCount != old.recipe.favoriteCount) {
      setState(() {
        _isFavorited = widget.recipe.isFavorited;
        _favoriteCount = widget.recipe.favoriteCount;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (!await AuthService.isLoggedIn()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อน')),
        );
        Navigator.pushNamed(context, '/login');
      }
      return;
    }

    setState(() {
      _isFavorited = !_isFavorited;
      _favoriteCount += _isFavorited ? 1 : -1;
    });

    try {
      await ApiService.toggleFavorite(widget.recipe.id, _isFavorited);
    } on ApiException catch (e) {
      setState(() {
        _isFavorited = !_isFavorited;
        _favoriteCount += _isFavorited ? 1 : -1;
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /* ╔════════ BUILD ════════ */
  @override
  Widget build(BuildContext context) => _verticalCard(context);

  /* ╔════════ Vertical Card ════════ */
  Widget _verticalCard(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- ภาพ (4:3) ---
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ชื่อ + รายการวัตถุดิบย่อ
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTitle(theme),
                        const SizedBox(height: 4),
                        _buildIngredient(theme, maxLines: 2),
                      ],
                    ),
                    // แถบ meta (rating / favorite / comments)
                    _buildMeta(theme),
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
    final style = theme.textTheme.titleSmall!;
    return widget.highlightEnabled
        ? RichText(
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            text: highlightSpan(
              widget.recipe.name,
              widget.highlightTerms,
              style,
            ),
          )
        : Text(widget.recipe.name,
            maxLines: 2, overflow: TextOverflow.ellipsis, style: style);
  }

  Widget _buildIngredient(ThemeData theme, {int maxLines = 2}) {
    if (widget.recipe.shortIngredients.isEmpty) return const SizedBox.shrink();
    final style = theme.textTheme.bodySmall!
        .copyWith(color: theme.colorScheme.onSurfaceVariant);

    return widget.highlightEnabled
        ? RichText(
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            text: highlightSpan(
              widget.recipe.shortIngredients,
              widget.highlightTerms,
              style,
            ),
          )
        : Text(widget.recipe.shortIngredients,
            maxLines: maxLines, overflow: TextOverflow.ellipsis, style: style);
  }

  Widget _buildMeta(ThemeData theme) {
    final cs = theme.colorScheme;
    final ts = theme.textTheme.bodySmall!;

    return Row(
      children: [
        Icon(Icons.star, size: 16, color: Colors.amber.shade700),
        const SizedBox(width: 4),
        Text(widget.recipe.averageRating.toStringAsFixed(1),
            style: ts.copyWith(fontWeight: FontWeight.bold)),
        const Spacer(),
        InkWell(
          onTap: _toggleFavorite,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            child: Row(
              children: [
                Icon(
                  _isFavorited ? Icons.favorite : Icons.favorite_border,
                  size: 14,
                  color: _isFavorited ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(formatCount(_favoriteCount),
                    style: ts.copyWith(
                        color:
                            _isFavorited ? cs.primary : cs.onSurfaceVariant)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.comment_outlined, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(formatCount(widget.recipe.reviewCount), style: ts),
      ],
    );
  }

  /* ── Helpers ─────────────────────────────────────────────── */

  Widget _buildBadge() {
    final rank = widget.rankOverride ?? widget.recipe.rank;
    if (rank == null && !widget.recipe.hasAllergy) {
      return const SizedBox.shrink();
    }
    return Positioned(
      top: 8,
      left: 8,
      child: RankBadge(rank: rank, showWarning: widget.recipe.hasAllergy),
    );
  }

  Widget _buildImage() {
    return widget.recipe.imageUrl.isNotEmpty
        ? Image.network(
            widget.recipe.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallbackImage(),
          )
        : _fallbackImage();
  }

  Widget _fallbackImage() =>
      Image.asset('assets/images/default_recipe.png', fit: BoxFit.cover);
}
