// lib/widgets/recipe_meta_widget.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RecipeMetaWidget extends StatelessWidget {
  final String name;
  final double? averageRating; // e.g. 4.9
  final int? reviewCount; // e.g. 12
  final DateTime? createdAt; // e.g. DateTime
  final int? prepTimeMinutes; // e.g. 20

  const RecipeMetaWidget({
    Key? key,
    required this.name,
    this.averageRating,
    this.reviewCount,
    this.createdAt,
    this.prepTimeMinutes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ฟอร์แมตวันที่แบบ "d MMMM yyyy"
    final dateStr = createdAt != null
        ? DateFormat('d MMMM yyyy', 'th').format(createdAt!)
        : '-';
    // คะแนนเฉลี่ย
    final ratingStr =
        averageRating != null ? averageRating!.toStringAsFixed(1) : '-';
    // เวลาเตรียม
    final prepStr = prepTimeMinutes != null ? '$prepTimeMinutes นาที' : '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ชื่อสูตร + Rating pill
        Row(
          children: [
            // ชื่อสูตร
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 22, // ตาม CSS
                  fontWeight: FontWeight.w700, // 700
                  height: 24 / 22, // line-height 24px
                  color: Color(0xFF000000),
                ),
              ),
            ),
            SizedBox(width: 8.73), // gap ตาม CSS

            // Rating pill
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: 4.36267, // ตาม CSS
                horizontal: 8.72533, // ตาม CSS
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: const Color(0xFFABABAB),
                  width: 1.09067, // ตาม CSS
                ),
                borderRadius: BorderRadius.circular(25.0853), // ตาม CSS
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.star,
                    size: 15.27, // ตาม CSS
                    color: Color(0xFFFFCC00),
                  ),
                  const SizedBox(width: 2.18), // ตาม CSS gap
                  Text(
                    ratingStr,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13, // ตาม CSS
                      fontWeight: FontWeight.w500,
                      height: 16 / 13, // line-height 16px
                      color: Color(0xFF000000),
                    ),
                  ),
                  if (reviewCount != null) ...[
                    const SizedBox(width: 2.18),
                    Text(
                      '(${reviewCount!})',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 13, // ให้เท่ากัน
                        fontWeight: FontWeight.w500,
                        height: 16 / 13,
                        color: Color(0xFF000000),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 8.73), // vertical gap ตาม CSS

        // วันที่สร้าง + เวลาเตรียม
        Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 17.45, // ตาม CSS
              color: Color(0xFF908F8F),
            ),
            const SizedBox(width: 4.36), // gap ตาม CSS
            Text(
              dateStr,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14, // ตาม CSS
                fontWeight: FontWeight.w600,
                height: 24 / 14, // line-height 24px
                color: Color(0xFF908F8F),
              ),
            ),
            const SizedBox(width: 13.09), // gap ตาม CSS
            const Icon(
              Icons.schedule,
              size: 17.45,
              color: Color(0xFF908F8F),
            ),
            const SizedBox(width: 4.36),
            Text(
              prepStr,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 24 / 14,
                color: Color(0xFF908F8F),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
