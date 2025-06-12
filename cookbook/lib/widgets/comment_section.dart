// lib/widgets/comment_section.dart

import 'package:flutter/material.dart';
import '../models/comment.dart';
import 'comment_card.dart';

/// ส่วนแสดงความคิดเห็นและการให้ดาว (Frame 160)
class CommentSection extends StatelessWidget {
  /// รายการความคิดเห็น
  final List<Comment>? comments;

  /// คะแนนก่อนหน้านี้ (0–5)
  final int currentRating;

  /// ระบุว่าผู้ใช้ล็อกอินหรือยัง
  final bool isLoggedIn;

  /// เมื่อผู้ใช้เลือกดาว (1–5)
  final ValueChanged<int>? onRatingSelected;

  /// เมื่อกดกรอบ “แสดงความคิดเห็น”
  final VoidCallback? onCommentPressed;

  const CommentSection({
    Key? key,
    this.comments,
    this.currentRating = 0,
    this.isLoggedIn = false,
    this.onRatingSelected,
    this.onCommentPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final totalComments = (comments ?? []).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── กล่องหลัก (Frame 160) ───
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            // เอา height:146 ออก → ให้ปรับความสูงอัตโนมัติ
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFABABAB), width: 1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // คำถาม (Frame 159)
                SizedBox(
                  width: 228,
                  height: 22,
                  child: Text(
                    'คุณคิดอย่างไรกับสูตรนี้บ้าง?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 22 / 12,
                      color: Color(0xFF000000),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // แถวดาว (Frame 158)
                SizedBox(
                  height: 32,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final filled = i < currentRating;
                      return GestureDetector(
                        onTap: () => onRatingSelected?.call(i + 1),
                        child: Icon(
                          filled ? Icons.star : Icons.star_outline,
                          size: 32,
                          color: const Color(0xFFBFBFBF),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 8),

                // กล่องแสดงความคิดเห็น (Frame 27)
                if (isLoggedIn && onCommentPressed != null)
                  GestureDetector(
                    onTap: onCommentPressed!,
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                            color: const Color(0xFF828282), width: 1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.mode_edit_outline,
                            size: 20,
                            color: Color(0xFF838383),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'แสดงความคิดเห็น',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 22 / 12,
                              color: Color(0xFF838383),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ─── หัวข้อความคิดเห็น ───
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'ความคิดเห็น ($totalComments)',
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 24 / 16,
              color: Color(0xFF000000),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // ─── การ์ดแต่ละรีวิว ───
        if (comments != null)
          ...comments!.map((c) => CommentCard(comment: c)).toList(),
      ],
    );
  }
}
