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
    super.key,
    required this.comment,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<CommentCard> {
  bool _expanded = false; // “ดูเพิ่มเติม”

  @override
  Widget build(BuildContext context) {
    // ✅ 1. ลบ Manual Responsive Calculation และใช้ Theme
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    // --- Data Mapping ---
    final c = widget.comment;
    final userName = (c.profileName?.trim().isNotEmpty ?? false)
        ? c.profileName!
        : 'ผู้ใช้ทั่วไป';
    final dateText = c.createdAt != null
        ? DateFormat('d MMM yyyy', 'th').format(c.createdAt!)
        : 'ไม่ระบุวันที่';
    final avatarProvider = (c.avatarUrl?.isNotEmpty ?? false)
        ? NetworkImage(c.avatarUrl!)
        : const AssetImage('assets/images/default_avatar.png') as ImageProvider;
    final commentText = (c.comment?.trim().isNotEmpty ?? false)
        ? c.comment!
        : '— ไม่มีข้อความรีวิว —';

    // --- UI ---
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colorScheme.surfaceVariant,
                  backgroundImage: avatarProvider,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    userName,
                    style: textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  dateText,
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                // --- Popup Menu for Delete ---
                if (c.isMine && widget.onDelete != null) _buildPopupMenu(c),
              ],
            ),
            const SizedBox(height: 8),
            // --- Rating Stars ---
            _buildRatingStars(c.rating ?? 0, colorScheme),
            const SizedBox(height: 12),
            // --- Comment Body (expandable) ---
            _ExpandableText(
              text: commentText,
              style: textTheme.bodyMedium,
              toggleStyle: textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            // --- Edit Button ---
            if (c.isMine && widget.onEdit != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => widget.onEdit!.call(c),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('แก้ไข'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// ✅ 2. แยก UI ย่อยๆ ออกมาเป็น Widget Builder และใช้ Theme
  Widget _buildPopupMenu(Comment c) {
    return SizedBox(
      width: 32,
      height: 32,
      child: PopupMenuButton<String>(
        iconSize: 18,
        tooltip: 'ตัวเลือกเพิ่มเติม',
        onSelected: (value) {
          if (value == 'delete') widget.onDelete?.call(c);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'delete', child: Text('ลบรีวิว')),
        ],
      ),
    );
  }

  Widget _buildRatingStars(int rating, ColorScheme colorScheme) {
    return Row(
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star : Icons.star_border,
          size: 20,
          color: const Color(0xFFFFCC00), // สีดาวยังคงเดิมได้เพื่อให้เด่นชัด
        );
      }),
    );
  }
}

/// ✅ 3. แยก Logic ของ Expandable Text ออกมาเป็น StatefulWidget ของตัวเอง
class _ExpandableText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? toggleStyle;

  const _ExpandableText({required this.text, this.style, this.toggleStyle});

  @override
  __ExpandableTextState createState() => __ExpandableTextState();
}

class __ExpandableTextState extends State<_ExpandableText> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textStyle = widget.style ?? DefaultTextStyle.of(context).style;

        // --- ⭐️ จุดที่แก้ไข ⭐️ ---
        // ดึงค่า textDirection มาจาก context โดยตรง
        final textDirection = Directionality.of(context);

        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: textStyle),
          textDirection: textDirection, // 👈 แก้ไขตรงนี้
          maxLines: 3,
        )..layout(maxWidth: constraints.maxWidth);
        // -------------------------

        final isOverflow = textPainter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: textStyle,
              maxLines: _isExpanded ? null : 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (isOverflow)
              GestureDetector(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    _isExpanded ? '...ย่อลง' : 'อ่านเพิ่มเติม...',
                    style: widget.toggleStyle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
