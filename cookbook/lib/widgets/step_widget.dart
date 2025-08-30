import 'package:flutter/material.dart';
import '../models/recipe_step.dart';

/// StepWidget
/// พรีวิวสเต็ปตามจำนวนที่กำหนด แล้วกด “ดูเพิ่มเติม” เพื่อ full list
class StepWidget extends StatefulWidget {
  final List<RecipeStep> steps;
  final int previewCount;
  final ValueChanged<int>? onStepTap;

  const StepWidget({
    super.key,
    required this.steps,
    this.previewCount = 3,
    this.onStepTap,
  });

  @override
  _StepWidgetState createState() => _StepWidgetState();
}

class _StepWidgetState extends State<StepWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) {
      return const SizedBox.shrink();
    }

    //   1. ลบ Manual Responsive Calculation และใช้ Theme
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final canExpand = widget.steps.length > widget.previewCount;
    final displayList = _isExpanded
        ? widget.steps
        : widget.steps.take(widget.previewCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- กล่องแสดงขั้นตอน ---
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (int i = 0; i < displayList.length; i++) ...[
                _buildStepRow(
                  context: context,
                  step: displayList[i],
                  index: i,
                  // ทำให้รายการสุดท้ายในโหมด preview ดูจางลง
                  isFaded:
                      !_isExpanded && i == displayList.length - 1 && canExpand,
                ),
                if (i < displayList.length - 1) const Divider(height: 24),
              ],
            ],
          ),
        ),

        // --- ปุ่ม "ดูเพิ่มเติม" / "ย่อขนาด" ---
        if (canExpand)
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _isExpanded = !_isExpanded),
              icon: Icon(_isExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down),
              label: Text(_isExpanded ? 'ย่อขั้นตอน' : 'ดูขั้นตอนทั้งหมด'),
            ),
          ),
      ],
    );
  }

  ///   2. แยก UI ของแต่ละแถวออกมาเป็น Helper Function และใช้ Theme
  Widget _buildStepRow({
    required BuildContext context,
    required RecipeStep step,
    required int index,
    required bool isFaded,
  }) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final textColor = isFaded
        ? theme.colorScheme.onSurface.withOpacity(0.5)
        : theme.colorScheme.onSurface;

    return InkWell(
      onTap: widget.onStepTap != null ? () => widget.onStepTap!(index) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- เลขข้อ ---
            Text(
              '${index + 1}.',
              style: textTheme.titleMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
            // --- คำอธิบาย ---
            Expanded(
              child: SelectableText(
                step.description,
                style: textTheme.bodyLarge?.copyWith(
                  color: textColor,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
