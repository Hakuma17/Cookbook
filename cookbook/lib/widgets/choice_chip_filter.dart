// lib/widgets/choice_chip_filter.dart
// UPDATE SEARCH MOCKUP ❸ – choice-chip filter row (responsive)

import 'package:flutter/material.dart';

/// คลาสตัวเลือกการกรองหรือเรียงลำดับ ใช้ร่วมกับ ChoiceChipFilter
class FilterOption {
  final String label;
  final String key;
  const FilterOption(this.label, this.key);
}

class ChoiceChipFilter extends StatefulWidget {
  final List<FilterOption> options;
  final int initialIndex;
  final void Function(int index, String key)? onChanged;

  const ChoiceChipFilter({
    super.key,
    required this.options,
    this.initialIndex = 0,
    this.onChanged,
  });

  @override
  State<ChoiceChipFilter> createState() => _ChoiceChipFilterState();
}

class _ChoiceChipFilterState extends State<ChoiceChipFilter> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialIndex.clamp(0, widget.options.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    /* ── responsive metrics ── */
    final w = MediaQuery.of(context).size.width;
    double clamp(double v, double min, double max) =>
        v < min ? min : (v > max ? max : v);

    final fontF = clamp(w * 0.038, 13, 16); // ฟอนต์บนชิป
    final padHChip = clamp(w * 0.038, 10, 16); // horiz padding chip
    final padVChip = clamp(w * 0.022, 6, 10); // vert  padding chip
    final radius = clamp(w * 0.06, 18, 28); // radius chip
    final listPad = clamp(w * 0.042, 12, 20); // padding รายการชิป
    final gap = clamp(w * 0.032, 8, 14); // ระยะระหว่างชิป

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding:
          EdgeInsets.symmetric(horizontal: listPad, vertical: listPad * 0.5),
      child: Row(
        children: List.generate(widget.options.length, (i) {
          final sel = i == _selected;
          final opt = widget.options[i];

          return Padding(
            padding: EdgeInsets.only(
                right: i == widget.options.length - 1 ? 0 : gap),
            child: ChoiceChip(
              label: Text(
                opt.label,
                style: TextStyle(
                  color: sel ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: fontF,
                ),
              ),
              labelPadding: EdgeInsets.symmetric(
                  horizontal: padHChip, vertical: padVChip),
              selected: sel,
              selectedColor: const Color(0xFFFF9B05),
              backgroundColor: const Color(0xFFF2F2F2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
              ),
              onSelected: (_) {
                if (sel) return;
                setState(() => _selected = i);
                widget.onChanged?.call(i, opt.key);
              },
            ),
          );
        }),
      ),
    );
  }
}
