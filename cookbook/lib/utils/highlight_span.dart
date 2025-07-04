// lib/utils/highlight_span.dart
// ------------------------------------------------------------
// Utility สร้าง TextSpan ที่ “ไฮไลท์” คำค้น โดย **คงฟอนต์เดิมทุกอย่าง**
// (เวอร์ชันรับ tokens จาก backend – 2025-07-04)
// ------------------------------------------------------------

import 'package:flutter/material.dart';

/// คืนค่า TextSpan ที่ข้างใน “ไฮไลท์” ทุกคำใน `terms`
///
/// * `baseStyle`       – สไตล์ต้นฉบับ (เช่น Montserrat w700)
/// * `normalStyle`     – (ไม่บังคับ) override สไตล์ปกติ
/// * `highlightStyle`  – (ไม่บังคับ) override สไตล์ไฮไลท์
TextSpan highlightSpan(
  String source,
  List<String> terms,
  TextStyle baseStyle, {
  TextStyle? normalStyle,
  TextStyle? highlightStyle,
}) {
  /* ---------- 1) เตรียมสไตล์ ---------- */
  final normal = normalStyle ?? baseStyle;
  final highlight = highlightStyle ??
      baseStyle.merge(
        const TextStyle(color: Color(0xFFFF9B05)), // สีส้มของแอป
      );

  /* ---------- 2) ถ้า source หรือ terms ว่าง → ส่ง span เดียว ---------- */
  if (source.isEmpty || terms.isEmpty) {
    return TextSpan(text: source, style: normal);
  }

  /* ---------- 3) สร้าง RegExp รวมทุก token ---------- */
  // 3-A กรองช่องว่าง/ซ้ำ แล้วเรียง “ยาว → สั้น” ป้องกันคำยาวถูกคร่อม
  final toks = <String>{
    for (final t in terms)
      if (t.trim().isNotEmpty) t.trim(),
  }.toList()
    ..sort((a, b) => b.length.compareTo(a.length));

  if (toks.isEmpty) {
    return TextSpan(text: source, style: normal);
  }

  // 3-B รวมเป็น pattern เดียว แล้ว ignore case
  final reg =
      RegExp('(${toks.map(RegExp.escape).join('|')})', caseSensitive: false);

  /* ---------- 4) เดินสตริงแล้วแตกเป็น spans ---------- */
  final spans = <TextSpan>[];
  int last = 0;

  for (final m in reg.allMatches(source)) {
    if (m.start > last) {
      spans.add(TextSpan(text: source.substring(last, m.start), style: normal));
    }
    spans.add(
        TextSpan(text: source.substring(m.start, m.end), style: highlight));
    last = m.end;
  }

  if (last < source.length) {
    spans.add(TextSpan(text: source.substring(last), style: normal));
  }

  return TextSpan(children: spans, style: normal);
}
