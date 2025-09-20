// lib/widgets/nutrition_summary.dart
// ------------------------------------------------------------
// Style ปัจจุบัน: "ตารางแถบ" เหมือนวัตถุดิบเป๊ะ
// - กล่องมีขอบโค้ง
// - แถวซ้าย=ชื่อ ขวา=ค่า
// - Divider คั่นระหว่างแถว
// - ใช้ฟอนต์ titleMedium น้ำหนัก w400 (เหมือน IngredientTable)
// - รูปแบบตัวเลขแบบ K ตั้งแต่หลักพัน (2.1K, 22.5K)
// - FIX: _trimZeros ใช้ replaceFirstMapped (แก้บั๊ก 93\1)
// ------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // ★ Added: ใช้คั่นหลักพันแบบไทย
import '../models/nutrition.dart';

/*──────────────── helper ───────────────*/
class _NutItem {
  final String label;
  final double value;
  final String unit; // 'kcal' หรือ 'g'  ★ Changed: เดิมคอมเมนต์ระบุ 'Kal'
  const _NutItem(this.label, this.value, this.unit);
}

/*───────── CURRENT number formatting ─────────*/
// แสดง K ตั้งแต่หลักพัน (เช่น 2.1K, 22.5K)
// ★ Changed: เปลี่ยนเป็นคั่นหลักพันด้วย NumberFormat (เลิกใช้ K)
final NumberFormat _nTh = NumberFormat.decimalPattern('th_TH');

String _fmtNut(double n) {
  final x = n.abs();
  if (x >= 1000)
    return _nTh
        .format(n.round()); // หลักพันขึ้นไปปัดเป็นจำนวนเต็ม + คั่นหลักพัน
  if (x >= 100) return _trimZeros(n.toStringAsFixed(0));
  if (x >= 10) return _trimZeros(n.toStringAsFixed(1));
  if (x >= 1) return _trimZeros(n.toStringAsFixed(1));
  return _trimZeros(n.toStringAsFixed(2));
}

// ตัดศูนย์ทศนิยมเกินจำเป็น (2.10 -> 2.1, 2.0 -> 2)
String _trimZeros(String s) {
  if (!s.contains('.')) return s;
  s = s.replaceFirstMapped(RegExp(r'([.]\d*?)0+$'), (m) => m.group(1)!);
  s = s.replaceFirst(RegExp(r'[.]$'), '');
  return s;
}

/*──────────────── widget ───────────────*/
class NutritionSummary extends StatelessWidget {
  final Nutrition? nutrition;
  final int baseServings;
  final int currentServings;

  const NutritionSummary({
    super.key,
    this.nutrition,
    required this.baseServings,
    required this.currentServings,
  });

  @override
  Widget build(BuildContext context) {
    if (nutrition == null || baseServings <= 0) {
      return const SizedBox.shrink();
    }

    final ratio = currentServings / baseServings;
    final items = <_NutItem>[
      _NutItem('แคลอรี่', nutrition!.calories * ratio,
          'kcal'), // ★ Changed: Kal → kcal
      _NutItem('ไขมัน', nutrition!.fat * ratio, 'g'),
      _NutItem('โปรตีน', nutrition!.protein * ratio, 'g'),
      _NutItem('คาร์โบไฮเดรต', nutrition!.carbs * ratio, 'g'),
    ];

    final theme = Theme.of(context);

    // ★★ สไตล์เดียวกับ IngredientTable ★★
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _buildRow(context, items[i]),
            if (i < items.length - 1) const Divider(height: 24),
          ],
        ],
      ),
    );

    /* ───────────────────────────────────────────────────────────
    // [OLD v1] แบบ "แถบ + ป้ายส้มด้านซ้าย"
    // ใช้แทน Container ด้านบนได้ โดยปลดคอมเมนต์บล็อกนี้
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _buildStripRowBadge(context, items[i]),
            if (i < items.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
    ─────────────────────────────────────────────────────────── */
  }

  /// แถวแบบ "ตารางวัตถุดิบ" (ซ้ายชื่อ/ขวาค่า + เส้นคั่น)
  Widget _buildRow(BuildContext context, _NutItem item) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final TextStyle base =
        (textTheme.titleMedium ?? textTheme.bodyLarge!).copyWith(
      fontWeight: FontWeight.w400,
      color: cs.onSurface,
    );

    // ★ Changed: เปลี่ยนจาก _fmtK → _fmtNut (คั่นหลักพัน, ไม่มี 'K')
    final valueStr = _fmtNut(item.value);
    final display = '$valueStr ${item.unit}'.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ชื่อ
        Expanded(
          flex: 3,
          child: Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: base,
          ),
        ),
        const SizedBox(width: 16),
        // ค่า (ชิดขวา)
        Expanded(
          flex: 2,
          child: Text(
            display,
            maxLines: 1,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: base,
          ),
        ),
      ],
    );
  }

  /* ───────────────────────────────────────────────────────────
   [OLD v1] แถวแบบ "แถบ + ป้ายส้มด้านซ้าย"
   ปลดคอมเมนต์ฟังก์ชันนี้ + ใช้บล็อก build(…) เวอร์ชัน OLD v1 ข้างบน
   เพื่อกลับไปใช้สไตล์ป้ายส้ม
  ───────────────────────────────────────────────────────────
  Widget _buildStripRowBadge(BuildContext context, _NutItem item) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final txt = theme.textTheme;

    final baseSize = txt.titleMedium?.fontSize ?? 20.0;
    final valueStr = _fmtNut(item.value); // ★ Changed: ใช้ _fmtNut
    final display = '$valueStr ${item.unit}'.trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
  color: cs.surface.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.primary, width: 1.5),
            ),
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (txt.labelLarge ?? txt.bodyMedium!)
                  .copyWith(color: cs.primary, fontWeight: FontWeight.w700),
            ),
          ),
          const Spacer(),
          Text(
            display,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: txt.titleMedium?.copyWith(
              fontSize: baseSize,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
  ─────────────────────────────────────────────────────────── */

  /* ───────────────────────────────────────────────────────────
   [OLD v0] การ์ด 4 คอลัมน์ (สไตล์แรกสุด)
   ใช้คู่กับ GridView.builder ใน build() (ดูตัวอย่างในไฟล์ก่อนหน้า)
  ───────────────────────────────────────────────────────────
  Widget _buildOldCard(BuildContext context, _NutItem item) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final valueStr = _fmtNut(item.value); // ★ Changed: ใช้ _fmtNut
    final v = '$valueStr ${item.unit}'.trim();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
  border: Border.all(color: cs.primary.withValues(alpha: .7), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(item.label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w700,
                height: 1.15,
              )),
          const SizedBox(height: 6),
          Text(
            v,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
  ─────────────────────────────────────────────────────────── */

  /* ───────────────────────────────────────────────────────────
   [OLD util] Number format เดิม + บั๊กเดิมของ _trimZeros (อ้างอิง)
   - เดิม: ใช้ K เฉพาะ >= 10,000 และตัวแทนกลุ่มย่อยเป็น r'\1'
   - ตอนนี้แก้เป็น _fmtK และใช้ replaceFirstMapped แล้ว
  ───────────────────────────────────────────────────────────
  // String _fmt(double n) {
  //   if (n >= 1_000_000) return '${(n / 1e6).toStringAsFixed(1)}M';
  //   if (n >= 10_000) return '${(n / 1e3).toStringAsFixed(1)}K';
  //   if (n >= 1_000) return NumberFormat('#,###', 'th_TH').format(n.round());
  //   if (n >= 100) return n.toStringAsFixed(0);
  //   if (n >= 10) return n.toStringAsFixed(1);
  //   if (n >= 1) return n.toStringAsFixed(1);
  //   return n.toStringAsFixed(2);
  // }
  //
  // String _trimZeros_BUG(String s) => s
  //     .replaceFirst(RegExp(r'([.]\d*?)0+$'), r'\1') // ← ทำให้ได้ "93\1"
  //     .replaceFirst(RegExp(r'[.]$'), '');
  ─────────────────────────────────────────────────────────── */
}
