// lib/widgets/custom_search_bar.dart

import 'package:flutter/material.dart';
import '../utils/debouncer.dart';

class CustomSearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onFilterTap;

  /// เมื่อมี active-filter จะขึ้นจุดส้มบนปุ่ม filter
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

  @override
  void dispose() {
    _debouncer.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onClear() {
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          // ── search box ───────────────────────────────────────
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: widget.onSubmitted,
              onChanged: (txt) => _debouncer.run(() => widget.onChanged(txt)),
              decoration: InputDecoration(
                hintText: 'คุณอยากทำอะไรในวันนี้?',
                hintStyle: const TextStyle(fontSize: 16, color: Colors.grey),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 18, horizontal: 0),
                prefixIcon: const Icon(Icons.search,
                    color: Color(0xFF959595), size: 26),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close,
                            color: Color(0xFF959595), size: 20),
                        onPressed: _onClear,
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
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
          ),
          const SizedBox(width: 10),
          // ── filter icon ──────────────────────────────────────
          InkWell(
            onTap: widget.onFilterTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE1E1E1)),
                color: Colors.white,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.tune, color: Color(0xFF4D4D4D)),
                  if (widget.hasActiveFilter) // badge ส้ม
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFF9B05),
                        ),
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
