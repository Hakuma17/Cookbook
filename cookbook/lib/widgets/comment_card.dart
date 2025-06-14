import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/comment.dart';

/// การ์ดแสดงรีวิวแต่ละรายการ พร้อมเมนู Delete และปุ่ม "แก้ไข" แยกต่างหาก
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
  _CommentCardState createState() => _CommentCardState();
}

class _CommentCardState extends State<CommentCard> {
  bool _expanded = false;
  int _hoveredIndex = -1;

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    final userName = (c.profileName?.trim().isNotEmpty ?? false)
        ? c.profileName!
        : 'ผู้ใช้ทั่วไป';
    final date = c.createdAt != null
        ? DateFormat('d MMMM yyyy', 'th').format(c.createdAt!)
        : 'ไม่ระบุวันที่';
    final avatar = (c.pathImgProfile?.isNotEmpty ?? false)
        ? NetworkImage(c.pathImgProfile!)
        : const AssetImage('lib/assets/images/default_avatar.png')
            as ImageProvider;
    final text =
        c.comment?.trim().isNotEmpty == true ? c.comment! : '— ไม่มีข้อความ —';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Avatar, Name, Date, Delete Menu
            Row(
              children: [
                CircleAvatar(radius: 18, backgroundImage: avatar),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF908F8F),
                  ),
                ),
                if (c.isMine && widget.onDelete != null)
                  PopupMenuButton<String>(
                    iconSize: 20,
                    onSelected: (value) {
                      if (value == 'delete') widget.onDelete?.call(c);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'delete', child: Text('ลบ')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Animated Star Rating
            Row(
              children: List.generate(5, (i) {
                final filled = i < (c.rating ?? 0);
                return MouseRegion(
                  onEnter: (_) => setState(() => _hoveredIndex = i),
                  onExit: (_) => setState(() => _hoveredIndex = -1),
                  child: AnimatedScale(
                    scale: (_hoveredIndex == i) ? 1.3 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: GestureDetector(
                      onTap: () {}, // เพื่อให้มี ripple ได้
                      child: Icon(
                        filled ? Icons.star : Icons.star_border,
                        size: 16,
                        color: const Color(0xFFFFCC00),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),

            // Comment Text with overflow detection
            _buildExpandableText(text),

            // ปุ่มแก้ไข (แยกมุมขวาล่าง)
            if (c.isMine && widget.onEdit != null)
              Align(
                alignment: Alignment.bottomRight,
                child: TextButton.icon(
                  onPressed: () => widget.onEdit!(c),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text(
                    'แก้ไข',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF666666),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(64, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableText(String text) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final span = TextSpan(
        text: text,
        style: const TextStyle(fontSize: 14, height: 1.4),
      );
      final tp = TextPainter(
        text: span,
        textDirection: Directionality.of(context),
        maxLines: _expanded ? null : 3,
      )..layout(maxWidth: constraints.maxWidth);

      final isOverflow = tp.didExceedMaxLines;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            maxLines: _expanded ? null : 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          if (isOverflow)
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
    });
  }
}
