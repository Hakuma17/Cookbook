import 'package:flutter_test/flutter_test.dart';
import 'package:cookbook/utils/unit_convert.dart';

void main() {
  group('UnitConvert.approximateGrams()', () {
    test('รู้จักหน่วยครัวพื้นฐาน (ช้อนชา/โต๊ะ/ถ้วย)', () {
      expect(UnitConvert.approximateGrams(1, 'ช้อนชา'), 5);
      expect(UnitConvert.approximateGrams(2, 'tbsp'), 30);
      expect(UnitConvert.approximateGrams(0.5, 'cup'), 120);
    });

    test('metric: กรัม/กิโลกรัม/มิลลิลิตร/ลิตร', () {
      expect(UnitConvert.approximateGrams(15, 'g'), 15);
      expect(UnitConvert.approximateGrams(1.2, 'kg'), 1200);
      expect(UnitConvert.approximateGrams(100, 'ml'), 100);
      expect(UnitConvert.approximateGrams(1, 'ลิตร'), 1000);
    });

    test('ไม่รู้จักหน่วย → คืน null', () {
      expect(UnitConvert.approximateGrams(1, 'pinch'), isNull);
    });
  });

  group('UnitConvert.fmtNum()', () {
    test('ตัดศูนย์ทศนิยมส่วนเกิน และปัดอย่างถูกต้อง', () {
      expect(UnitConvert.fmtNum(5.0), '5');
      expect(UnitConvert.fmtNum(5.2), '5.2');
      expect(UnitConvert.fmtNum(5.251), '5.25');
      expect(UnitConvert.fmtNum(5.255), '5.26');
    });

    test('ค่าทศนิยมเล็กมากจนปัดเป็นศูนย์แต่เดิมไม่ใช่ศูนย์', () {
      expect(UnitConvert.fmtNum(0.001, maxDecimals: 2), '0.00');
    });
  });
}
