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
    // ✅ 1. ลบ Manual Responsive Calculation และใช้ Theme
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    // ✅ 2. ใช้ Material -> InkWell -> Container เพื่อสร้างปุ่มที่สวยงามและตอบสนอง
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Material(
        // ใช้สีและ shape จาก Theme ของ Card
        color: theme.cardTheme.color ?? colorScheme.surface,
        shape: theme.cardTheme.shape ??
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28.0), // ทำให้เป็นทรงแคปซูล
            ),
        clipBehavior: Clip.antiAlias, // ทำให้ InkWell อยู่ในขอบเขตของ shape
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 52, // กำหนดความสูงคงที่
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            // ✅ 3. ใช้สีเส้นขอบและสไตล์จาก Theme
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outline.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(28.0),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: colorScheme.onSurfaceVariant, // สีไอคอนที่เหมาะสม
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant, // สีข้อความที่เหมาะสม
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
