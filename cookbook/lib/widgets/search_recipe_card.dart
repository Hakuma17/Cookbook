// lib/widgets/search_recipe_card.dart
// -------   การ์ดสำหรับหน้า Search (vertical / compact / expanded)

import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../utils/format_utils.dart';
import '../utils/highlight_span.dart';
import '../services/api_service.dart';
import 'rank_badge.dart';

// -------   Stateful ─ ต้องจำสถานะ ❤ ในการ์ด
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
  final bool initialIsFav; // ผู้ใช้กดไว้ไหม (จาก API)
  final bool compact; // โหมด list
  final bool expanded; // โหมด detail
  final VoidCallback? onTap;

  /// ★ เปิด/ปิดการไฮไลท์คำ (โยงกับ Setting ได้ภายหลัง)
  final bool highlightEnabled;

  @override
  State<SearchRecipeCard> createState() => _SearchRecipeCardState();
}

// -------   State : _isFav & _favCnt
class _SearchRecipeCardState extends State<SearchRecipeCard> {
  late bool _isFav = widget.initialIsFav;
  late int _favCnt = widget.recipe.favoriteCount;

  // -------   กดหัวใจ → call API + อัปเดต local state
  Future<void> _toggleFav() async {
    try {
      await ApiService.toggleFavorite(widget.recipe.id, !_isFav);
      if (!mounted) return;
      setState(() {
        _isFav = !_isFav;
        _favCnt += _isFav ? 1 : -1; // ปรับเลขทันที
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  // -------   route layout
  @override
  Widget build(BuildContext context) {
    if (widget.compact) return _buildCompactCard(context);
    if (widget.expanded) return _buildExpandedCard(context);
    return _buildVerticalCard(context); // default
  }

  /* ╔═══════════════════════ Vertical (Grid) ═══════════════════════ */
  // -------   ใช้ใน Grid 2 คอลัมน์
  Widget _buildVerticalCard(BuildContext ctx) {
    final w = (MediaQuery.of(ctx).size.width - 16 - 12) / 2;
    final imgH = w * .82;
    final h = w * 1.65;
    const br = 12.0;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: w,
        height: h,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: _cardDecoration(br),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // รูป + badge
            Stack(children: [
              _image(double.infinity, imgH, br),
              _badge(),
            ]),
            // ชื่อเมนู
            _titleSection(pad: const EdgeInsets.fromLTRB(8, 8, 8, 0)),
            // วัตถุดิบ
            _ingredientSection(
              pad: const EdgeInsets.fromLTRB(8, 2, 8, 0),
              maxLines: 3,
            ),
            const Spacer(),
            // meta row
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: _metaRow(showPrep: true),
            ),
          ],
        ),
      ),
    );
  }

  /* ╔═══════════════════════ Compact (List) ════════════════════════ */
  // -------   โหมด List 1-คอลัมน์ (Home-like)
  Widget _buildCompactCard(BuildContext c) {
    const br = 18.0;
    const imgH = 180.0;

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
            _titleSection(pad: const EdgeInsets.fromLTRB(12, 12, 12, 4)),
            _ingredientSection(
              pad: const EdgeInsets.symmetric(horizontal: 12),
              maxLines: 3,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: _metaRow(),
            ),
          ],
        ),
      ),
    );
  }

  /* ╔══════════════════════ Expanded (Detail) ══════════════════════ */
  // -------   การ์ดใหญ่ (ใช้ใน Search-Detail ภายหน้า)
  Widget _buildExpandedCard(BuildContext c) {
    const br = 18.0;

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
                  _titleSection(),
                  const SizedBox(height: 4),
                  _ingredientSection(maxLines: 4),
                  const SizedBox(height: 8),
                  _metaRow(showPrep: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ───────────────────────── Child-sections ────────────────────── */
  // -------   ข้อความชื่อเมนู
  Widget _titleSection({EdgeInsets pad = EdgeInsets.zero}) => Padding(
        padding: pad,
        child: widget.highlightEnabled
            // ถ้าเปิดไฮไลท์: ใช้ RichText + highlightSpan
            ? RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: highlightSpan(
                  widget.recipe.name,
                  widget.highlightTerms,
                  _titleStyle(),
                ),
              )
            // ถ้าปิดไฮไลท์: แสดงปกติด้วย Text
            : Text(
                widget.recipe.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _titleStyle(),
              ),
      );

  // -------   สรุปวัตถุดิบสั้น ๆ
  Widget _ingredientSection(
          {EdgeInsets pad = EdgeInsets.zero, int maxLines = 2}) =>
      widget.recipe.shortIngredients.isEmpty
          ? const SizedBox()
          : Padding(
              padding: pad,
              child: widget.highlightEnabled
                  // ไฮไลท์วัตถุดิบ
                  ? RichText(
                      maxLines: maxLines,
                      overflow: TextOverflow.ellipsis,
                      text: highlightSpan(
                        widget.recipe.shortIngredients,
                        widget.highlightTerms,
                        const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          height: 1.45,
                          color: Color(0xFF818181),
                        ),
                      ),
                    )
                  // ปิดไฮไลท์: แสดง Text ธรรมดา
                  : Text(
                      widget.recipe.shortIngredients,
                      maxLines: maxLines,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 14,
                        height: 1.45,
                        color: Color(0xFF818181),
                      ),
                    ),
            );

  // -------   Row meta : เวลา ⭐ ❤ 💬
  Widget _metaRow({bool showPrep = false}) => Row(
        children: [
          if (showPrep && widget.recipe.prepTime > 0) ...[
            const Icon(Icons.access_time, size: 14, color: Color(0xFF888888)),
            const SizedBox(width: 4),
            Text('${widget.recipe.prepTime} นาที',
                style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    color: Color(0xFF888888))),
            const SizedBox(width: 12),
          ],
          const Icon(Icons.star, size: 14, color: Color(0xFFFF9B05)),
          const SizedBox(width: 4),
          Text(widget.recipe.averageRating.toStringAsFixed(1),
              style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  color: Color(0xFFA6A6A6))),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _toggleFav,
            child: Icon(Icons.favorite,
                size: 16,
                color:
                    _isFav ? const Color(0xFFFF9B05) : const Color(0xFFA6A6A6)),
          ),
          const SizedBox(width: 4),
          Text(formatCount(_favCnt),
              style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  color: Color(0xFFA6A6A6))),
          const SizedBox(width: 12),
          const Icon(Icons.comment, size: 14, color: Color(0xFFA6A6A6)),
          const SizedBox(width: 4),
          Text(formatCount(widget.recipe.reviewCount),
              style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  color: Color(0xFFA6A6A6))),
        ],
      );

  /* ───────────────────────── helper UI ─────────────────────────── */
  Widget _badge() {
    final rank = widget.rankOverride ?? widget.recipe.rank;
    // ถ้าไม่มี rank และไม่มี allergy → ไม่แสดง
    if (rank == null && !widget.recipe.hasAllergy) return const SizedBox();
    return Positioned(
      top: 8,
      left: 8,
      // showWarning จะทำให้ badge เปลี่ยนสีหรือแสดง icon เตือน
      child: RankBadge(rank: rank, showWarning: widget.recipe.hasAllergy),
    );
  }

  Widget _image(double w, double h, double br) {
    final img = widget.recipe.imageUrl.isNotEmpty
        ? Image.network(widget.recipe.imageUrl,
            width: w,
            height: h,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback(w, h))
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

  TextStyle _titleStyle() => const TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.35,
        color: Color(0xFF0A2533),
      );

  Widget _fallback(double w, double h) => Image.asset(
        'assets/images/default_recipe.png',
        width: w,
        height: h,
        fit: BoxFit.cover,
      );
}
