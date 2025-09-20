import 'package:flutter/material.dart';

/// กล่องกดเพื่อแสดงความคิดเห็น / แก้ไข
class CommentInputField extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const CommentInputField({
    super.key,
    required this.onTap,
    this.label = 'แสดงความคิดเห็นของคุณ...',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Material(
        // สี/ทรง ให้ไปตาม CardTheme ถ้ามี
        color: theme.cardTheme.color ?? colorScheme.surface,
        surfaceTintColor:
            theme.cardTheme.surfaceTintColor ?? Colors.transparent,
        shape: theme.cardTheme.shape ??
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28.0), // ทรงแคปซูล
            ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28.0),
          child: Container(
            // เดิมเป็น height: 52 → ใช้ minHeight เพื่อกันล้นแนวตั้ง
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            decoration: BoxDecoration(
              border:
                  Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(28.0),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                // ⬇️ ป้องกันล้นขอบขวา
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textWidthBasis: TextWidthBasis.parent,
                    style:
                        (textTheme.bodyLarge ?? const TextStyle(fontSize: 16))
                            .copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.2, // ให้แน่นขึ้นเล็กน้อย
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
