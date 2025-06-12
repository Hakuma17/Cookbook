// lib/widgets/tag_list.dart

import 'package:flutter/material.dart';

/// TagList
/// แสดงชุดป้าย (tags) เป็นแนวนอนแบบ wrap
class TagList extends StatelessWidget {
  /// รายการชื่อป้าย
  final List<String>? tags;

  const TagList({
    Key? key,
    this.tags,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final list = tags ?? [];
    if (list.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 10.9067, // ตาม CSS gap:10.91px
        runSpacing: 4.36267, // vertical gap:4.36px
        children: list.map((tag) {
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10.9067, // ตาม CSS
              vertical: 4.36267, // ตาม CSS
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: const Color(0xFFFF9B05),
                width: 1.09067, // ตาม CSS
              ),
              borderRadius: BorderRadius.circular(13.088), // ตาม CSS
            ),
            child: Text(
              tag,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                height: 16 / 14, // line-height ≈16px
                color: Color(0xFFFF9B05),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
