// lib/widgets/comment_section.dart
import 'package:cookbook/services/auth_service.dart';
import 'package:flutter/material.dart';

import '../models/comment.dart';
import 'comment_card.dart';
import 'comment_input_field.dart';

/// ส่วนแสดงและจัดการคอมเมนต์ทั้งหมดของสูตรอาหาร
class CommentSection extends StatelessWidget {
  final List<Comment> comments;
  final int currentRating;
  final bool isLoggedIn;
  final ValueChanged<int> onRatingSelected;
  final VoidCallback onCommentPressed;
  final ValueChanged<Comment> onEdit;
  final ValueChanged<Comment> onDelete;
  final VoidCallback? onViewAll;

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
    /* ── responsive helpers ── */
    final w = MediaQuery.of(context).size.width;
    double clamp(double v, double min, double max) =>
        v < min ? min : (v > max ? max : v);

    final headFont = clamp(w * 0.044, 15, 18); // ฟอนต์หัวข้อ
    final hrPadH = clamp(w * 0.042, 12, 20); // padding ซ้าย-ขวาหัวข้อ
    final spaceV = clamp(w * 0.032, 10, 18); // ช่องว่างระหว่างบล็อก

    /* ── แยกคอมเมนต์ของฉันกับคนอื่น ── */
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

        /* ── UI ── */
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: spaceV),

            /*  “ความคิดเห็นของฉัน” */
            if (isLoggedIn && updatedMy.isMine && !updatedMy.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hrPadH),
                child: _MyCommentBox(
                  comment: updatedMy,
                  onEdit: onEdit,
                  onDelete: onDelete,
                  baseW: w,
                ),
              ),

            /*  กล่องสร้างคอมเมนต์แรก */
            if (isLoggedIn && updatedMy.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hrPadH),
                child: _FirstCommentBox(
                  currentRating: currentRating,
                  onRatingSelected: onRatingSelected,
                  onCommentPressed: onCommentPressed,
                  baseW: w,
                ),
              ),
            SizedBox(height: spaceV),

            /*  หัวข้อ “ความคิดเห็น (x)” */
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hrPadH),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'ความคิดเห็น ($commentCount)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600, fontSize: headFont),
                    ),
                  ),
                  if (onViewAll != null)
                    TextButton(
                        onPressed: onViewAll, child: const Text('ดูทั้งหมด')),
                ],
              ),
            ),
            const SizedBox(height: 8),

            /* ▶︎ คอมเมนต์คนอื่น ๆ */
            if (otherComments.isNotEmpty)
              ...otherComments.map(
                (c) => Padding(
                  padding: EdgeInsets.symmetric(horizontal: hrPadH),
                  child: CommentCard(
                      comment: c, onEdit: onEdit, onDelete: onDelete),
                ),
              ),

            /*  ถ้ายังไม่มีคอมเมนต์ */
            if (commentCount == 0)
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: hrPadH, vertical: spaceV / 1.5),
                child: const Text('ยังไม่มีความคิดเห็นในขณะนี้',
                    style: TextStyle(fontSize: 14, color: Color(0xFF666666))),
              ),
          ],
        );
      },
    );
  }
}

/*──────────────────── “ความคิดเห็นของฉัน” ───────────────────*/
class _MyCommentBox extends StatelessWidget {
  final Comment comment;
  final ValueChanged<Comment> onEdit;
  final ValueChanged<Comment> onDelete;
  final double baseW;

  const _MyCommentBox({
    required this.comment,
    required this.onEdit,
    required this.onDelete,
    required this.baseW,
  });

  @override
  Widget build(BuildContext context) {
    double clamp(double v, double min, double max) =>
        v < min ? min : (v > max ? max : v);

    final radius = clamp(baseW * 0.042, 14, 20);
    final titleF = clamp(baseW * 0.043, 14, 16);
    final padBox = clamp(baseW * 0.042, 12, 20);
    final gapV = clamp(baseW * 0.028, 8, 14);

    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: EdgeInsets.all(padBox),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: primaryColor, width: 1.5),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ความคิดเห็นของคุณ',
              style: TextStyle(fontSize: titleF, fontWeight: FontWeight.w700)),
          SizedBox(height: gapV),
          CommentCard(comment: comment, onEdit: onEdit, onDelete: onDelete),
        ],
      ),
    );
  }
}

/*──────────────────── กล่องสร้างคอมเมนต์แรก ───────────────────*/
class _FirstCommentBox extends StatelessWidget {
  final int currentRating;
  final ValueChanged<int> onRatingSelected;
  final VoidCallback onCommentPressed;
  final double baseW;

  const _FirstCommentBox({
    required this.currentRating,
    required this.onRatingSelected,
    required this.onCommentPressed,
    required this.baseW,
  });

  @override
  Widget build(BuildContext context) {
    double clamp(double v, double min, double max) =>
        v < min ? min : (v > max ? max : v);

    final radius = clamp(baseW * 0.042, 14, 20);
    final padBox = clamp(baseW * 0.042, 12, 20);
    final titleF = clamp(baseW * 0.043, 14, 16);
    final starSz = clamp(baseW * 0.08, 24, 34);
    final gapV = clamp(baseW * 0.028, 8, 14);

    return Container(
      padding: EdgeInsets.all(padBox),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDADADA), width: 1),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 5,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Text('คุณคิดอย่างไรกับสูตรนี้บ้าง?',
              style: TextStyle(fontSize: titleF, fontWeight: FontWeight.w600)),
          SizedBox(height: gapV),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < currentRating;
              return GestureDetector(
                onTap: () => onRatingSelected(i + 1),
                child: Icon(
                  filled ? Icons.star : Icons.star_outline,
                  size: starSz,
                  color: filled ? const Color(0xFFFF9B05) : Colors.grey,
                ),
              );
            }),
          ),
          SizedBox(height: gapV),
          CommentInputField(onTap: onCommentPressed),
        ],
      ),
    );
  }
}
