// lib/widgets/choice_chip_filter.dart
// UPDATE SEARCH MOCKUP ❸ – choice-chip filter row

import 'package:flutter/material.dart';

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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(widget.options.length, (i) {
          final sel = i == _selected;
          final opt = widget.options[i];

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              label: Text(
                opt.label,
                style: TextStyle(
                  color: sel ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              selected: sel,
              selectedColor: const Color(0xFFFF9B05),
              backgroundColor: const Color(0xFFF2F2F2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
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
