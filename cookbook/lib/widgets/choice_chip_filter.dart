import 'package:flutter/material.dart';

/// คลาสตัวเลือกการกรองหรือเรียงลำดับ ใช้ร่วมกับ ChoiceChipFilter
/// (ถ้ามีการประกาศ FilterOption ซ้ำในไฟล์อื่น เช่น search_screen.dart
///  เลือกเก็บไว้แค่ที่เดียวแล้ว import มาใช้ก็พอ เพื่อลด duplication) ★A
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
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, widget.options.length - 1);
  }

  // ทำให้ค่าจาก parent sync ลงชิปได้ตลอด
  @override
  void didUpdateWidget(covariant ChoiceChipFilter oldWidget) {
    super.didUpdateWidget(oldWidget);

    // ถ้า parent เปลี่ยน initialIndex
    if (widget.initialIndex != oldWidget.initialIndex) {
      setState(() {
        _selectedIndex =
            widget.initialIndex.clamp(0, widget.options.length - 1);
      });
    }

    // ถ้า parent เปลี่ยนจำนวน options (เช่น ภาษาที่ต่างกัน) ★B
    if (widget.options.length != oldWidget.options.length &&
        _selectedIndex >= widget.options.length) {
      setState(() => _selectedIndex = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // 🔸 ถ้าชิปเยอะมาก ๆ บนจอใหญ่ อาจเปลี่ยนจาก Row → Wrap
    //     ให้ชิปขึ้นบรรทัดใหม่ได้ (เปิดคอมเมนต์ถ้าต้องการ) ★C
    //
    // return Wrap(
    //   spacing: 8,
    //   runSpacing: 4,
    //   children: List.generate(widget.options.length, _buildChip),
    // );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: List.generate(widget.options.length, _buildChip),
      ),
    );
  }

  /* ---------- helper ---------- */

  Widget _buildChip(int index) {
    final option = widget.options[index];
    final isSelected = index == _selectedIndex;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(option.label),
        labelStyle: textTheme.labelLarge?.copyWith(
          color: isSelected
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        ),
        selected: isSelected,
        selectedColor: theme.colorScheme.primary,
        backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        shape: const StadiumBorder(),
        onSelected: (selected) {
          if (selected) {
            setState(() => _selectedIndex = index);
            widget.onChanged?.call(index, option.key);
          }
        },
      ),
    );
  }
}
