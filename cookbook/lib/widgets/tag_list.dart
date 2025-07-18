// lib/widgets/tag_list.dart

import 'package:flutter/material.dart';

/// TagList
/// แสดงชุดป้าย (tags) เป็นแนวนอนแบบ wrap
class TagList extends StatelessWidget {
  /// รายการชื่อป้าย
  final List<String>? tags;

  /// ปรับ font-size ภายนอก (เช่น ในหน้า RecipeDetail)
  final double? fontSize;

  const TagList({
    Key? key,
    this.tags,
    this.fontSize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final list = tags ?? [];
    if (list.isEmpty) return const SizedBox.shrink();

    /* ───── responsive helpers ───── */
    final w = MediaQuery.of(context).size.width;
    double scale = (w / 360).clamp(0.78, 1.30); // safe-range กว้างขึ้น

    // ป้องกันค่าเล็ก/ใหญ่เกินด้วย clamp ภายใน
    double px(double v, {double min = 2, double max = 999}) =>
        (v * scale).clamp(min, max).toDouble();

    final gapH = px(10.9);
    final gapV = px(4.36);
    final padH = px(10.9);
    final padV = px(4.36);
    final br = px(13.1, min: 6); // มุมโค้งอย่างน้อย 6px
    final stroke = px(1.09, min: .6); // เส้นบางสุด .6px
    final fz = fontSize ?? px(14, min: 11, max: 18); // font 11-18

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: px(16)),
      child: Wrap(
        spacing: gapH,
        runSpacing: gapV,
        children: list.map((tag) {
          return Container(
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: const Color(0xFFFF9B05),
                width: stroke,
              ),
              borderRadius: BorderRadius.circular(br),
            ),
            child: Text(
              tag,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w600,
                fontSize: fz,
                height: 1.25, // line-height คงที่-สวย
                color: const Color(0xFFFF9B05),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
