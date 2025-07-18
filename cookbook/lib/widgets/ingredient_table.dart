// lib/widgets/ingredient_table.dart

import 'package:flutter/material.dart';
import '../models/ingredient_quantity.dart';

class IngredientTable extends StatefulWidget {
  final List<IngredientQuantity>? items;
  final int previewCount;
  final int baseServings;
  final int currentServings;
  final double? fontSize;

  const IngredientTable({
    Key? key,
    this.items,
    this.previewCount = 5,
    required this.baseServings,
    required this.currentServings,
    this.fontSize,
  }) : super(key: key);

  @override
  State<IngredientTable> createState() => _IngredientTableState();
}

class _IngredientTableState extends State<IngredientTable> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final list = widget.items ?? [];
    if (list.isEmpty || widget.baseServings <= 0)
      return const SizedBox.shrink();

    /* ───────────── LayoutBuilder → scale จากความกว้างจริง ───────────── */
    return LayoutBuilder(builder: (context, box) {
      final boxW = box.maxWidth; // กว้างของคอนเทนเนอร์
      double clamp(double v, double min, double max) =>
          v < min ? min : (v > max ? max : v);

      /* ── responsive metrics ── */
      final baseFont = widget.fontSize ?? clamp(boxW * .045, 13, 18);
      final smallFont = baseFont - 1;
      final radius = clamp(boxW * .035, 10, 20);
      final pad = clamp(boxW * .035, 10, 20);
      final gap = clamp(boxW * .025, 6, 16);
      final borderW = clamp(boxW * .003, 0.8, 1.6);
      final arrowSz = baseFont + 3;

      /* ── factor ปรับจำนวนเสิร์ฟ ── */
      final scale = widget.currentServings / widget.baseServings;
      final showList =
          _expanded ? list : list.take(widget.previewCount).toList();

      /* ───────────────────────── UI ───────────────────────── */
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          /* กล่องตารางวัถุดิบ */
          Container(
            padding: EdgeInsets.all(pad),
            decoration: BoxDecoration(
              border:
                  Border.all(color: const Color(0xFFD8D8D8), width: borderW),
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Column(
              children: List.generate(showList.length, (i) {
                final item = showList[i];

                // คำนวณตามจำนวนเสิร์ฟจริง
                final qtyAdj = item.quantity * scale;
                final qtyStr = qtyAdj % 1 == 0
                    ? qtyAdj.toStringAsFixed(0)
                    : qtyAdj.toStringAsFixed(2);

                final isDisabled = !_expanded && i == showList.length - 1;
                final textColor =
                    isDisabled ? Colors.grey.shade400 : const Color(0xFF000000);

                final nameTxt =
                    item.description.isNotEmpty ? item.description : item.name;

                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /* ── ชื่อวัตถุดิบ (รองรับ 2 บรรทัด) ── */
                        Expanded(
                          flex: 3,
                          child: Text(
                            nameTxt,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: baseFont,
                              fontWeight: FontWeight.w500,
                              height: 1.32,
                              color: textColor,
                            ),
                          ),
                        ),
                        /* ── ปริมาณ + หน่วย (FittedBox กันล้น) ── */
                        Expanded(
                          flex: 1,
                          child: FittedBox(
                            alignment: Alignment.centerRight,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$qtyStr ${item.unit}',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: baseFont,
                                fontWeight: FontWeight.w700,
                                height: 1.32,
                                color: textColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (i < showList.length - 1) ...[
                      SizedBox(height: gap),
                      Divider(
                        color: const Color(0xFFD8D8D8),
                        thickness: borderW,
                        height: 0,
                      ),
                      SizedBox(height: gap),
                    ],
                  ],
                );
              }),
            ),
          ),

          /* ปุ่ม ดูเพิ่มเติม / ย่อ */
          if (list.length > widget.previewCount)
            TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.only(left: pad),
                minimumSize: const Size(double.infinity, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(
                _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: arrowSz,
                color: const Color(0xFFFF9B05),
              ),
              label: Text(
                _expanded ? 'ย่อขนาด' : 'ดูเพิ่มเติม',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: smallFont,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFFF9B05),
                ),
              ),
            ),
        ],
      );
    });
  }
}
