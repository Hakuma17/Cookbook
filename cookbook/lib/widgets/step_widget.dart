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

    final displayCount = _expanded ? list.length : widget.previewCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(13.088),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD8D8D8), width: 1.09),
            borderRadius: BorderRadius.circular(13.088),
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
                      Text(
                        '${i + 1}.',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 18 / 15,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 8.77),
                      Expanded(
                        child: Text(
                          step.description,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 14,
                            height: 18 / 14,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (i < displayCount - 1) const SizedBox(height: 13.088),
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
                size: 17.45,
                color: const Color(0xFFFF9B05),
              ),
              label: Text(
                _expanded ? 'ซ่อน' : 'ดูเพิ่มเติม',
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 24 / 14,
                  color: Color(0xFFFF9B05),
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 4.36),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
      ],
    );
  }
}
