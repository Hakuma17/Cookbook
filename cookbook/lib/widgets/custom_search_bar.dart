import 'package:flutter/material.dart';
import '../utils/debouncer.dart';

class CustomSearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  const CustomSearchBar({
    Key? key,
    required this.onChanged,
    this.onSubmitted,
  }) : super(key: key);

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  final _controller = TextEditingController();
  final _debouncer = Debouncer(delay: Duration(milliseconds: 800));

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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'คุณอยากทำอะไรในวันนี้?',
                hintStyle: const TextStyle(fontSize: 16, color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: _onClear,
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xFFFF9B05), width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (text) => _debouncer.run(() => widget.onChanged(text)),
              onSubmitted: widget.onSubmitted,
              textInputAction: TextInputAction.search,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFBDBDBD)),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.tune, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
