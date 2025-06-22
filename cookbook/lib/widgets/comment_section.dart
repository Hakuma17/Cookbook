// lib/widgets/comment_section.dart
import 'package:cookbook/services/auth_service.dart';
import 'package:flutter/material.dart';

import '../models/comment.dart';
import 'comment_card.dart';
import 'comment_input_field.dart';

/// ส่วนแสดงและจัดการคอมเมนต์ทั้งหมดของสูตรอาหาร
class CommentSection extends StatelessWidget {
  final List<Comment> comments;
  final int currentRating; // ดาวที่ user เลือกไว้
  final bool isLoggedIn;
  final ValueChanged<int> onRatingSelected; // เมื่อกดดาว (1–5)
  final VoidCallback onCommentPressed; // เมื่อแตะ “แสดงความคิดเห็น”
  final ValueChanged<Comment> onEdit;
  final ValueChanged<Comment> onDelete;
  final VoidCallback? onViewAll; // (opt.) ปุ่ม “ดูทั้งหมด”

  const CommentSection({
    super.key,
    required this.comments,
    required this.currentRating,
    required this.isLoggedIn,
    required this.onRatingSelected,
    required this.onCommentPressed,
    required this.onEdit,
    required this.onDelete,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    // แยก “คอมเมนต์ของฉัน” ออกจากคอมเมนต์คนอื่น
    final myComment = comments.firstWhere(
      (c) => c.isMine,
      orElse: Comment.empty,
    );
    final otherComments = comments.where((c) => !c.isMine).toList();

    return FutureBuilder<Map<String, dynamic>>(
      future: AuthService.getLoginData(),
      builder: (context, snap) {
        final profile = snap.data;

        /// ถ้าโหลดโปรไฟล์มาแล้ว ให้อัปเดตรูป/ชื่อในคอมเมนต์ของเรา
        final updatedMy = (myComment.isMine && profile != null)
            ? myComment.copyWith(
                profileName: profile['profileName'] ?? 'คุณ',
                avatarUrl: profile['profileImage'] ?? '',
              )
            : myComment;

        final commentCount = comments.isEmpty
            ? 0
            : (updatedMy.isEmpty
                ? otherComments.length
                : otherComments.length + 1);

        // ───────────────────────── UI ─────────────────────────
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),

            // ▶︎ กล่อง “ความคิดเห็นของฉัน”
            if (isLoggedIn && updatedMy.isMine && !updatedMy.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _MyCommentBox(
                  comment: updatedMy,
                  onEdit: onEdit,
                  onDelete: onDelete,
                ),
              ),
            ],

            // ▶︎ กล่องสร้างรีวิว (ครั้งแรก)
            if (isLoggedIn && updatedMy.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _FirstCommentBox(
                  currentRating: currentRating,
                  onRatingSelected: onRatingSelected,
                  onCommentPressed: onCommentPressed,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ▶︎ หัวข้อความคิดเห็น
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'ความคิดเห็น ($commentCount)',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (onViewAll != null)
                    TextButton(
                      onPressed: onViewAll,
                      child: const Text('ดูทั้งหมด'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ▶︎ รายการคอมเมนต์อื่น ๆ
            if (otherComments.isNotEmpty)
              ...otherComments.map(
                (c) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CommentCard(
                    comment: c,
                    onEdit: onEdit,
                    onDelete: onDelete,
                  ),
                ),
              ),

            // ▶︎ ไม่มีคอมเมนต์เลย
            if (commentCount == 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  'ยังไม่มีความคิดเห็นในขณะนี้',
                  style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                ),
              ),
          ],
        );
      },
    );
  }
}

/*────────────────────────  Widgets ย่อย ────────────────────────*/

class _MyCommentBox extends StatelessWidget {
  final Comment comment;
  final ValueChanged<Comment> onEdit;
  final ValueChanged<Comment> onDelete;
  const _MyCommentBox({
    required this.comment,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF1479F2), width: 1.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ความคิดเห็นของคุณ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1479F2),
            ),
          ),
          const SizedBox(height: 12),
          CommentCard(
            comment: comment,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }
}

class _FirstCommentBox extends StatelessWidget {
  final int currentRating;
  final ValueChanged<int> onRatingSelected;
  final VoidCallback onCommentPressed;
  const _FirstCommentBox({
    required this.currentRating,
    required this.onRatingSelected,
    required this.onCommentPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDADADA), width: 1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'คุณคิดอย่างไรกับสูตรนี้บ้าง?',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < currentRating;
              return GestureDetector(
                onTap: () => onRatingSelected(i + 1),
                child: Icon(
                  filled ? Icons.star : Icons.star_outline,
                  size: 30,
                  color: filled ? const Color(0xFFFF9B05) : Colors.grey,
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          CommentInputField(
            onTap: onCommentPressed,
            label: 'แสดงความคิดเห็น',
          ),
        ],
      ),
    );
  }
}

/*───────────────────────────────────────────────────────────────*/
