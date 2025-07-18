// lib/widgets/comment_card.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/comment.dart';

/// การ์ดแสดงรีวิว พร้อมเมนูแก้ไข / ลบ
class CommentCard extends StatefulWidget {
  final Comment comment;
  final ValueChanged<Comment>? onEdit;
  final ValueChanged<Comment>? onDelete;

  const CommentCard({
    Key? key,
    required this.comment,
    this.onEdit,
    this.onDelete,
  }) : super(key: key);

  @override
  State<CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<CommentCard> {
  bool _expanded = false; // “ดูเพิ่มเติม”
  int _hovered = -1; // index ดาวที่ hover (desktop)

  @override
  Widget build(BuildContext context) {
    /* ── responsive metrics ── */
    final w = MediaQuery.of(context).size.width;
    double clamp(double v, double min, double max) =>
        v < min ? min : (v > max ? max : v);

    final avatarR = clamp(w * .045, 14, 22);
    final starSz = clamp(w * .040, 14, 18);
    final nameF = clamp(w * .040, 13, 16);
    final dateF = clamp(w * .033, 11, 13);
    final textF = clamp(w * .039, 13, 15);
    final editF = clamp(w * .038, 12, 14);
    final cardPad = clamp(w * .032, 10, 16);
    final headGap = clamp(w * .022, 6, 10);
    final marginV = clamp(w * .020, 6, 12);

    /* ── data mapping ── */
    final c = widget.comment;

    final userName = (c.profileName?.trim().isNotEmpty ?? false)
        ? c.profileName!
        : 'ผู้ใช้ทั่วไป';

    final dateText = c.createdAt != null
        ? DateFormat('d MMM y', 'th').format(c.createdAt!)
        : 'ไม่ระบุวันที่';

    final avatarProvider = (c.avatarUrl?.isNotEmpty ?? false)
        ? NetworkImage(c.avatarUrl!)
        : const AssetImage('assets/images/default_avatar.png') as ImageProvider;

    final commentText = (c.comment?.trim().isNotEmpty ?? false)
        ? c.comment!
        : '— ไม่มีข้อความ —';

    /* ── UI ── */
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: marginV),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(cardPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /* ---------- Header ---------- */
            Row(
              children: [
                CircleAvatar(
                  radius: avatarR,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: avatarProvider,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: nameF,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  dateText,
                  style: TextStyle(
                    fontSize: dateF,
                    color: const Color(0xFF909090),
                  ),
                ),
                if (c.isMine && widget.onDelete != null) ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    iconSize: dateF + 4,
                    padding: EdgeInsets.zero,
                    onSelected: (v) {
                      if (v == 'delete') widget.onDelete?.call(c);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'delete', child: Text('ลบ')),
                    ],
                  ),
                ],
              ],
            ),
            SizedBox(height: headGap),

            /* ---------- Rating stars ---------- */
            Row(
              children: List.generate(5, (i) {
                final filled = i < (c.rating ?? 0);
                final star = Icon(
                  filled ? Icons.star : Icons.star_border,
                  size: starSz,
                  color: const Color(0xFFFFCC00),
                );

                // hover effect on desktop / web
                if (kIsWeb ||
                    defaultTargetPlatform == TargetPlatform.macOS ||
                    defaultTargetPlatform == TargetPlatform.windows ||
                    defaultTargetPlatform == TargetPlatform.linux) {
                  return MouseRegion(
                    onEnter: (_) => setState(() => _hovered = i),
                    onExit: (_) => setState(() => _hovered = -1),
                    child: AnimatedScale(
                      scale: _hovered == i ? 1.30 : 1.00,
                      duration: const Duration(milliseconds: 180),
                      child: star,
                    ),
                  );
                }
                return star;
              }),
            ),
            const SizedBox(height: 8),

            /* ---------- Comment body (expandable) ---------- */
            _expandable(commentText, textF),

            /* ---------- Edit button ---------- */
            if (c.isMine && widget.onEdit != null)
              Align(
                alignment: Alignment.bottomRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF666666),
                    minimumSize: const Size(64, 28),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(Icons.edit, size: editF + 2),
                  label: Text('แก้ไข',
                      style: TextStyle(
                        fontSize: editF,
                        fontWeight: FontWeight.w500,
                      )),
                  onPressed: () => widget.onEdit!.call(c),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /* ───────── ย่อ / ขยายข้อความ ───────── */
  Widget _expandable(String text, double fz) {
    return LayoutBuilder(
      builder: (context, cons) {
        // 1) สร้าง TextPainter เพื่อเช็กว่าล้นหรือไม่
        final tp = TextPainter(
          text:
              TextSpan(text: text, style: TextStyle(fontSize: fz, height: 1.4)),
          textDirection: Directionality.of(context), // ใช้บริบทจริง
          maxLines: _expanded ? null : 3,
        )..layout(maxWidth: cons.maxWidth);

        final isOverflow = tp.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              maxLines: _expanded ? null : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: fz, height: 1.4),
            ),
            if (isOverflow)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _expanded ? 'ย่อ' : 'ดูเพิ่มเติม',
                  style: TextStyle(
                    fontSize: fz,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFFF9B05),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
