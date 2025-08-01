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

    final theme = Theme.of(context);

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
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (int i = 0; i < displayList.length; i++) ...[
                _buildIngredientRow(
                  context: context,
                  item: displayList[i],
                  scaleFactor: scaleFactor,
                  isFaded:
                      !_isExpanded && i == displayList.length - 1 && canExpand,
                ),
                if (i < displayList.length - 1) const Divider(height: 24),
              ],
            ],
          ),
        ),

        if (canExpand) _buildExpandButton(theme),
      ],
    );
  }

  /// แถววัตถุดิบ (ชื่อ / ปริมาณ)
  Widget _buildIngredientRow({
    required BuildContext context,
    required IngredientQuantity item,
    required double scaleFactor,
    required bool isFaded,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // ✨ สร้างสไตล์ "มีเดียมแต่ไม่หนา" ไว้ใช้ซ้ำ
    final TextStyle nameStyle = (textTheme.titleMedium ?? textTheme.bodyLarge!)
        .copyWith(fontWeight: FontWeight.w400);
    final TextStyle qtyStyle = (textTheme.titleMedium ?? textTheme.bodyLarge!)
        .copyWith(fontWeight: FontWeight.w400);

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
        // --- ชื่อวัตถุดิบ (ไม่หนา) ---
        Expanded(
          flex: 3,
          child: Text(
            item.description.isNotEmpty ? item.description : item.name,
            style: nameStyle.copyWith(color: textColor), // ✨
          ),
        ),
        const SizedBox(width: 16),
        // --- ปริมาณ + หน่วย (ไม่หนา) ---
        Expanded(
          flex: 2,
          child: Text(
            '$quantityString ${item.unit}',
            textAlign: TextAlign.end,
            style: qtyStyle.copyWith(color: textColor), // ✨
            /* โค้ดเดิม (ตัวหนา)
            style: textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            */
          ),
        ),
      ],
    );
  }

  Widget _buildExpandButton(ThemeData theme) {
    return TextButton.icon(
      onPressed: () => setState(() => _isExpanded = !_isExpanded),
      icon: Icon(
        _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
      ),
      label: const Text('ดูเพิ่มเติม'), // ข้อความนี้ไม่จำเป็นต้องหนา
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.primary,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
      ),
    );
  }
}
