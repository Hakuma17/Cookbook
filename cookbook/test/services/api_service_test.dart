import 'package:flutter_test/flutter_test.dart';
import 'package:cookbook/services/api_service.dart';

void main() {
  // แบบทดสอบภาษาไทย: ตรวจพฤติกรรม normalizeUrl ให้ถูกตามที่ระบบใช้งานจริง
  group('ApiService.normalizeUrl()', () {
    setUpAll(() async {
      // กำหนด baseUrl สำหรับการทดสอบ
      ApiService.baseUrl = 'http://example.com/app/';
    });

    test('คืนค่าว่างเมื่อรับค่าว่าง/ช่องว่าง', () {
      expect(ApiService.normalizeUrl(''), '');
      expect(ApiService.normalizeUrl('   '), '');
      expect(ApiService.normalizeUrl(null), '');
    });

    test('แปลง relative path → absolute โดยอิง baseUrl', () {
      expect(
        ApiService.normalizeUrl('images/pic.jpg'),
        'http://example.com/app/images/pic.jpg',
      );
      expect(
        ApiService.normalizeUrl('/images/pic.jpg'),
        'http://example.com/app/images/pic.jpg',
      );
    });

    test('map localhost/127.0.0.1/::1 → host ของ baseUrl', () {
      expect(
        ApiService.normalizeUrl('http://localhost/assets/a.png'),
        'http://example.com/assets/a.png',
      );
      expect(
        ApiService.normalizeUrl('http://127.0.0.1:8080/a/b'),
        'http://example.com/a/b',
      );
      expect(
        ApiService.normalizeUrl('http://[::1]/a'),
        'http://example.com/a',
      );
    });
  });
}
