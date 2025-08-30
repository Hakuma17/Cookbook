// test/widget_test.dart
import 'package:cookbook/screens/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cookbook/main.dart';
import 'package:cookbook/screens/splash_screen.dart';

void main() {
  //   1. ตั้งค่าที่จำเป็นก่อนการทดสอบ
  setUpAll(() async {
    // Test จำเป็นต้องมีการ mock หรือ setup service ที่เรียกใน main() ก่อน
    // ในที่นี้เราจะข้ามไปก่อนเพื่อให้ Test รันผ่านได้
    // แต่ในอนาคตควรเรียนรู้เรื่องการ Mocking เพิ่มเติม
  });

  testWidgets('App starts with SplashScreen smoke test',
      (WidgetTester tester) async {
    // 2. สร้าง MyApp ของเราขึ้นมา
    await tester.pumpWidget(MyApp(
      initialFavoriteIds: <int>{},
    ));

    // 3. รอให้ animation หรือ Future ทำงานเสร็จ (เช่น Timer ใน SplashScreen)
    // pumpAndSettle จะรอจนกว่าจะไม่มี frame ใหม่ๆ เกิดขึ้น
    await tester.pumpAndSettle();

    // 4. ตรวจสอบว่าเจอ SplashScreen 1 ตัวในหน้าจอ
    expect(find.byType(SplashScreen), findsOneWidget);

    // 5. ตรวจสอบว่าไม่เจอ Widget ของหน้าอื่น เช่น HomeScreen
    expect(find.byType(HomeScreen), findsNothing);
  });
}
