import 'package:flutter/material.dart';
import '../models/ingredient_quantity.dart';

/// IngredientTable
/// - previewCount: จำนวนแถวที่จะโชว์เมื่อยังปิด (default = 5)
/// - activeCount: ไม่ใช้แล้ว (เพราะ blur แค่แถวสุดท้าย)
class IngredientTable extends StatefulWidget {
  final List<IngredientQuantity>? items;
  final int previewCount;

  const IngredientTable({
    Key? key,
    this.items,
    this.previewCount = 5,
  }) : super(key: key);

  @override
  State<IngredientTable> createState() => _IngredientTableState();
}

class _IngredientTableState extends State<IngredientTable> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final list = widget.items ?? [];
    if (list.isEmpty) return const SizedBox.shrink();

    // เลือกแสดงทั้งหมดถ้า expand แล้ว มิฉะนั้น previewCount แรก
    final displayList =
        _expanded ? list : list.take(widget.previewCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD8D8D8), width: 1.09),
            borderRadius: BorderRadius.circular(13.088),
          ),
          padding: const EdgeInsets.all(13.088),
          child: Column(
            children: List.generate(displayList.length, (i) {
              final item = displayList[i];
              final qty = item.quantity % 1 == 0
                  ? item.quantity.toStringAsFixed(0)
                  : item.quantity.toStringAsFixed(2);

              // blur เฉพาะรายการสุดท้าย เมื่อยังไม่ expand
              final isDisabled = !_expanded && i == displayList.length - 1;
              final textColor =
                  isDisabled ? Colors.grey.shade400 : const Color(0xFF000000);

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 24 / 15,
                            color: textColor,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '$qty ${item.unit}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 24 / 15,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (i < displayList.length - 1) ...[
                    const SizedBox(height: 8.73),
                    const Divider(
                      color: Color(0xFFD8D8D8),
                      thickness: 1.09067,
                    ),
                    const SizedBox(height: 8.73),
                  ],
                ],
              );
            }),
          ),
        ),
        if (list.length > widget.previewCount)
          TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(
              _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 17.45,
              color: const Color(0xFFFF9B05),
            ),
            label: Text(
              _expanded ? 'ย่อขนาด' : 'ดูเพิ่มเติม',
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 24 / 14,
                color: Color(0xFFFF9B05),
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.only(left: 16),
              minimumSize: const Size(double.infinity, 24),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: Alignment.centerLeft,
            ),
          ),
      ],
    );
  }
}
