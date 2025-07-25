import 'package:flutter/material.dart';

import '../models/comment.dart';
import 'comment_card.dart';
import 'comment_input_field.dart';

/// ส่วนแสดงและจัดการคอมเมนต์ทั้งหมดของสูตรอาหาร
class CommentSection extends StatelessWidget {
  // ✅ 1. รับข้อมูลที่ประมวลผลแล้วมาจาก Parent
  final Comment? myComment;
  final List<Comment> otherComments;

  final int currentRating;
  final bool isLoggedIn;
  final ValueChanged<int> onRatingSelected;
  final VoidCallback onCommentPressed;
  final ValueChanged<Comment> onEdit;
  final ValueChanged<Comment> onDelete;

  const CommentSection({
    super.key,
    this.myComment, // คอมเมนต์ของฉัน (อาจเป็น null ถ้ายังไม่เคยคอมเมนต์)
    required this.otherComments,
    required this.currentRating,
    required this.isLoggedIn,
    required this.onRatingSelected,
    required this.onCommentPressed,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ 2. ลบ FutureBuilder และ Manual Responsive ทั้งหมด
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final hasMyComment = myComment != null && !myComment!.isEmpty;
    final totalComments = otherComments.length + (hasMyComment ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- ส่วนของ "ความคิดเห็นของฉัน" ---
        if (isLoggedIn)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: hasMyComment
                ? _buildMyCommentBox(context, myComment!)
                : _buildFirstCommentBox(context),
          ),

        const SizedBox(height: 24),

        // --- ส่วนของ "ความคิดเห็นอื่นๆ" ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'ความคิดเห็นทั้งหมด ($totalComments)',
            style: textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 8),

        if (otherComments.isNotEmpty)
          // ListView ถูกสร้างภายใน Column จึงต้องใช้ shrinkWrap และ physics
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: otherComments.length,
            itemBuilder: (context, index) {
              return CommentCard(
                comment: otherComments[index],
                onEdit: onEdit,
                onDelete: onDelete,
              );
            },
          )
        else if (!hasMyComment) // แสดงเมื่อไม่มีคอมเมนต์เลย
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Center(
              child: Text(
                'ยังไม่มีความคิดเห็นสำหรับสูตรนี้',
                style: textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// ✅ 3. แยก UI ย่อยออกมาเป็น Helper Function และใช้ Theme
  // Widget สำหรับแสดงคอมเมนต์ของตัวเองที่มีอยู่แล้ว
  Widget _buildMyCommentBox(BuildContext context, Comment comment) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.primary, width: 1.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ความคิดเห็นของคุณ', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          // CommentCard ถูก refactor ไปแล้ว จะดึง Theme เอง
          CommentCard(comment: comment, onEdit: onEdit, onDelete: onDelete),
        ],
      ),
    );
  }

  // Widget สำหรับชวนให้คอมเมนต์ครั้งแรก
  Widget _buildFirstCommentBox(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('คุณคิดอย่างไรกับสูตรนี้?', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final ratingValue = i + 1;
                return IconButton(
                  icon: Icon(
                    ratingValue <= currentRating
                        ? Icons.star
                        : Icons.star_border,
                    size: 32,
                    color: ratingValue <= currentRating
                        ? Colors.amber
                        : Colors.grey,
                  ),
                  onPressed: () => onRatingSelected(ratingValue),
                );
              }),
            ),
            const SizedBox(height: 12),
            CommentInputField(onTap: onCommentPressed),
          ],
        ),
      ),
    );
  }
}
