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

  const CustomSearchBar({
    super.key,
    required this.onChanged,
    this.onSubmitted,
    this.onFilterTap,
    this.hasActiveFilter = false,
  });

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  final _controller = TextEditingController();
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 600));
  _SearchMode _mode = _SearchMode.recipe;

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
          : raw.replaceFirst(RegExp(r'[^ ,;]+$'), pure) + ' ';
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

    String _hintText() {
      switch (_mode) {
        case _SearchMode.recipe:
          return 'ค้นหาชื่อเมนู...';
        case _SearchMode.ingredient:
          return 'ค้นหาด้วยวัตถุดิบ...';
        case _SearchMode.group:
          return 'ค้นหาด้วยกลุ่มวัตถุดิบ...';
      }
    }

    IconData _modeIcon() {
      switch (_mode) {
        case _SearchMode.recipe:
          return Icons.search;
        case _SearchMode.ingredient:
          return Icons.spa;
        case _SearchMode.group:
          return Icons.category_outlined;
      }
    }

    String _modeLabel() {
      switch (_mode) {
        case _SearchMode.recipe:
          return 'เมนู';
        case _SearchMode.ingredient:
          return 'วัตถุดิบ';
        case _SearchMode.group:
          return 'กลุ่ม';
      }
    }

    void _cycleMode() {
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
            builder: (context, textController, focusNode) => TextField(
              controller: textController,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (txt) {
                final t = txt.trim();
                if (t.isEmpty) return;
                widget.onSubmitted?.call(t);
              },
              onChanged: (txt) {
                _debouncer.run(() => widget.onChanged(txt.trim()));
                setState(() {}); // update clear-button
              },
              decoration: InputDecoration(
                hintText: _hintText(),
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
          label: 'สลับโหมดค้นหา: ${_modeLabel()}',
          child: OutlinedButton.icon(
            onPressed: _cycleMode,
            icon: Icon(
              _modeIcon(),
              size: 18,
              color: _mode == _SearchMode.recipe ? focusColor : iconColor,
            ),
            label: Text(_modeLabel()),
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
