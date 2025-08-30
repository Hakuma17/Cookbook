import 'package:flutter/material.dart';

/// TagList
/// แสดงชุดป้าย (tags) เป็นแนวนอนแบบ wrap
class TagList extends StatelessWidget {
  /// รายการชื่อป้าย
  final List<String> tags;

  // 🗑️ ลบ fontSize ออก เพราะควรใช้ขนาดจาก Theme เพื่อความสอดคล้อง

  const TagList({
    super.key,
    required this.tags,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    //   1. ลบ Manual Responsive Calculation และใช้ Theme
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    //   2. ใช้ Wrap Widget ซึ่งเหมาะสมที่สุดสำหรับการแสดง Tag
    return Wrap(
      spacing: 8.0, // ระยะห่างแนวนอนระหว่าง Chip
      runSpacing: 8.0, // ระยะห่างแนวตั้งเมื่อขึ้นบรรทัดใหม่
      children: tags.map((tag) {
        //   3. เปลี่ยนจาก Container ที่สร้างเอง มาเป็น Chip Widget มาตรฐาน
        return Chip(
          label: Text(tag),
          //   4. ใช้สไตล์จาก Theme ส่วนกลางทั้งหมด
          labelStyle: textTheme.labelLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
          backgroundColor: colorScheme.primaryContainer.withOpacity(0.4),
          side: BorderSide(color: colorScheme.primary.withOpacity(0.6)),
          // ทำให้ Chip มีขนาดกระทัดรัดขึ้น
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        );
      }).toList(),
    );
  }
}
