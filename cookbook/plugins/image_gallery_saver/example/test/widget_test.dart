import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Update the import path to the correct relative location of main.dart
import '../lib/main.dart';

void main() {
  testWidgets('Verify Widgets', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(new MyApp());
    final Finder flatButtonPass = find.widgetWithText(ElevatedButton, '保存屏幕截图');
    expect(flatButtonPass, findsOneWidget);
  });
}
