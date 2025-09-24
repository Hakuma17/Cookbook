// lib/utils/sanitize.dart
//
// ตัวช่วยทำความสะอาดอินพุตสำหรับข้อความ/คำค้นที่แสดงต่อผู้ใช้
// ฟังก์ชันเหล่านี้มีน้ำหนักเบาและไม่ใช่การตรวจสอบฝั่งเซิร์ฟเวอร์
// แต่ช่วยลดอักขระเสี่ยงและทำให้ช่องว่างเป็นมาตรฐานก่อนส่งไป backend หรือใช้ใน UI
//
// ภาษาไทย (สรุป):
// - text(): ตัด control chars, รวมช่องว่างซ้ำ, trim และ (ค่าเริ่มต้น) ลบอักขระเสี่ยง
// - query(): ตัด control chars, รวมช่องว่างซ้ำ, trim และลบเครื่องหมายที่เสี่ยงกับการค้นหา

class Sanitize {
  // อนุญาตเครื่องหมายวรรคตอนทั่วไป; ปฏิเสธ control chars และสัญลักษณ์เสี่ยง
  static final RegExp _control = RegExp(r"[\x00-\x08\x0B\x0C\x0E-\x1F]");
  static final RegExp _multiSpace = RegExp(r"\s{2,}");

  /// ทำความสะอาดช่องข้อความอิสระ (เช่น ชื่อแสดงผล, bio)
  /// - ตัดช่องว่างหัวท้าย (Trim)
  /// - ลบอักขระควบคุม (control characters)
  /// - รวมช่องว่างที่มากเกินจำเป็น
  /// - เลือกลบอักขระที่มักทำให้ SQL/HTML พัง หากนำไปใช้ผิดที่ผิดทาง
  static String text(String? raw, {bool stripDangerous = true}) {
    if (raw == null) return '';
    var s = raw.replaceAll(_control, '').trim();
    s = s.replaceAll(_multiSpace, ' ');
    if (stripDangerous) {
      // ลบอักขระที่นำไปสู่การโจมตี/injection หรือรูปแบบผิดพลาดได้ง่าย
      // คงไว้ซึ่งอักษรไทย/ละติน ตัวเลข เว้นวรรค และวรรคตอนพื้นฐาน
      s = s.replaceAll(RegExp(r"[<>`$\\]"), '');
    }
    return s;
  }

  /// ทำความสะอาดคำค้นหา: ทำความสะอาดแบบเบาๆ และคงสัญลักษณ์ที่ผู้ใช้คาดหวัง
  static String query(String? raw) {
    if (raw == null) return '';
    var s = raw.replaceAll(_control, '').trim();
    s = s.replaceAll(_multiSpace, ' ');
    // เลี่ยงเครื่องหมายคำพูดที่อาจทำให้คำค้นฝั่งเซิร์ฟเวอร์พัง หาก escape ไม่ดี
    s = s.replaceAll('"', '');
    s = s.replaceAll("'", '');
    return s;
  }
}
