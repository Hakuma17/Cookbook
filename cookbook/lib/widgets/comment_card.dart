// lib/widgets/comment_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/comment.dart';

/// การ์ดแสดงรีวิวแต่ละรายการ พร้อมลิงก์ “ดูเพิ่มเติม” เมื่อข้อความยาว
class CommentCard extends StatefulWidget {
  final Comment comment;

  const CommentCard({Key? key, required this.comment}) : super(key: key);

  @override
  _CommentCardState createState() => _CommentCardState();
}

class _CommentCardState extends State<CommentCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    // ชื่อ fallback
    final userName = (comment.profileName?.trim().isNotEmpty ?? false)
        ? comment.profileName!
        : 'ผู้ใช้ทั่วไป';
    // วันที่
    final date = comment.createdAt;
    final formattedDate = date != null
        ? DateFormat('d MMMM yyyy', 'th').format(date)
        : 'ไม่ระบุวันที่';
    // avatar
    final avatar = (comment.pathImgProfile?.isNotEmpty ?? false)
        ? NetworkImage(comment.pathImgProfile!)
        : const AssetImage('lib/assets/images/default_avatar.png')
            as ImageProvider;
    // ข้อความ
    final text = comment.comment?.trim().isNotEmpty == true
        ? comment.comment!
        : '— ไม่มีข้อความ —';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 17.45,
              backgroundImage: avatar,
              backgroundColor: Colors.transparent,
            ),
            const SizedBox(width: 8),
            // เนื้อหารีวิว
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ชื่อ + วันที่
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 24 / 14,
                          color: Color(0xFF000000),
                        ),
                      ),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 24 / 14,
                          color: Color(0xFF908F8F),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // แถวดาว
                  Row(
                    children: List.generate(5, (i) {
                      final filled = i < (comment.rating ?? 0);
                      return Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: Icon(
                          filled ? Icons.star : Icons.star_border,
                          size: 15.27,
                          color: const Color(0xFFFFCC00),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  // ข้อความรีวิว (ย่อหรือเต็ม)
                  Text(
                    text,
                    maxLines: _expanded ? null : 3,
                    overflow: _expanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 24 / 14,
                      color: Color(0xFF000000),
                    ),
                  ),
                  // ลิงก์ดูเพิ่มเติม / ย่อ
                  if (text.length > 100) // หรือเช็คบรรทัดเกิน 3
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
                            fontFamily: 'Roboto',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 20 / 14,
                            color: Color(0xFFFF9B05),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
