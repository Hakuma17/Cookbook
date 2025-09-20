import 'package:flutter/material.dart';

/// Signature for when the user taps a star.
/// [rating] is the new rating value (1.0 to [starCount].toDouble()).
typedef RatingChangeCallback = void Function(double rating);

/// StarRating
/// แสดงดาว (เต็ม/ว่าง) ตามค่าที่กำหนด
class StarRating extends StatelessWidget {
  final double rating;
  final int starCount;
  final double size;
  final Color? filledColor;
  final Color? emptyColor;
  final double spacing;
  final RatingChangeCallback? onRatingChanged;

  const StarRating({
    super.key,
    this.rating = 0.0,
    this.starCount = 5,
    this.size = 24.0, //   1. ปรับขนาดเริ่มต้นให้เหมาะสม
    this.filledColor,
    this.emptyColor,
    this.spacing = 4.0, //   2. ปรับระยะห่างเริ่มต้นให้เหมาะสม
    this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    //   3. ลบ LayoutBuilder และการคำนวณทั้งหมด
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // กำหนดสีเริ่มต้นโดยอิงจาก Theme หากไม่ได้ระบุมา
    final finalFilledColor = filledColor ?? Colors.amber.shade700;
    final finalEmptyColor =
        emptyColor ?? colorScheme.onSurface.withValues(alpha: 0.3);

    //   4. ใช้ for loop ใน Row children เพื่อสร้าง UI ที่สะอาดและอ่านง่าย
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < starCount; i++) ...[
          GestureDetector(
            onTap: onRatingChanged == null
                ? null
                : () => onRatingChanged!((i + 1).toDouble()),
            child: Icon(
              i < rating ? Icons.star_rounded : Icons.star_border_rounded,
              size: size,
              color: i < rating ? finalFilledColor : finalEmptyColor,
            ),
          ),
          // เพิ่มช่องว่างถ้ายังไม่ใช่ดาวดวงสุดท้าย
          if (i < starCount - 1) SizedBox(width: spacing),
        ]
      ],
    );
  }
}
