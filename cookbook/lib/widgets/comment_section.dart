import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/comment.dart';
import 'comment_card.dart';
import 'comment_input_field.dart';

/// ส่วนแสดงและจัดการคอมเมนต์ทั้งหมด
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
    Key? key,
    required this.comments,
    required this.currentRating,
    required this.isLoggedIn,
    required this.onRatingSelected,
    required this.onCommentPressed,
    required this.onEdit,
    required this.onDelete,
    this.onViewAll,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final myComment = comments.firstWhere(
      (c) => c.isMine,
      orElse: () => Comment.empty(),
    );
    final otherComments = comments.where((c) => !c.isMine).toList();

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        final prefs = snapshot.data;

        final updatedMyComment = (myComment.isMine && prefs != null)
            ? Comment(
                userId: myComment.userId,
                profileName: prefs.getString('profileName') ?? 'คุณ',
                pathImgProfile: prefs.getString('profileImage') ?? '',
                rating: myComment.rating,
                comment: myComment.comment,
                createdAt: myComment.createdAt,
                isMine: true,
              )
            : myComment;

        final commentCount = comments.isEmpty
            ? 0
            : (updatedMyComment.isEmpty
                ? otherComments.length
                : otherComments.length + 1);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),

            // ความคิดเห็นของฉัน
            if (isLoggedIn &&
                updatedMyComment.isMine &&
                !updatedMyComment.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border:
                        Border.all(color: const Color(0xFF1479F2), width: 1.5),
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
                        comment: updatedMyComment,
                        onEdit: onEdit,
                        onDelete: onDelete,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // กล่องแสดงความคิดเห็น (เมื่อยังไม่เคยโพสต์)
            if (isLoggedIn && updatedMyComment.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border:
                        Border.all(color: const Color(0xFFDADADA), width: 1),
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
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
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
                              color: filled
                                  ? const Color(0xFFFF9B05)
                                  : Colors.grey,
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
                ),
              ),
            ],

            const SizedBox(height: 24),

            // หัวข้อความคิดเห็นทั้งหมด
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'ความคิดเห็น ($commentCount)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
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

            // แสดงรายการคอมเมนต์
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

            // ไม่มีคอมเมนต์เลย
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
