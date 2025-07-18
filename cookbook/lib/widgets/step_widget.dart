// lib/widgets/step_widget.dart

import 'package:flutter/material.dart';
import '../models/recipe_step.dart';

/// StepWidget
/// พรีวิวสเต็ป 3 ขั้นแรก (blur เฉพาะข้อสุดท้าย) แล้วกด “ดูเพิ่มเติม” เพื่อ full list
class StepWidget extends StatefulWidget {
  final List<RecipeStep>? steps;
  final int previewCount;
  final ValueChanged<int>? onStepTap;
  final VoidCallback? onViewAll;

  const StepWidget({
    Key? key,
    this.steps,
    this.previewCount = 3,
    this.onStepTap,
    this.onViewAll,
  }) : super(key: key);

  @override
  _StepWidgetState createState() => _StepWidgetState();
}

class _StepWidgetState extends State<StepWidget> {
  bool _expanded = false;
  static const disabledColor = Color(0xFF908F8F);

  @override
  Widget build(BuildContext context) {
    final list = widget.steps ?? [];
    if (list.isEmpty) return const SizedBox.shrink();

    /* ───── responsive numbers (อิงดีไซน์กว้าง 360 px) ───── */
    final w = MediaQuery.of(context).size.width;
    double scale = (w / 360).clamp(0.78, 1.30); // ปรับช่วงให้กว้างขึ้นเล็กน้อย

    // helper → ย่อ/ขยายค่าตามสเกล แต่ “ปัด” ให้อยู่บน pixel ครึ่ง (ลด blurry)
    double px(double v) => (v * scale).clamp(v * .75, v * 1.3);

    final br = px(13.088); // border-radius & padding
    final gapV = px(13.088);
    final gapH = px(8.77);
    final font15 = px(15);
    final font14 = px(14);
    final iconSz = px(17.45);
    final borderW = px(1.09);

    /* ───── build UI ───── */
    final displayCount = _expanded ? list.length : widget.previewCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: px(16)),
          padding: EdgeInsets.all(br),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD8D8D8), width: borderW),
            borderRadius: BorderRadius.circular(br),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(displayCount, (i) {
              final step = list[i];

              // blur เฉพาะสเต็ปสุดท้าย เมื่อยังไม่ expand
              final isDisabled = !_expanded && i == displayCount - 1;
              final textColor =
                  isDisabled ? disabledColor : const Color(0xFF000000);

              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ▸ เลขข้อ
                      Text(
                        '${i + 1}.',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: font15,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: textColor,
                        ),
                      ),
                      SizedBox(width: gapH),
                      // ▸ คำอธิบาย (ใช้ SelectableText ⇒ ตัดคำดีขึ้นและเลือกก๊อปปี้ได้)
                      Expanded(
                        child: SelectableText(
                          step.description,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: font14,
                            height: 1.45,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (i < displayCount - 1) ...[
                    SizedBox(height: gapV),
                    Divider(
                      color: const Color(0xFFD8D8D8),
                      thickness: borderW,
                      height: borderW, // ลดช่องว่างเกินจำเป็น
                    ),
                    SizedBox(height: gapV),
                  ],
                ],
              );
            }),
          ),
        ),
        if (list.length > widget.previewCount)
          Center(
            child: TextButton.icon(
              onPressed: () {
                if (!_expanded && widget.onViewAll != null) {
                  widget.onViewAll!();
                } else {
                  setState(() => _expanded = !_expanded);
                }
              },
              icon: Icon(
                _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: iconSz,
                color: const Color(0xFFFF9B05),
              ),
              label: Text(
                _expanded ? 'ซ่อน' : 'ดูเพิ่มเติม',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: px(14),
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFFF9B05),
                ),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: px(4.36)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
      ],
    );
  }
}
