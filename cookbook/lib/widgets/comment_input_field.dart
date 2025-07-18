import 'package:flutter/material.dart';

/// กล่องกดเพื่อแสดงความคิดเห็น / แก้ไข
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
    /* ── responsive metrics ── */
    final w = MediaQuery.of(context).size.width;
    double clamp(double v, double min, double max) =>
        v < min ? min : (v > max ? max : v);

    final radius = clamp(w * 0.035, 10, 18); // มุมโค้งกล่อง
    final height = clamp(w * 0.128, 46, 60); // ความสูง field
    final iconSz = clamp(w * 0.052, 18, 22); // ขนาดไอคอนดินสอ
    final fontF = clamp(w * 0.034, 12, 14); // ฟอนต์ label
    final padH = clamp(w * 0.04, 12, 20); // padding แนวนอน
    final gap = clamp(w * 0.018, 4, 8); // ช่องว่างไอคอน-ข้อความ

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.grey[700]! : const Color(0xFFDDDDDD);
    final textColor = isDark ? Colors.grey[300]! : const Color(0xFF666666);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padH),
      child: Material(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          splashColor: const Color(0xFFFFD180).withOpacity(0.3),
          highlightColor: Colors.transparent,
          child: Container(
            height: height,
            padding: EdgeInsets.symmetric(horizontal: padH * 0.75),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: 1),
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.mode_edit_outline,
                    size: iconSz, color: const Color(0xFF838383)),
                SizedBox(width: gap),
                Text(label,
                    style: TextStyle(
                        fontSize: fontF,
                        fontWeight: FontWeight.w600,
                        color: textColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
