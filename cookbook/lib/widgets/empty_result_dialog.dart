import 'package:flutter/material.dart';

/// Dialog แจ้งว่าไม่พบเมนูสำหรับวัตถุดิบที่ต้องการ
/// - แสดงไอคอน + หัวเรื่อง
/// - เนื้อความเน้นชื่อวัตถุดิบในประโยค (ไม่มีชิป/กรอบซ้ำ)
/// - ปุ่ม "ยกเลิก" / "ไปต่อ" สูงเท่ากัน (อาศัยธีมที่ตั้งไว้)
class EmptyResultDialog extends StatelessWidget {
  const EmptyResultDialog({
    super.key,
    required this.subject, // เช่น "กระจับ" หรือ "กุ้งทะเล"
    required this.onProceed, // callback เมื่อกด "ไปต่อ"
    this.caption, // ถ้าส่งมา จะใช้แทนข้อความมาตรฐาน
  });

  final String subject;
  final String? caption;
  final VoidCallback onProceed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ไอคอนสถานะ
            Icon(Icons.search_off_rounded, size: 44, color: cs.primary),
            const SizedBox(height: 8),

            // หัวเรื่อง
            Text(
              'ยังไม่มีสูตรเลยนะ',
              style: theme.textTheme.titleLarge?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),

            // เนื้อความ: เน้นชื่อวัตถุดิบในประโยคเดียว (ตัดชิปออก)
            caption != null
                ? Text(
                    caption!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  )
                : Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'ตอนนี้ยังไม่เจอเมนูที่ใช้ “'),
                        TextSpan(
                          text: subject,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(text: '”\nไปเปิดหน้าค้นหาเลยไหม?'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),

            const SizedBox(height: 20),

            // ปุ่มการกระทำ: ใช้ Expanded ให้กว้างเท่ากัน
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
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onProceed();
                    },
                    child: const Text('ไปต่อ'),
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
