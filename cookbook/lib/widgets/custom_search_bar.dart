import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

import '../utils/debouncer.dart';
import '../services/api_service.dart';

enum _SearchMode { recipe, ingredient }

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
    if (token.isEmpty) return [];
    final list = _mode == _SearchMode.recipe
        ? await ApiService.getRecipeSuggestions(token)
        : await ApiService.getIngredientSuggestions(token);
    final prefix = _mode == _SearchMode.recipe ? '🍳 ' : '🥕 ';
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

  /* ───── UI ───── */
  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF9A28);
    final greyBorder = Colors.grey.shade400;

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
              onSubmitted: widget.onSubmitted,
              onChanged: (txt) {
                _debouncer.run(() => widget.onChanged(txt.trim()));
                setState(() {}); // update clear‑button
              },
              decoration: InputDecoration(
                hintText: _mode == _SearchMode.recipe
                    ? 'ค้นหาชื่อเมนู...'
                    : 'ค้นหาด้วยวัตถุดิบ...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: textController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _controller.clear();
                          widget.onChanged('');
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide: BorderSide(color: greyBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide: const BorderSide(color: orange, width: 1.4),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
            ),
            itemBuilder: (_, s) => ListTile(
              leading: Text(s.substring(0, 2),
                  style: Theme.of(context).textTheme.titleMedium),
              title: Text(s.substring(2).trim()),
              dense: true,
            ),
            onSelected: (s) =>
                _applySuggestion(_controller.text, s.substring(2).trim()),
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
                border: Border.all(color: greyBorder),
              ),
              child: IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'กรองผลการค้นหา',
                onPressed: widget.onFilterTap,
              ),
            ),
            if (widget.hasActiveFilter)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: orange,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),

        /// Mode toggle button
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _mode = _mode == _SearchMode.recipe
                  ? _SearchMode.ingredient
                  : _SearchMode.recipe;
            });
          },
          icon: Icon(
            _mode == _SearchMode.recipe ? Icons.search : Icons.spa,
            size: 18,
          ),
          label: Text(_mode == _SearchMode.recipe ? 'เมนู' : 'วัตถุดิบ'),
          style: OutlinedButton.styleFrom(
            foregroundColor:
                _mode == _SearchMode.recipe ? orange : Colors.grey.shade600,
            side: BorderSide(
                color: _mode == _SearchMode.recipe ? orange : greyBorder),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            textStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
