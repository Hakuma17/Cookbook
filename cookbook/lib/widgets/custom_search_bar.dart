// lib/widgets/custom_search_bar.dart
//
// CustomSearchBar — 2025-07-04  (multi-token fixed)
//
// – Autocomplete หลายคำ: คั่นได้ทั้ง space , ;
// – เลือกคำแนะนำแล้วจะ “แทรก/ต่อ” อย่างถูกต้อง  ไม่ลบคำก่อนหน้า
// – pill-toggle โหมด 🍳/🥕 + ปุ่มกรอง เหมือนเดิม
// ---------------------------------------------------------------------------

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

  /* ───── onSelected: แทรก/ต่อ อย่างถูกต้อง ───── */
  void _applySuggestion(String raw, String pure) {
    if (raw.isEmpty) {
      _controller.text = '$pure ';
    } else {
      final last = raw[raw.length - 1];
      final isDelim = RegExp(r'[ ,;]').hasMatch(last);

      if (isDelim) {
        // เพิ่งกดเว้นวรรค/คอมม่า → ต่อท้าย
        _controller.text = '$raw$pure ';
      } else {
        // ยังพิมพ์ค้างอยู่ → แทน token สุดท้าย
        _controller.text = raw.replaceFirst(RegExp(r'[^ ,;]+$'), pure) + ' ';
      }
    }

    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
    final trimmed = _controller.text.trim();
    widget.onChanged(trimmed);
    widget.onSubmitted?.call(trimmed);
  }

  /* ───── UI ───── */
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          /* search + autocomplete */
          Expanded(
            child: TypeAheadField<String>(
              controller: _controller,
              suggestionsCallback: _suggest,
              debounceDuration: const Duration(milliseconds: 250),
              hideOnEmpty: true,
              hideOnError: true,
              hideOnLoading: true,
              offset: const Offset(0, 6),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              builder: (context, ctrl, focus) => TextField(
                controller: ctrl,
                focusNode: focus,
                textInputAction: TextInputAction.search,
                onSubmitted: widget.onSubmitted,
                onChanged: (txt) {
                  _debouncer.run(() => widget.onChanged(txt.trim()));
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: _mode == _Mode.recipe
                      ? 'ค้นหาชื่อเมนู...'
                      : 'ค้นหาวัตถุดิบ...',
                  prefixIcon:
                      const Icon(Icons.search, color: Color(0xFF959595)),
                  suffixIcon: ctrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close,
                              size: 20, color: Color(0xFF959595)),
                          onPressed: () {
                            _controller.clear();
                            widget.onChanged('');
                            setState(() {});
                          },
                        )
                      : null,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 18, horizontal: 0),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:
                        const BorderSide(color: Color(0xFFE1E1E1), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:
                        const BorderSide(color: Color(0xFFFF9B05), width: 2),
                  ),
                ),
              ),
              decorationBuilder: (context, child) => Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: child,
              ),
              itemBuilder: (_, s) => ListTile(
                dense: true,
                leading: Text(s.substring(0, 2)),
                title: Text(s.substring(2).trim()),
              ),
              onSelected: (s) {
                final pure = s.substring(2).trim();
                _applySuggestion(_controller.text, pure);
              },
            ),
          ),
          const SizedBox(width: 8),

          /* filter button */
          InkWell(
            onTap: widget.onFilterTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE1E1E1)),
                color: Colors.white,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.tune, size: 22, color: Color(0xFF4D4D4D)),
                  if (widget.hasActiveFilter)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF9B05),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),

          /* pill toggle */
          GestureDetector(
            onTap: () => setState(() {
              _mode = _mode == _Mode.recipe ? _Mode.ingredient : _Mode.recipe;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _mode == _Mode.recipe
                    ? const Color(0xFFFFEBDA)
                    : const Color(0xFFE9F9EB),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _mode == _Mode.recipe
                      ? const Color(0xFFFF9B05)
                      : const Color(0xFF55B85E),
                ),
              ),
              child: Row(
                children: [
                  Text(_mode == _Mode.recipe ? '🍳' : '🥕',
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Text(
                    _mode == _Mode.recipe ? 'เมนู' : 'วัตถุดิบ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
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
