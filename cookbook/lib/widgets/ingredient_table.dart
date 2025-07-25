import 'package:flutter/material.dart';
import '../models/ingredient_quantity.dart';

class IngredientTable extends StatefulWidget {
  final List<IngredientQuantity> items;
  final int previewCount;
  final int baseServings;
  final int currentServings;

  const IngredientTable({
    super.key,
    required this.items,
    this.previewCount = 5,
    required this.baseServings,
    required this.currentServings,
  });

  @override
  State<IngredientTable> createState() => _IngredientTableState();
}

class _IngredientTableState extends State<IngredientTable> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty || widget.baseServings <= 0) {
      return const SizedBox.shrink();
    }

    // ✅ 1. ลบ Manual Responsive Calculation และใช้ Theme
    final theme = Theme.of(context);

    // Logic การแสดงผล (คงเดิม)
    final scaleFactor = widget.currentServings / widget.baseServings;
    final displayList = _isExpanded
        ? widget.items
        : widget.items.take(widget.previewCount).toList();
    final canExpand = widget.items.length > widget.previewCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- กล่องตารางวัตถุดิบ ---
        Container(
          padding: const EdgeInsets.all(16.0),
          // ✅ 2. ใช้สไตล์จาก Theme
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            // ✅ 3. ใช้ for loop เพื่อสร้างรายการและเส้นคั่น ทำให้โค้ดสะอาดขึ้น
            children: [
              for (int i = 0; i < displayList.length; i++) ...[
                _buildIngredientRow(
                  context: context,
                  item: displayList[i],
                  scaleFactor: scaleFactor,
                  // ทำให้รายการสุดท้ายในโหมด preview ดูจางลง (เป็น UX ที่ดี)
                  isFaded:
                      !_isExpanded && i == displayList.length - 1 && canExpand,
                ),
                if (i < displayList.length - 1) const Divider(height: 24),
              ],
            ],
          ),
        ),

        // --- ปุ่ม "ดูเพิ่มเติม" / "ย่อขนาด" ---
        if (canExpand) _buildExpandButton(theme),
      ],
    );
  }

  /// ✅ 4. แยก UI ย่อยออกมาเป็น Helper Function และใช้ Theme
  Widget _buildIngredientRow({
    required BuildContext context,
    required IngredientQuantity item,
    required double scaleFactor,
    required bool isFaded,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // คำนวณปริมาณตามจำนวนเสิร์ฟ
    final adjustedQuantity = item.quantity * scaleFactor;
    final quantityString = adjustedQuantity % 1 == 0
        ? adjustedQuantity.toInt().toString()
        : adjustedQuantity.toStringAsFixed(2);

    final textColor = isFaded
        ? colorScheme.onSurface.withOpacity(0.5)
        : colorScheme.onSurface;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- ชื่อวัตถุดิบ ---
        Expanded(
          flex: 3,
          child: Text(
            item.description.isNotEmpty ? item.description : item.name,
            style: textTheme.bodyLarge?.copyWith(color: textColor),
          ),
        ),
        const SizedBox(width: 16),
        // --- ปริมาณ + หน่วย ---
        Expanded(
          flex: 2,
          child: Text(
            '$quantityString ${item.unit}',
            textAlign: TextAlign.end,
            style: textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandButton(ThemeData theme) {
    return TextButton.icon(
      onPressed: () => setState(() => _isExpanded = !_isExpanded),
      icon: Icon(
          _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
      label: Text(_isExpanded ? 'ย่อขนาด' : 'ดูเพิ่มเติม'),
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.primary,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
      ),
    );
  }
}
