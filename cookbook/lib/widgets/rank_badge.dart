import 'package:flutter/material.dart';

class RankBadge extends StatelessWidget {
  /// 1 = Gold / 2 = Silver / 3 = Bronze (อื่น ๆ ไม่แสดง)
  final int? rank;

  /// แสดงวงกลมเตือนสีแดง + ไอคอน ⚠
  final bool showWarning;

  ///   1. เพิ่ม parameter สำหรับกำหนดขนาดโดยตรงจาก Parent
  final double radius;

  const RankBadge({
    super.key,
    this.rank,
    this.showWarning = false,
    this.radius = 14.0, // กำหนดขนาดเริ่มต้นที่เหมาะสม
  });

  @override
  Widget build(BuildContext context) {
    //   2. ลบ Manual Responsive Calculation และใช้ Theme
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    // --- กำหนดสีพื้นหลัง ---
    final Color backgroundColor = showWarning
        ? colorScheme.error // ใช้สี error จาก Theme
        : switch (rank) {
            1 => const Color(0xFFFFD700), // Gold
            2 => const Color(0xFFC0C0C0), // Silver
            3 => const Color(0xFFCD7F32), // Bronze
            _ => Colors.transparent,
          };

    // ถ้าไม่มี rank และไม่ใช่ warning, จะไม่แสดงผลอะไรเลย
    if (backgroundColor == Colors.transparent) {
      return const SizedBox.shrink();
    }

    // --- กำหนด child (ตัวเลข หรือ ไอคอน) ---
    final Widget child = showWarning
        ? Icon(
            Icons.priority_high_rounded,
            size: radius * 1.1, // กำหนดขนาดไอคอนตามสัดส่วนของ radius
            color: colorScheme.onError, // ใช้สี onError จาก Theme
          )
        : Text(
            '$rank',
            //   3. ใช้ TextStyle จาก Theme ส่วนกลาง
            style: textTheme.labelSmall?.copyWith(
              color: Colors.white, // สีขาวยังคงเหมาะสมกับพื้นหลังสีๆ
              fontWeight: FontWeight.bold,
            ),
          );

    //   4. เปลี่ยนมาใช้ CircleAvatar ซึ่งเป็น Widget ที่เหมาะสมที่สุด
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: FittedBox(
        // ทำให้ child ปรับขนาดพอดีกับวงกลม
        child: child,
      ),
    );
  }
}
