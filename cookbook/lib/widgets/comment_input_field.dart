import 'package:flutter/material.dart';

/// กล่องให้กดเพื่อแสดงความคิดเห็นหรือแก้ไข (ตามดีไซน์ Frame 27)
class CommentInputField extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const CommentInputField({
    Key? key,
    required this.onTap,
    this.label = 'แสดงความคิดเห็น',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.grey[700]! : const Color(0xFFDDDDDD);
    final textColor = isDark ? Colors.grey[300]! : const Color(0xFF666666);

    return Padding(
      // ชิดขอบซ้าย–ขวา 16px ตาม mock-up
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor:
              const Color(0xFFFFD180).withOpacity(0.3), // ripple สีส้มอ่อน
          highlightColor: Colors.transparent,
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: 1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.mode_edit_outline,
                  size: 20,
                  color: Color(0xFF838383),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
