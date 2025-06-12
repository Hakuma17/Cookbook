// lib/widgets/star_rating.dart

import 'package:flutter/material.dart';

/// Signature for when the user taps a star.
/// [rating] is the new rating value (1.0 to [starCount].toDouble()).
typedef RatingChangeCallback = void Function(double rating);

/// StarRating
/// แสดงดาว (เต็ม/ว่าง) ตามค่าที่กำหนด
/// - [rating]           : คะแนนปัจจุบัน (0.0 – starCount)
/// - [starCount]        : จำนวนดาว (default 5)
/// - [size]             : ขนาดไอคอนดาว (default 32 ตาม mock-up)
/// - [filledColor]      : สีดาวเต็ม (default #FFCC00)
/// - [emptyColor]       : สีดาวว่าง (default #BFBFBF ตาม mock-up)
/// - [spacing]          : ระยะห่างระหว่างดาว (default 8 ตาม mock-up)
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
    this.size = 32.0, // ปรับเป็น 32px ตาม mock-up
    this.filledColor = const Color(0xFFFFCC00),
    this.emptyColor = const Color(0xFFBFBFBF),
    this.spacing = 8.0, // ปรับเป็น 8px ตาม mock-up
    this.onRatingChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(starCount * 2 - 1, (index) {
        if (index.isOdd) {
          // ช่องว่างระหว่างดาว
          return SizedBox(width: spacing);
        }
        final starIndex = index ~/ 2;
        final filled = starIndex < rating;
        return GestureDetector(
          onTap: onRatingChanged == null
              ? null
              : () => onRatingChanged!((starIndex + 1).toDouble()),
          child: Icon(
            filled ? Icons.star : Icons.star_outline,
            size: size,
            color: filled ? filledColor : emptyColor,
          ),
        );
      }),
    );
  }
}
