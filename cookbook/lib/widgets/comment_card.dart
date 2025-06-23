// lib/widgets/comment_card.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/widgets.dart';

import '../models/comment.dart';

/// การ์ดแสดงรีวิวพร้อมเมนูแก้ไข / ลบ
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
  bool _expanded = false; // สำหรับ “ดูเพิ่มเติม”
  int _hovered = -1; // index ดวงดาวที่ hover (เฉพาะ Desktop)

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;

    // ------- ข้อมูลที่ต้องแสดง -------
    final userName = (c.profileName?.trim().isNotEmpty ?? false)
        ? c.profileName!
        : 'ผู้ใช้ทั่วไป';

    final dateText = c.createdAt != null
        ? DateFormat('d MMM y', 'th').format(c.createdAt!)
        : 'ไม่ระบุวันที่';

    final avatarProvider = (c.avatarUrl?.isNotEmpty ?? false) // ← ใช้ avatarUrl
        ? NetworkImage(c.avatarUrl!)
        : const AssetImage('assets/images/default_avatar.png') as ImageProvider;

    final commentText = (c.comment?.trim().isNotEmpty ?? false)
        ? c.comment!
        : '— ไม่มีข้อความ —';

    // ------- UI หลัก -------
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------------- Header ----------------
            Row(
              children: [
                CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: avatarProvider),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(userName,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                Text(dateText,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF909090))),
                if (c.isMine && widget.onDelete != null)
                  PopupMenuButton<String>(
                    iconSize: 20,
                    onSelected: (v) {
                      if (v == 'delete') widget.onDelete?.call(c);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'delete', child: Text('ลบ'))
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // ---------------- ดาว Rating ----------------
            Row(
              children: List.generate(5, (i) {
                final filled = i < (c.rating ?? 0);
                final star = Icon(
                  filled ? Icons.star : Icons.star_border,
                  size: 16,
                  color: const Color(0xFFFFCC00),
                );

                // “ขยายเวลาชี้” เฉพาะบน Desktop / Web
                if (kIsWeb ||
                    defaultTargetPlatform == TargetPlatform.macOS ||
                    defaultTargetPlatform == TargetPlatform.windows ||
                    defaultTargetPlatform == TargetPlatform.linux) {
                  return MouseRegion(
                    onEnter: (_) => setState(() => _hovered = i),
                    onExit: (_) => setState(() => _hovered = -1),
                    child: AnimatedScale(
                      scale: _hovered == i ? 1.3 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: star,
                    ),
                  );
                }
                return star;
              }),
            ),
            const SizedBox(height: 8),

            // ---------------- ข้อความ (ย่อ/ขยาย) ----------------
            _buildExpandableText(commentText),

            // ---------------- ปุ่ม “แก้ไข” ----------------
            if (c.isMine && widget.onEdit != null)
              Align(
                alignment: Alignment.bottomRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF666666),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(60, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => widget.onEdit!.call(c),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('แก้ไข',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  ย่อ / ขยายข้อความยาว ๆ ไม่ให้การ์ดยืดเกินไป
  // ─────────────────────────────────────────────────────────────
  Widget _buildExpandableText(String text) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final span = TextSpan(
          text: text,
          style: const TextStyle(fontSize: 14, height: 1.4),
        );

        final painter = TextPainter(
          text: span,
          textDirection: Directionality.of(context), // ⭐️ จุดที่แก้
          maxLines: _expanded ? null : 3,
        )..layout(maxWidth: constraints.maxWidth);

        final overflow = painter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              maxLines: _expanded ? null : 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            if (overflow)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _expanded ? 'ย่อ' : 'ดูเพิ่มเติม',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFFF9B05),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
