import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/recipe.dart';

/// ------------------------------------------------------------
/// 1) ConfirmRemoveDialog – ไดอาล็อกยืนยันลบ (เช่น ลบจากตะกร้า/รายการโปรด)
///    ใช้สี error ของธีม + ปุ่มชัดเจน
/// ------------------------------------------------------------
class ConfirmRemoveDialog extends StatelessWidget {
  final String title; // เช่น 'ยืนยันลบเมนู'
  final String message; // เช่น 'ต้องการลบ "แกงมัสมั่นไก่" ออกจากตะกร้าใช่ไหม?'
  final String cancelText; // 'ยกเลิก'
  final String confirmText; // 'ลบ'
  final IconData icon; // Icons.delete_forever_rounded

  const ConfirmRemoveDialog({
    super.key,
    required this.title,
    required this.message,
    this.cancelText = 'ยกเลิก',
    this.confirmText = 'ลบ',
    this.icon = Icons.delete_forever_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon ในแผ่นสี errorContainer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: cs.onErrorContainer),
            ),
            const SizedBox(height: 14),
            Text(title,
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(cancelText),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.error,
                      foregroundColor: cs.onError,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context, true);
                    },
                    child: Text(confirmText),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper เรียกง่าย ๆ
Future<bool?> showConfirmRemoveDialog(
  BuildContext context, {
  required String recipeName,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => ConfirmRemoveDialog(
      title: 'ยืนยันลบเมนู',
      message: 'ต้องการลบ "$recipeName" ออกจากรายการใช่ไหม?',
    ),
  );
}

/// ------------------------------------------------------------
/// 2) AllergyWarningDialog – เตือนวัตถุดิบที่แพ้ (API เดิม)
///    ใช้งานแทนของเดิมได้เลย: รับ recipe + รายชื่อส่วนผสมอันตราย
/// ------------------------------------------------------------
class AllergyWarningDialog extends StatelessWidget {
  final Recipe recipe;
  final List<String> badIngredientNames;
  final ValueChanged<Recipe> onConfirm;

  const AllergyWarningDialog({
    super.key,
    required this.recipe,
    required this.badIngredientNames,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // สัญลักษณ์เตือน
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_amber_rounded,
                  size: 28, color: cs.onErrorContainer),
            ),
            const SizedBox(height: 12),
            Text('คำเตือน',
                style: tt.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold, color: cs.error)),
            const SizedBox(height: 4),
            Text(
              'เมนู “${recipe.name}” มีวัตถุดิบที่คุณอาจแพ้:',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),

            // รายการวัตถุดิบแบบชิป
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: badIngredientNames.map((n) {
                    return Chip(
                      label: Text(n),
                      side: BorderSide(color: cs.error.withOpacity(.5)),
                      backgroundColor: cs.errorContainer.withOpacity(.45),
                      labelStyle: tt.labelMedium?.copyWith(color: cs.error),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 16),
            // ปุ่ม
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ยกเลิก'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                      onConfirm(recipe);
                    },
                    child: const Text('เปิดดูต่อไป'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
