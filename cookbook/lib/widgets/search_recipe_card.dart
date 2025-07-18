// lib/widgets/search_recipe_card.dart
// ──────────────────────────────────────────────────────────────
// Responsive Search-Recipe Card  (2025-07-10 → overflow-safe 2025-07-13)
//
//  • Vertical-grid card เปลี่ยนใช้ AspectRatio(0.58) + ตัด margin-bottom
//    ให้สูงพอดีกับ cell ที่ GridDelegate สร้าง จบปัญหา BOTTOM OVERFLOWED
//  • Compact / Expanded ไม่เปลี่ยน
// ──────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../utils/format_utils.dart';
import '../utils/highlight_span.dart';
import '../services/api_service.dart';
import 'rank_badge.dart';

class SearchRecipeCard extends StatefulWidget {
  const SearchRecipeCard({
    super.key,
    required this.recipe,
    this.highlightTerms = const [],
    this.rankOverride,
    this.initialIsFav = false,
    this.compact = false,
    this.expanded = false,
    this.onTap,
    this.highlightEnabled = true, // ★ เปิด/ปิดการไฮไลท์คำได้
  });

  final Recipe recipe;
  final List<String> highlightTerms;
  final int? rankOverride; // บังคับลำดับ 1-3
  final bool initialIsFav; // กด ♥ ไว้ไหม
  final bool compact; // โหมด list
  final bool expanded; // โหมด detail
  final VoidCallback? onTap;
  final bool highlightEnabled;

  @override
  State<SearchRecipeCard> createState() => _SearchRecipeCardState();
}

class _SearchRecipeCardState extends State<SearchRecipeCard> {
  late bool _isFav = widget.initialIsFav;
  late int _favCnt = widget.recipe.favoriteCount;

  /* ───────── toggle ♥ ───────── */
  Future<void> _toggleFav() async {
    try {
      await ApiService.toggleFavorite(widget.recipe.id, !_isFav);
      if (!mounted) return;
      setState(() {
        _isFav = !_isFav;
        _favCnt += _isFav ? 1 : -1;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    }
  }

  /* ───────── responsive helper ───────── */
  double _rs(double v, double min, double max) => v.clamp(min, max).toDouble();

  /* ╔════════════════════ build ════════════════════ */
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final screenW = MediaQuery.of(context).size.width;
      final cardWgrid = (screenW - 16 - 12) / 2; // กว้างสุทธิ 1 ช่องกริด

      /* ---- responsive numbers ---- */
      final titleF = _rs(screenW * .045, 14, 18); // 14–18
      final bodyF = _rs(titleF * .87, 12, 15); // 12–15
      final metaF = bodyF;
      final iconF = _rs(bodyF * .9, 12, 16);
      final favF = iconF - 1;
      final brGrid = _rs(12, 10, 14);
      final brList = brGrid + 4;
      final imgHc = _rs(titleF * 10, 160, 220); // compact-imgH

      /* ---- route layout ---- */
      if (widget.compact) {
        return _buildCompactCard(
            brList, titleF, bodyF, metaF, iconF, favF, imgHc);
      }
      if (widget.expanded) {
        return _buildExpandedCard(brList, titleF, bodyF, metaF, iconF, favF);
      }
      return _buildVerticalCard(cardWgrid, brGrid, titleF, bodyF, metaF, iconF,
          favF); // default vertical
    });
  }

  /* ╔════════ Vertical (grid) ════════ */
  Widget _buildVerticalCard(double w, double br, double titleF, double bodyF,
      double metaF, double iconF, double favF) {
    // ★ อัตราส่วนกว้าง/สูง ของ cell (ต้องตรง childAspectRatio ใน GridDelegate)
    const double _kAspect = 0.58; // = w / h ≈ 1 / 1.72

    final imgH = w * .82; // รูป ≈ 82 % ของความกว้าง

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: w,
        child: AspectRatio(
          aspectRatio: _kAspect, // ← ให้สูงตรง cell, ไม่ fix height เอง
          child: Container(
            decoration: _cardDecoration(br),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(children: [
                  _image(double.infinity, imgH, br),
                  _badge(),
                ]),
                _titleSection(
                    pad: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    fontSize: titleF),
                _ingredientSection(
                  pad: const EdgeInsets.fromLTRB(8, 2, 8, 0),
                  maxLines: 3,
                  fontSize: bodyF,
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: _metaRow(metaF, iconF, favF, showPrep: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /* ╔════════ Compact (list) ═════════ */
  Widget _buildCompactCard(double br, double titleF, double bodyF, double metaF,
      double iconF, double favF, double imgH) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: _cardDecoration(br),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(children: [
              _image(double.infinity, imgH, br),
              _badge(),
            ]),
            _titleSection(
                pad: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                fontSize: titleF),
            _ingredientSection(
              pad: const EdgeInsets.symmetric(horizontal: 12),
              maxLines: 3,
              fontSize: bodyF,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: _metaRow(metaF, iconF, favF),
            ),
          ],
        ),
      ),
    );
  }

  /* ╔════════ Expanded (detail) ═══════ */
  Widget _buildExpandedCard(double br, double titleF, double bodyF,
      double metaF, double iconF, double favF) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: _cardDecoration(br),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _image(double.infinity, 180, br),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _titleSection(fontSize: titleF),
                  const SizedBox(height: 4),
                  _ingredientSection(maxLines: 4, fontSize: bodyF),
                  const SizedBox(height: 8),
                  _metaRow(metaF, iconF, favF, showPrep: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ───────────────────────── sub-sections ───────────────────── */
  Widget _titleSection(
          {EdgeInsets pad = EdgeInsets.zero, required double fontSize}) =>
      Padding(
        padding: pad,
        child: widget.highlightEnabled
            ? RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: highlightSpan(
                  widget.recipe.name,
                  widget.highlightTerms,
                  TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w700,
                    fontSize: fontSize,
                    height: 1.32,
                    color: const Color(0xFF0A2533),
                  ),
                ),
              )
            : Text(
                widget.recipe.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                  fontSize: fontSize,
                  height: 1.32,
                  color: const Color(0xFF0A2533),
                ),
              ),
      );

  Widget _ingredientSection(
      {EdgeInsets pad = EdgeInsets.zero,
      int maxLines = 2,
      required double fontSize}) {
    if (widget.recipe.shortIngredients.isEmpty) return const SizedBox();
    final txtStyle = TextStyle(
      fontFamily: 'Roboto',
      fontSize: fontSize,
      height: 1.4,
      color: const Color(0xFF818181),
    );

    return Padding(
      padding: pad,
      child: widget.highlightEnabled
          ? RichText(
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              text: highlightSpan(
                widget.recipe.shortIngredients,
                widget.highlightTerms,
                txtStyle,
              ),
            )
          : Text(
              widget.recipe.shortIngredients,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: txtStyle,
            ),
    );
  }

  Widget _metaRow(double fontSize, double iconSz, double favSz,
          {bool showPrep = false}) =>
      Row(
        children: [
          if (showPrep && widget.recipe.prepTime > 0) ...[
            Icon(Icons.access_time,
                size: iconSz, color: const Color(0xFF888888)),
            SizedBox(width: iconSz * .3),
            Text(
              '${widget.recipe.prepTime} นาที',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: fontSize,
                color: const Color(0xFF888888),
              ),
            ),
            SizedBox(width: iconSz),
          ],
          Icon(Icons.star, size: iconSz, color: const Color(0xFFFF9B05)),
          SizedBox(width: iconSz * .3),
          Text(
            widget.recipe.averageRating.toStringAsFixed(1),
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: fontSize,
              color: const Color(0xFFA6A6A6),
            ),
          ),
          SizedBox(width: iconSz),
          GestureDetector(
            onTap: _toggleFav,
            child: Icon(Icons.favorite,
                size: favSz,
                color:
                    _isFav ? const Color(0xFFFF9B05) : const Color(0xFFA6A6A6)),
          ),
          SizedBox(width: iconSz * .3),
          Text(
            formatCount(_favCnt),
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: fontSize,
              color: const Color(0xFFA6A6A6),
            ),
          ),
          SizedBox(width: iconSz),
          Icon(Icons.comment, size: iconSz, color: const Color(0xFFA6A6A6)),
          SizedBox(width: iconSz * .3),
          Text(
            formatCount(widget.recipe.reviewCount),
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: fontSize,
              color: const Color(0xFFA6A6A6),
            ),
          ),
        ],
      );

  /* ───────────────────────── helpers ─────────────────────────── */
  Widget _badge() {
    final rank = widget.rankOverride ?? widget.recipe.rank;
    if (rank == null && !widget.recipe.hasAllergy) return const SizedBox();
    return Positioned(
      top: 8,
      left: 8,
      child: RankBadge(rank: rank, showWarning: widget.recipe.hasAllergy),
    );
  }

  Widget _image(double w, double h, double br) {
    final img = widget.recipe.imageUrl.isNotEmpty
        ? Image.network(
            widget.recipe.imageUrl,
            width: w,
            height: h,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback(w, h),
          )
        : _fallback(w, h);

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(br)),
      child: img,
    );
  }

  BoxDecoration _cardDecoration(double br) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(br),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF063336).withOpacity(.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      );

  Widget _fallback(double w, double h) => Image.asset(
        'assets/images/default_recipe.png',
        width: w,
        height: h,
        fit: BoxFit.cover,
      );
}
