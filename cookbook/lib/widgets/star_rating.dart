// lib/widgets/star_rating.dart
//
// Responsive Star-Rating 2025-07-10
// – ปรับ ‘size’ & ‘spacing’ อัตโนมัติเพื่อป้องกัน overflow
// – ไม่กระทบ logic & signature เดิม
// --------------------------------------------------------------------

import 'package:flutter/material.dart';

/// Signature for when the user taps a star.
/// [rating] is the new rating value (1.0 to [starCount].toDouble()).
typedef RatingChangeCallback = void Function(double rating);

/// StarRating
/// แสดงดาว (เต็ม/ว่าง) ตามค่าที่กำหนด
/// - [rating]           : คะแนนปัจจุบัน (0.0 – starCount)
/// - [starCount]        : จำนวนดาว (default 5)
/// - [size]             : *ขนาดไอคอนดาวเริ่มต้น* (default 32 ตาม mock-up)
/// - [filledColor]      : สีดาวเต็ม (default #FFCC00)
/// - [emptyColor]       : สีดาวว่าง (default #BFBFBF ตาม mock-up)
/// - [spacing]          : *ระยะห่างเริ่มต้น* (default 8 ตาม mock-up)
/// - [onRatingChanged]  : ถ้าไม่ null จะรองรับการแตะเพื่อเปลี่ยนเรตติ้ง
class StarRating extends StatelessWidget {
  final double rating;
  final int starCount;
  final double size;
  final Color filledColor;
  final Color emptyColor;
  final double spacing;
  final RatingChangeCallback? onRatingChanged;

  const StarRating({
    Key? key,
    this.rating = 0.0,
    this.starCount = 5,
    this.size = 32.0,
    this.filledColor = const Color(0xFFFFCC00),
    this.emptyColor = const Color(0xFFBFBFBF),
    this.spacing = 8.0,
    this.onRatingChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      // ────────── Responsive block ──────────
      // 1) คำนวณ “พื้นที่จริง” ที่แสดง Row นี้ได้
      final maxW = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : MediaQuery.of(ctx).size.width;

      final maxH = constraints.maxHeight.isFinite
          ? constraints.maxHeight
          : double.infinity;

      // 2) พื้นที่ที่ต้องการโดยใช้ค่าตั้งต้น
      final needW = starCount * size + (starCount - 1) * spacing;
      final needH = size;

      // 3) scale = min(scaleW , scaleH , 1.0)
      final scaleW = needW > maxW && maxW > 0 ? maxW / needW : 1.0;
      final scaleH = needH > maxH && maxH > 0 ? maxH / needH : 1.0;
      final scale = [scaleW, scaleH, 1.0].reduce((a, b) => a < b ? a : b);

      // 4) ขนาดจริงหลังปรับ (ยังคงสัดส่วน)
      final starSz = size * scale;
      final starSp = spacing * scale;
      // ──────────────────────────────────────

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(starCount * 2 - 1, (index) {
          if (index.isOdd) {
            // ช่องว่างระหว่างดาว
            return SizedBox(width: starSp);
          }
          final starIndex = index ~/ 2;
          final filled = starIndex < rating;

          return GestureDetector(
            onTap: onRatingChanged == null
                ? null
                : () => onRatingChanged!((starIndex + 1).toDouble()),
            child: Icon(
              filled ? Icons.star : Icons.star_outline,
              size: starSz,
              color: filled ? filledColor : emptyColor,
            ),
          );
        }),
      );
    });
  }
}
