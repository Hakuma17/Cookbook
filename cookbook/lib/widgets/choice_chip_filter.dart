import 'package:flutter/material.dart';

/// คลาสตัวเลือกการกรองหรือเรียงลำดับ ใช้ร่วมกับ ChoiceChipFilter
/// (ถ้ามีการประกาศ FilterOption ซ้ำในไฟล์อื่น เช่น search_screen.dart
///  เลือกเก็บไว้แค่ที่เดียวแล้ว import มาใช้ก็พอ เพื่อลด duplication) ★A
class FilterOption {
  final String label;
  final String key;
  const FilterOption(this.label, this.key);
}

/// โหมดการแสดงผลของ ChoiceChipFilter
/// - single: ชิปตัวเลือกแบบเลือกได้ครั้งละ 1 รายการ (เดิม)
/// - group: แสดงชิปกลุ่มวัตถุดิบ 2 กลุ่ม (ต้องมี / ไม่เอา) พร้อมปุ่มลบ
enum ChipFilterMode { single, group }

class ChoiceChipFilter extends StatefulWidget {
  /// ใช้ในโหมด single (เดิม)
  final List<FilterOption> options;
  final int initialIndex;
  final void Function(int index, String key)? onChanged;

  /// ใช้ในโหมด group (ใหม่)
  final ChipFilterMode mode;
  final List<String> includeGroups;
  final List<String> excludeGroups;
  final void Function(List<String> includeGroups, List<String> excludeGroups)?
      onGroupsChanged;
  final bool deletable;

  const ChoiceChipFilter({
    super.key,
    required this.options,
    this.initialIndex = 0,
    this.onChanged,
    this.mode = ChipFilterMode.single,
    this.includeGroups = const [],
    this.excludeGroups = const [],
    this.onGroupsChanged,
    this.deletable = true,
  });

  @override
  State<ChoiceChipFilter> createState() => _ChoiceChipFilterState();
}

class _ChoiceChipFilterState extends State<ChoiceChipFilter> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex
        .clamp(0, widget.options.isEmpty ? 0 : widget.options.length - 1);
  }

  // ทำให้ค่าจาก parent sync ลงชิปได้ตลอด (เฉพาะโหมด single)
  @override
  void didUpdateWidget(covariant ChoiceChipFilter oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.mode == ChipFilterMode.single) {
      // ถ้า parent เปลี่ยน initialIndex
      if (widget.initialIndex != oldWidget.initialIndex) {
        setState(() {
          _selectedIndex = widget.initialIndex
              .clamp(0, widget.options.isEmpty ? 0 : widget.options.length - 1);
        });
      }

      // ถ้า parent เปลี่ยนจำนวน options (เช่น ภาษาที่ต่างกัน) ★B
      if (widget.options.length != oldWidget.options.length &&
          _selectedIndex >= widget.options.length) {
        setState(() => _selectedIndex = 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == ChipFilterMode.group) {
      return _buildGroupMode(context);
    }

    // ── โหมด single (เดิม) ─────────────────────────────────────
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: List.generate(widget.options.length, _buildChipSingle),
      ),
    );
  }

  /* ---------- โหมด single: helper ---------- */

  Widget _buildChipSingle(int index) {
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
        backgroundColor:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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

  /* ---------- โหมด group: UI ---------- */

  Widget _buildGroupMode(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final include = List<String>.from(widget.includeGroups);
    final exclude = List<String>.from(widget.excludeGroups);

    if (include.isEmpty && exclude.isEmpty) {
      // ไม่มีชิปให้แสดง → คืนกล่องว่าง (ให้หน้าพ่อจัดการ empty state เอง)
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (include.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: include
                  .map((g) => _GroupChip(
                        text: g,
                        bg: cs.secondaryContainer,
                        fg: cs.onSecondaryContainer,
                        deletable: widget.deletable,
                        onDelete: widget.deletable
                            ? () {
                                final nextInclude = List<String>.from(include)
                                  ..remove(g);
                                widget.onGroupsChanged?.call(
                                  nextInclude,
                                  exclude,
                                );
                              }
                            : null,
                        semanticPrefix: 'ต้องมี(กลุ่ม) ',
                      ))
                  .toList(),
            ),
            const SizedBox(height: 6),
          ],
          if (exclude.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: exclude
                  .map((g) => _GroupChip(
                        text: g,
                        bg: cs.tertiaryContainer,
                        fg: cs.onTertiaryContainer,
                        deletable: widget.deletable,
                        onDelete: widget.deletable
                            ? () {
                                final nextExclude = List<String>.from(exclude)
                                  ..remove(g);
                                widget.onGroupsChanged?.call(
                                  include,
                                  nextExclude,
                                );
                              }
                            : null,
                        semanticPrefix: 'ไม่เอา(กลุ่ม) ',
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

/* ---------- โหมด group: ชิปเดี่ยว ---------- */
class _GroupChip extends StatelessWidget {
  const _GroupChip({
    required this.text,
    required this.bg,
    required this.fg,
    required this.deletable,
    this.onDelete,
    this.semanticPrefix = '',
  });

  final String text;
  final Color bg;
  final Color fg;
  final bool deletable;
  final VoidCallback? onDelete;
  final String semanticPrefix;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$semanticPrefix$text',
      button: deletable,
      child: Chip(
        label: Text(text),
        backgroundColor: bg,
        labelStyle: TextStyle(color: fg, fontWeight: FontWeight.w600),
        deleteIcon: deletable ? const Icon(Icons.close, size: 16) : null,
        onDeleted: deletable ? onDelete : null,
        side: BorderSide(color: fg.withValues(alpha: .35)),
      ),
    );
  }
}
