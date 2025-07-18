//
// CustomSearchBar (responsive) — 2025-07-10
//
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../utils/debouncer.dart';
import '../services/api_service.dart';

enum _Mode { recipe, ingredient }

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
  _Mode _mode = _Mode.recipe;

  /* ───── helper: token สุดท้าย ───── */
  final _splitter = RegExp(r'[ ,;]+');
  String _lastToken(String raw) {
    final parts = raw.split(_splitter).where((e) => e.trim().isNotEmpty);
    return parts.isEmpty ? '' : parts.last.trim();
  }

  /* ───── suggestions ───── */
  Future<List<String>> _suggest(String raw) async {
    final token = _lastToken(raw);
    if (token.isEmpty) return [];
    final list = _mode == _Mode.recipe
        ? await ApiService.getRecipeSuggestions(token)
        : await ApiService.getIngredientSuggestions(token);
    final prefix = _mode == _Mode.recipe ? '🍳 ' : '🥕 ';
    return list.take(10).map((e) => '$prefix$e').toList();
  }

  /* ───── onSelected: แทรก/ต่อ token ───── */
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

  /* ───── UI ───── */
  @override
  Widget build(BuildContext context) {
    /* responsive numbers */
    final w = MediaQuery.of(context).size.width;
    double clamp(double v, double min, double max) =>
        v < min ? min : (v > max ? max : v);

    final barH = clamp(w * 0.15, 52, 72); // ความสูง search-bar
    final rad = clamp(w * 0.06, 20, 28); // รัศมีกล่อง search
    final hintF = clamp(w * 0.037, 13, 16); // ฟอนต์ hint
    final iconSz = clamp(w * 0.06, 20, 24); // ไอคอน search / close
    final filterDim = clamp(w * 0.12, 40, 48); // Ø ปุ่ม filter
    final pillPadH = clamp(w * 0.03, 8, 14); // padding pill แนวนอน
    final pillPadV = clamp(w * 0.017, 5, 8); // padding pill แนวตั้ง
    final pillF = clamp(w * 0.035, 12, 14); // ฟอนต์ pill
    final listH = MediaQuery.of(context).size.height * 0.4; // suggestion max

    return Padding(
      padding: EdgeInsets.fromLTRB(pillPadH * 1.3, 8, pillPadH * 1.3, 12),
      child: Row(
        children: [
          /* ── search field + autocomplete ── */
          Expanded(
            child: TypeAheadField<String>(
              controller: _controller,
              suggestionsCallback: _suggest,
              debounceDuration: const Duration(milliseconds: 250),
              hideOnEmpty: true,
              hideOnError: true,
              hideOnLoading: true,
              offset: const Offset(0, 6),
              constraints: BoxConstraints(maxHeight: listH),
              builder: (context, ctrl, focus) => TextField(
                controller: ctrl,
                focusNode: focus,
                textInputAction: TextInputAction.search,
                onSubmitted: widget.onSubmitted,
                onChanged: (txt) {
                  _debouncer.run(() => widget.onChanged(txt.trim()));
                  setState(() {}); // เพื่อโชว์/ซ่อนปุ่ม clear
                },
                style: TextStyle(fontSize: hintF),
                decoration: InputDecoration(
                  hintText: _mode == _Mode.recipe
                      ? 'ค้นหาชื่อเมนู...'
                      : 'ค้นหาวัตถุดิบ...',
                  hintStyle: TextStyle(fontSize: hintF),
                  prefixIcon: Icon(Icons.search,
                      size: iconSz, color: const Color(0xFF959595)),
                  suffixIcon: ctrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close,
                              size: iconSz, color: const Color(0xFF959595)),
                          onPressed: () {
                            _controller.clear();
                            widget.onChanged('');
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(
                      vertical: (barH - iconSz) / 3, horizontal: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(rad),
                    borderSide:
                        const BorderSide(color: Color(0xFFE1E1E1), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(rad),
                    borderSide:
                        const BorderSide(color: Color(0xFFFF9B05), width: 2),
                  ),
                ),
              ),
              decorationBuilder: (context, child) => Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(rad * 0.6),
                child: child,
              ),
              itemBuilder: (_, s) => ListTile(
                dense: true,
                leading:
                    Text(s.substring(0, 2), style: TextStyle(fontSize: pillF)),
                title: Text(s.substring(2).trim(),
                    style: TextStyle(fontSize: pillF)),
              ),
              onSelected: (s) =>
                  _applySuggestion(_controller.text, s.substring(2).trim()),
            ),
          ),
          SizedBox(width: pillPadH / 2),

          /* ── filter button ── */
          InkWell(
            onTap: widget.onFilterTap,
            borderRadius: BorderRadius.circular(filterDim / 2),
            child: Container(
              width: filterDim,
              height: filterDim,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE1E1E1)),
                color: Colors.white,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.tune,
                      size: iconSz * 0.85, color: const Color(0xFF4D4D4D)),
                  if (widget.hasActiveFilter)
                    Positioned(
                      top: filterDim * 0.23,
                      right: filterDim * 0.23,
                      child: Container(
                        width: filterDim * 0.18,
                        height: filterDim * 0.18,
                        decoration: const BoxDecoration(
                            color: Color(0xFFFF9B05), shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(width: pillPadH / 3),

          /* ── pill-toggle ── */
          GestureDetector(
            onTap: () => setState(() {
              _mode = _mode == _Mode.recipe ? _Mode.ingredient : _Mode.recipe;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(
                  horizontal: pillPadH, vertical: pillPadV),
              decoration: BoxDecoration(
                color: _mode == _Mode.recipe
                    ? const Color(0xFFFFEBDA)
                    : const Color(0xFFE9F9EB),
                borderRadius: BorderRadius.circular(rad),
                border: Border.all(
                  color: _mode == _Mode.recipe
                      ? const Color(0xFFFF9B05)
                      : const Color(0xFF55B85E),
                ),
              ),
              child: Row(
                children: [
                  Text(_mode == _Mode.recipe ? '🍳' : '🥕',
                      style: TextStyle(fontSize: pillF + 3)),
                  SizedBox(width: pillPadH / 4),
                  Text(
                    _mode == _Mode.recipe ? 'เมนู' : 'วัตถุดิบ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: pillF,
                      color: _mode == _Mode.recipe
                          ? const Color(0xFFFF9B05)
                          : const Color(0xFF55B85E),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
