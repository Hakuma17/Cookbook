// lib/utils/sanitize.dart
//
// Input sanitization helpers for UI-facing text and queries.
// These functions are lightweight and do not replace server-side validation,
// but they help reduce risky characters and normalize whitespace before
// sending to backend or using in UI.
//
// ภาษาไทย (สรุป):
// - text(): ตัด control chars, รวมช่องว่างซ้ำ, trim และ (ค่าเริ่มต้น) ลบอักขระเสี่ยง
// - query(): ตัด control chars, รวมช่องว่างซ้ำ, trim และลบเครื่องหมายที่เสี่ยงกับการค้นหา

class Sanitize {
  // Allow common punctuation; reject control chars and dangerous symbols
  static final RegExp _control = RegExp(r"[\x00-\x08\x0B\x0C\x0E-\x1F]");
  static final RegExp _multiSpace = RegExp(r"\s{2,}");

  /// Sanitize a free-text field (e.g., display name, bio)
  /// - Trim
  /// - Remove control characters
  /// - Collapse excessive whitespace
  /// - Optionally strip characters that commonly break SQL/HTML if misused
  static String text(String? raw, {bool stripDangerous = true}) {
    if (raw == null) return '';
    var s = raw.replaceAll(_control, '').trim();
    s = s.replaceAll(_multiSpace, ' ');
    if (stripDangerous) {
      // Remove characters that easily lead to injection/pattern mistakes
      // Keep normal Thai/Latin letters, digits, spaces, and lightweight punctuation.
      s = s.replaceAll(RegExp(r"[<>`$\\]"), '');
    }
    return s;
  }

  /// Sanitize a search query: lightweight cleanup, keep symbols that users expect.
  static String query(String? raw) {
    if (raw == null) return '';
    var s = raw.replaceAll(_control, '').trim();
    s = s.replaceAll(_multiSpace, ' ');
    // Avoid quotes that could break server-side poorly-escaped queries
    s = s.replaceAll('"', '');
    s = s.replaceAll("'", '');
    return s;
  }
}
