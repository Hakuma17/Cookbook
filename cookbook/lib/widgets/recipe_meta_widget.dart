// lib/widgets/recipe_meta_widget.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RecipeMetaWidget extends StatelessWidget {
  final String name;
  final double? averageRating;
  final int? reviewCount;
  final DateTime? createdAt;
  final int? prepTimeMinutes;

  const RecipeMetaWidget({
    super.key,
    required this.name,
    this.averageRating,
    this.reviewCount,
    this.createdAt,
    this.prepTimeMinutes,
  });

  // short helper
  double _rs(double w, double factor, double min, double max) =>
      factor.clamp(min, max).toDouble();

  @override
  Widget build(BuildContext context) {
    /* ───── แปลงข้อมูล ───── */
    final dateStr = createdAt != null
        ? DateFormat('d MMMM yyyy', 'th').format(createdAt!)
        : '-';
    final ratingStr =
        averageRating != null ? averageRating!.toStringAsFixed(1) : '-';
    final prepStr = prepTimeMinutes != null ? '$prepTimeMinutes นาที' : '-';

    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth; // พื้นที่แนวนอนที่ใช้ได้

      /* ───── responsive numbers ───── */
      final titleF = _rs(w, w * .055, 18, 26);
      final bodyF = _rs(w, titleF * .65, 12, 16);
      final iconSz = _rs(w, bodyF * 1.25, 14, 20);
      final pillPadV = _rs(w, 4, 3, 6);
      final pillPadH = pillPadV * 2;
      final pillBR = _rs(w, 25, 22, 30);
      final gap = _rs(w, 8, 6, 10);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /* ─── ชื่อสูตร + Rating pill ─── */
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ใช้ Flexible เพื่อกัน overflow ในจอแคบ
              Flexible(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: titleF,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    color: const Color(0xFF000000),
                  ),
                ),
              ),
              SizedBox(width: gap),
              Container(
                padding: EdgeInsets.symmetric(
                    vertical: pillPadV, horizontal: pillPadH),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFABABAB), width: 1),
                  borderRadius: BorderRadius.circular(pillBR),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star,
                        size: iconSz, color: const Color(0xFFFFCC00)),
                    SizedBox(width: iconSz * .15),
                    Text(ratingStr,
                        style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: bodyF,
                            fontWeight: FontWeight.w500)),
                    if (reviewCount != null) ...[
                      SizedBox(width: iconSz * .15),
                      Text('(${reviewCount!})',
                          style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: bodyF,
                              fontWeight: FontWeight.w500)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: gap),
          /* ─── meta row (วันที่ & เวลาเตรียม) ─── */
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: iconSz, color: const Color(0xFF908F8F)),
              SizedBox(width: iconSz * .25),
              Text(dateStr,
                  style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: bodyF,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF908F8F))),
              SizedBox(width: gap * 1.5),
              Icon(Icons.schedule,
                  size: iconSz, color: const Color(0xFF908F8F)),
              SizedBox(width: iconSz * .25),
              Text(prepStr,
                  style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: bodyF,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF908F8F))),
            ],
          ),
        ],
      );
    });
  }
}
