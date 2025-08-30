// lib/utils/unit_convert.dart
import 'dart:math' as math;
// import 'package:intl/intl.dart'; // (แนะนำ) สำหรับ NumberFormat ที่ยืดหยุ่นกว่า

/// A utility class for converting and formatting kitchen units.
class UnitConvert {
  UnitConvert._();

  /// ★ 1. ปรับปรุง Map ให้ Key เป็น lowercase ทั้งหมดตั้งแต่แรก
  ///    - เพื่อให้การค้นหา (lookup) ทำงานได้เร็วที่สุด (O(1))
  ///    - ลดความผิดพลาดในการเพิ่มข้อมูล key ในอนาคต
  static const Map<String, double> _gPerUnit = {
    // Metric
    'กรัม': 1, 'g': 1,
    'กิโลกรัม': 1000, 'กก.': 1000, 'kg': 1000,
    'มิลลิลิตร': 1, 'มล.': 1, 'ml': 1,
    'ลิตร': 1000, 'l': 1000,

    // Kitchen
    'ช้อนชา': 5, 'tsp': 5,
    'ช้อนโต๊ะ': 15, 'tbsp': 15,
    'ถ้วย': 240, 'cup': 240,
  };

  /// Approximates the gram value for a given quantity and unit.
  ///
  /// Returns the value in grams if the unit is recognized, otherwise returns `null`.
  static double? approximateGrams(double quantity, String unit) {
    // ★ 2. เปลี่ยนมาใช้การค้นหาจาก Map โดยตรง (O(1)) ซึ่งเร็วกว่า .firstWhere (O(n)) มาก
    final u = unit.trim().toLowerCase();
    final g = _gPerUnit[u];

    if (g == null) return null;
    return quantity * g;
  }

  /// Formats a number for easy reading by removing trailing zeros
  /// and limiting decimal places.
  /// e.g., 5.0 -> "5", 5.251 -> "5.25", 5.20 -> "5.2"
  static String fmtNum(double v, {int maxDecimals = 2}) {
    // ★ 3. ปรับปรุง `fmtNum` ให้อ่านง่ายและแม่นยำขึ้น
    if (v.isNaN) return '0';

    // ปัดเศษตามจำนวนทศนิยมที่ต้องการ
    final pow10 = math.pow(10, maxDecimals);
    final rounded = (v * pow10).round() / pow10;

    // ถ้าปัดเศษแล้วได้ 0 แต่ค่าเดิมไม่ใช่ 0 (เช่น 0.001) ให้แสดงตามทศนิยม
    if (rounded == 0 && v != 0) {
      return v.toStringAsFixed(maxDecimals);
    }

    // ถ้าเป็นจำนวนเต็ม ให้แสดงแบบไม่มีทศนิยม
    if (rounded == rounded.floorToDouble()) {
      return rounded.toInt().toString();
    }

    // สำหรับทศนิยม, .toString() จะตัด 0 ลงท้ายให้เอง (เช่น 5.20 -> "5.2")
    return rounded.toString();
  }

  /*
  // (วิธีมาตรฐาน) ใช้ NumberFormat จาก `intl` package จะยืดหยุ่นและดีกว่าในระยะยาว
  static String fmtNumWithIntl(double v) {
    // NumberFormat will handle rounding and formatting correctly.
    // '0.##' means show up to 2 decimal places, but only if necessary.
    return NumberFormat('0.##').format(v);
  }
  */

  /// Formats a gram value into a display string, e.g., "150 กรัม".
  static String fmtGrams(double grams) => '${fmtNum(grams)} กรัม';
}
