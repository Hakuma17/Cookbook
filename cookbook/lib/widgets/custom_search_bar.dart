import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

import '../utils/debouncer.dart';
import '../services/api_service.dart';

enum _SearchMode { recipe, ingredient, group }

class CustomSearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onFilterTap;
  final bool hasActiveFilter;
  final String? initialText; // ข้อความเริ่มต้น (คงไว้หลังค้นหา/เลือกคำแนะนำ)

  const CustomSearchBar({
    super.key,
    required this.onChanged,
    this.onSubmitted,
    this.onFilterTap,
    this.hasActiveFilter = false,
    this.initialText,
  });

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  final _controller = TextEditingController();
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 600));
  _SearchMode _mode = _SearchMode.recipe;

  @override
  void initState() {
    super.initState();
    // เซ็ตค่าข้อความเริ่มต้น ถ้ามี
    final init = widget.initialText?.trim();
    if (init != null && init.isNotEmpty) {
      _controller.text = init;
      _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length));
    }
  }

  @override
  void didUpdateWidget(covariant CustomSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ถ้าข้อความจากพาเรนต์เปลี่ยน ให้สะท้อนใน controller (ไม่รบกวนการพิมพ์)
    final next = widget.initialText?.trim() ?? '';
    if (next != (_controller.text)) {
      _controller.text = next;
      _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length));
    }
  }

  /* ─────  suggestion helpers  ───── */
  final _splitter = RegExp(r'[ ,;]+');
  String _lastToken(String raw) {
    final parts = raw.split(_splitter).where((e) => e.trim().isNotEmpty);
    return parts.isEmpty ? '' : parts.last.trim();
  }

  Future<List<String>> _suggest(String raw) async {
    final token = _lastToken(raw);
    // จำกัดความยาวขั้นต่ำของ token เพื่อลดภาระ/ไม่กวนผู้ใช้
    if (token.isEmpty || token.length < 2) return [];

    List<String> list;
    String prefix;

    switch (_mode) {
      case _SearchMode.recipe:
        list = await ApiService.getRecipeSuggestions(token);
        prefix = '🍳 ';
        break;
      case _SearchMode.ingredient:
        list = await ApiService.getIngredientSuggestions(token);
        prefix = '🥕 ';
        break;
      case _SearchMode.group:
        // ★ โหมดกลุ่ม: เรียก suggestGroups() จาก backend
        list = await ApiService.getGroupSuggestions(token);
        // เลือกอีโมจิที่ความยาว UTF-16 = 2 เพื่อไม่พังกับ substring(0,2)
        prefix = '📁 ';
        break;
    }

    return list.take(10).map((e) => '$prefix$e').toList();
  }

  void _applySuggestion(String raw, String pure) {
    if (raw.isEmpty) {
      _controller.text = '$pure ';
    } else {
      final last = raw[raw.length - 1];
      final isDelim = RegExp(r'[ ,;]').hasMatch(last);
      _controller.text = isDelim
          ? '$raw$pure '
          : '${raw.replaceFirst(RegExp(r'[^ ,;]+$'), pure)} ';
    }
    _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length));

    final trimmed = _controller.text.trim();
    widget.onChanged(trimmed);
    widget.onSubmitted?.call(trimmed);
  }

  // ทำความสะอาดทรัพยากร
  @override
  void dispose() {
    _controller.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  /* ───── UI ───── */
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final fillColor = cs.surfaceContainerHighest;
    final borderColor = cs.outlineVariant;
    final focusColor = cs.primary;
    final iconColor = cs.onSurfaceVariant;

    // เปลี่ยนชื่อ local function ไม่ให้ขึ้นต้นด้วย _ (หลีกเลี่ยง lint no_leading_underscores_for_local_identifiers)
    String hintTextLocal() {
      switch (_mode) {
        case _SearchMode.recipe:
          return 'ค้นหาชื่อเมนู...';
        case _SearchMode.ingredient:
          return 'ค้นหาด้วยวัตถุดิบ...';
        case _SearchMode.group:
          return 'ค้นหาด้วยกลุ่มวัตถุดิบ...';
      }
    }

    IconData modeIconLocal() {
      switch (_mode) {
        case _SearchMode.recipe:
          return Icons.search;
        case _SearchMode.ingredient:
          return Icons.spa;
        case _SearchMode.group:
          return Icons.category_outlined;
      }
    }

    String modeLabelLocal() {
      switch (_mode) {
        case _SearchMode.recipe:
          return 'เมนู';
        case _SearchMode.ingredient:
          return 'วัตถุดิบ';
        case _SearchMode.group:
          return 'กลุ่ม';
      }
    }

    void cycleModeLocal() {
      setState(() {
        if (_mode == _SearchMode.recipe) {
          _mode = _SearchMode.ingredient;
        } else if (_mode == _SearchMode.ingredient) {
          _mode = _SearchMode.group;
        } else {
          _mode = _SearchMode.recipe;
        }
      });
    }

    return Row(
      children: [
        /// Search Field
        Expanded(
          child: TypeAheadField<String>(
            controller: _controller,
            suggestionsCallback: _suggest,
            debounceDuration: const Duration(milliseconds: 250),
            emptyBuilder: (context) => Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text(
                  'ไม่พบคำแนะนำ',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
            builder: (context, textController, focusNode) => TextField(
              controller: textController,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (txt) {
                final t = txt.trim();
                if (t.isEmpty) return;
                widget.onSubmitted?.call(t);
                // ไม่ล้างข้อความหลังค้นหา คงไว้ให้แก้ได้ต่อ
                textController.selection = TextSelection.fromPosition(
                    TextPosition(offset: textController.text.length));
              },
              onChanged: (txt) {
                _debouncer.run(() => widget.onChanged(txt.trim()));
                setState(() {}); // update clear-button
              },
              decoration: InputDecoration(
                hintText: hintTextLocal(),
                prefixIcon: Icon(Icons.search, color: iconColor),
                suffixIcon: textController.text.isNotEmpty
                    ? Semantics(
                        button: true,
                        label: 'ล้างคำค้นหา',
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'ล้างคำค้นหา',
                          onPressed: () {
                            _controller.clear();
                            widget.onChanged('');
                            setState(() {});
                          },
                        ),
                      )
                    : null,
                filled: true,
                fillColor: fillColor,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide: BorderSide(color: focusColor, width: 1.4),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
            ),
            itemBuilder: (_, s) => ListTile(
              leading: Text(
                // คาดหวัง prefix แบบ 2 UTF-16 units (อีโมจิ) ตามที่ประกอบไว้ด้านบน
                s.substring(0, 2),
                style: theme.textTheme.titleMedium,
              ),
              // แสดงส่วนข้อความ (หลัง prefix) โดยไม่ต้องห่อด้วย interpolation
              title: Text(s.substring(2).trim()),
              dense: true,
            ),
            onSelected: (s) => _applySuggestion(
              _controller.text,
              s.substring(2).trim(),
            ),
          ),
        ),
        const SizedBox(width: 8),

        /// Filter Button + badge
        Stack(
          alignment: Alignment.topRight,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor),
              ),
              child: Semantics(
                button: true,
                label: 'กรองผลการค้นหา',
                child: IconButton(
                  icon: Icon(Icons.tune, color: iconColor),
                  tooltip: 'กรองผลการค้นหา',
                  onPressed: widget.onFilterTap,
                ),
              ),
            ),
            if (widget.hasActiveFilter)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: focusColor, // ใช้สี primary เป็น badge
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),

        /// Mode toggle button (วนลูป เมนู → วัตถุดิบ → กลุ่ม)
        Semantics(
          button: true,
          toggled: _mode != _SearchMode.recipe,
          label: 'สลับโหมดค้นหา: ${modeLabelLocal()}',
          child: OutlinedButton.icon(
            onPressed: cycleModeLocal,
            icon: Icon(
              modeIconLocal(),
              size: 18,
              color: _mode == _SearchMode.recipe ? focusColor : iconColor,
            ),
            label: Text(modeLabelLocal()),
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  _mode == _SearchMode.recipe ? focusColor : iconColor,
              side: BorderSide(
                color: _mode == _SearchMode.recipe ? focusColor : borderColor,
              ),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
