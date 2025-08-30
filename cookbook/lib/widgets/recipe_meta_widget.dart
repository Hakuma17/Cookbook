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

  // 🗑️ 1. ลบ Helper สำหรับคำนวณ Responsive และสร้าง Style ทิ้งทั้งหมด
  // double _rs(...) { ... }

  @override
  Widget build(BuildContext context) {
    //   2. ใช้ Theme จาก context
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    /* ───── แปลงข้อมูล (Logic เดิมดีอยู่แล้ว) ───── */
    final dateStr = createdAt != null
        ? DateFormat('d MMMM yyyy', 'th').format(createdAt!)
        : '-';
    final ratingStr =
        averageRating != null ? averageRating!.toStringAsFixed(1) : '-';
    final prepStr = prepTimeMinutes != null ? '$prepTimeMinutes นาที' : '-';

    // 🗑️ 3. ลบ LayoutBuilder ออก
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /* ─── ชื่อสูตร + Rating pill ─── */
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ใช้ Flexible เพื่อป้องกันชื่อยาวล้นจอ
            Flexible(
              child: Text(
                name,
                //   4. ใช้ TextStyle จาก Theme ส่วนกลาง
                style: textTheme.headlineSmall?.copyWith(height: 1.2),
              ),
            ),
            const SizedBox(width: 8),
            //   5. เปลี่ยนมาใช้ Chip Widget ที่สวยงามและจัดการง่าย
            Chip(
              avatar: Icon(Icons.star_rounded,
                  size: 18, color: Colors.amber.shade800),
              label: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: ratingStr,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (reviewCount != null)
                      TextSpan(
                        text: ' ($reviewCount)',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              // Chip จะดึงสไตล์ส่วนใหญ่มาจาก ChipTheme ใน main.dart
            ),
          ],
        ),
        const SizedBox(height: 8),
        /* ─── meta row (วันที่ & เวลาเตรียม) ─── */
        Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              dateStr,
              style: textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 16),
            Icon(Icons.schedule_outlined,
                size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              prepStr,
              style: textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}
