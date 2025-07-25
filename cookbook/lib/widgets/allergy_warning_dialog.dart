import 'package:flutter/material.dart';
import '../models/recipe.dart';

typedef OnAllergyConfirmed = void Function(Recipe recipe);

class AllergyWarningDialog extends StatelessWidget {
  final Recipe recipe;
  final List<String> badIngredientNames;
  final OnAllergyConfirmed onConfirm;

  const AllergyWarningDialog({
    super.key,
    required this.recipe,
    required this.badIngredientNames,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    // 1. ลบ Manual Responsive Calculation และใช้ Theme
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    // ใช้ AlertDialog ซึ่งเป็น Widget มาตรฐานสำหรับการแจ้งเตือน
    return AlertDialog(
      // 2. กำหนด Style ของ Dialog ให้สอดคล้องกับ Theme
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.only(top: 24, bottom: 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),

      // --- Title ---
      title: Column(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 48,
            color: colorScheme.error,
          ),
          const SizedBox(height: 8),
          Text(
            'คำเตือน',
            style: textTheme.headlineSmall?.copyWith(color: colorScheme.error),
          ),
        ],
      ),

      // --- Content ---
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'เมนู “${recipe.name}”\nมีวัตถุดิบที่คุณอาจแพ้:',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            // 3. ปรับปรุง Chip/Badge ให้ใช้ Theme
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: badIngredientNames
                    .map((name) => Chip(
                          label: Text(name),
                          backgroundColor: colorScheme.errorContainer,
                          labelStyle: textTheme.labelLarge
                              ?.copyWith(color: colorScheme.onErrorContainer),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),

      // --- Actions (Buttons) ---
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ยกเลิก'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  // ไม่ต้อง pop ที่นี่ เพราะ onConfirm จะจัดการเอง
                  onConfirm(recipe);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                ),
                child: const Text('เปิดดูต่อไป'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
