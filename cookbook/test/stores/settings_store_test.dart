import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cookbook/stores/settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsStore', () {
    test('load() ใช้ค่า default เมื่อยังไม่เคยบันทึก', () async {
      SharedPreferences.setMockInitialValues({});
      final s = SettingsStore();
      await s.load();
      expect(s.searchTokenizeEnabled, isFalse);
      expect(s.themeMode, ThemeMode.system);
      expect(s.isLoaded, isTrue);
    });

    test('toggle และ persist ค่า', () async {
      SharedPreferences.setMockInitialValues({});
      final s = SettingsStore();
      await s.load();

      await s.toggleSearchTokenize();
      expect(s.searchTokenizeEnabled, isTrue);

      await s.setThemeMode(ThemeMode.dark);
      expect(s.themeMode, ThemeMode.dark);

      // โหลดใหม่ควรได้ค่าที่บันทึกไว้
      final s2 = SettingsStore();
      await s2.load();
      expect(s2.searchTokenizeEnabled, isTrue);
      expect(s2.themeMode, ThemeMode.dark);
    });

    test('resetToDefault() คืนค่าโรงงานและลบใน prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final s = SettingsStore();
      await s.load();
      await s.setThemeMode(ThemeMode.dark);
      await s.setSearchTokenizeEnabled(true);

      await s.resetToDefault();
      expect(s.themeMode, ThemeMode.system);
      expect(s.searchTokenizeEnabled, isFalse);

      // โหลดใหม่ต้องได้ default
      final s2 = SettingsStore();
      await s2.load();
      expect(s2.themeMode, ThemeMode.system);
      expect(s2.searchTokenizeEnabled, isFalse);
    });
  });
}
