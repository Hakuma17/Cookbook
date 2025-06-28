// lib/utils/highlight_span.dart
// ------------------------------------------------------------
// Utility สร้าง TextSpan ที่ “ไฮไลท์” คำค้น โดย **คงฟอนต์เดิมทุกอย่าง**
// ------------------------------------------------------------

import 'package:flutter/material.dart';

/// คืนค่า TextSpan พร้อมไฮไลท์คำค้น (`terms`)
///
/// * `baseStyle`      – สไตล์ต้นฉบับ (เช่น Montserrat w700)
/// * `normalStyle`   – ถ้าอยาก override สไตล์ปกติ (ไม่แนะนำให้ตั้งเอง)
/// * `highlightStyle` – ถ้าอยาก override สไตล์ไฮไลท์ (ควรใช้แค่เปลี่ยนสี)
TextSpan highlightSpan(
  String source,
  List<String> terms,
  TextStyle baseStyle, {
  TextStyle? normalStyle,
  TextStyle? highlightStyle,
}) {
  // -----------------------------------------------------------------
  // 1) เตรียมสไตล์พื้นฐาน
  // -----------------------------------------------------------------
  final _normal = (normalStyle ?? baseStyle);

  // ถ้า caller ไม่ระบุ highlightStyle → merge จาก baseStyle แล้วเปลี่ยนแค่สี
  final _highlight = (highlightStyle ??
      baseStyle.merge(const TextStyle(
        color: Color(0xFFFF9B05), // สีส้มของแอป
      )));

  // -----------------------------------------------------------------
  // 2) ถ้าไม่มีข้อความหรือไม่มีคำค้น → ส่งกลับ span เดียวจบ
  // -----------------------------------------------------------------
  if (source.isEmpty || terms.isEmpty) {
    return TextSpan(text: source, style: _normal);
  }

  // -----------------------------------------------------------------
  // 3) สร้าง RegExp รวมทุกคำค้น (escape meta-chars)
  // -----------------------------------------------------------------
  final pattern =
      terms.where((t) => t.trim().isNotEmpty).map(RegExp.escape).join('|');
  if (pattern.isEmpty) {
    return TextSpan(text: source, style: _normal);
  }
  final reg = RegExp('($pattern)', caseSensitive: false);

  // -----------------------------------------------------------------
  // 4) วิ่งหาแมตช์แล้วแยกเป็น spans
  // -----------------------------------------------------------------
  final spans = <TextSpan>[];
  int last = 0;

  for (final m in reg.allMatches(source)) {
    // ส่วนที่ไม่ไฮไลท์
    if (m.start > last) {
      spans.add(TextSpan(
        text: source.substring(last, m.start),
        style: _normal,
      ));
    }
    // ส่วนที่ไฮไลท์
    spans.add(TextSpan(
      text: source.substring(m.start, m.end),
      style: _highlight,
    ));
    last = m.end;
  }
  // เติมส่วนท้าย (ถ้ามี)
  if (last < source.length) {
    spans.add(TextSpan(text: source.substring(last), style: _normal));
  }

  return TextSpan(children: spans, style: _normal);
}
