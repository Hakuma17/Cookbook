// lib/widgets/rank_badge.dart

import 'package:flutter/material.dart';

class RankBadge extends StatelessWidget {
  /// 1 = Gold / 2 = Silver / 3 = Bronze  (อื่น ๆ ไม่แสดง)
  final int? rank;

  /// แสดงวงกลมเตือนสีแดง + ไอคอน ⚠
  final bool showWarning;

  /// override เส้นผ่านศูนย์กลางขั้นต่ำ / สูงสุด (optional)
  final double? minDiameter;
  final double? maxDiameter;

  const RankBadge({
    super.key,
    this.rank,
    this.showWarning = false,
    this.minDiameter,
    this.maxDiameter,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      // ✔︎ ใช้พื้นที่จริง (width ของ parent) แทน MediaQuery ทั้งจอ
      final parentW = box.maxWidth.isFinite
          ? box.maxWidth
          : MediaQuery.of(context).size.width;

      // ถ้าพื้นที่ไม่มีจำกัด (เช่นวางทับใน Stack) fallback = screen-w
      double d = parentW * .066; // ≈ 24 px เมื่อ parent ≈ 360 px
      d = d.clamp(
        (minDiameter ?? 20),
        (maxDiameter ?? 32),
      );

      // ---------- กำหนด UI ----------
      final bgColor = showWarning
          ? Colors.redAccent
          : switch (rank) {
              1 => const Color(0xFFFFD700),
              2 => const Color(0xFFB0B0B0),
              3 => const Color(0xFFCD7F32),
              _ => Colors.transparent,
            };

      if (bgColor == Colors.transparent) return const SizedBox.shrink();

      final Widget iconWidget = showWarning
          ? const Icon(Icons.priority_high, color: Colors.white)
          : Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: d * .48,
                fontWeight: FontWeight.w700,
              ),
            );

      return SizedBox(
        width: d,
        height: d,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: bgColor.withOpacity(.35),
                blurRadius: d * .22,
                offset: Offset(0, d * .08),
              ),
            ],
          ),
          child: Center(
            child: FittedBox(child: iconWidget),
          ),
        ),
      );
    });
  }
}
