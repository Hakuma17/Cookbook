// lib/stores/settings_store.dart
//
// Store กลางสำหรับ “การตั้งค่าแอป”
// - เก็บสวิตช์ "ตัดคำภาษาไทย" สำหรับการค้นหา (ดีฟอลต์: ปิด)
// - เก็บโหมดธีมของแอป (ThemeMode): system/light/dark (ดีฟอลต์: system)
// - ใช้ SharedPreferences เพื่อคงค่านอกเหนือรันไทม์
//
// การใช้งาน (ตัวอย่างใน main.dart):
//   ChangeNotifierProvider(
//     create: (_) => SettingsStore()..load(),
//     child: MyApp(...),
//   )
//
// ใน MaterialApp ให้ใช้ค่า themeMode จาก store:
//   Consumer<SettingsStore>(
//     builder: (_, s, __) => MaterialApp(
//       theme: appLight,
//       darkTheme: appDark,
//       themeMode: s.themeMode,
//       ...
//     ),
//   )
//
// ในหน้า SettingsScreen เพิ่มตัวเลือก ThemeMode:
//   final store = context.watch<SettingsStore>();
//   RadioListTile<ThemeMode>(
//     value: ThemeMode.light,
//     groupValue: store.themeMode,
//     onChanged: (m) => context.read<SettingsStore>().setThemeMode(m!),
//   )

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore extends ChangeNotifier {
  /* ───────────────────────── Keys & Defaults ───────────────────────── */
  static const String _kSearchTokenizeKey = 'search_tokenize_enabled';
  static const bool _kDefaultTokenize = false;

  static const String _kThemeModeKey =
      'theme_mode'; // 'system' | 'light' | 'dark'
  static const ThemeMode _kDefaultThemeMode = ThemeMode.system;

  /* ───────────────────────── State ───────────────────────── */
  bool _searchTokenizeEnabled = _kDefaultTokenize; // ดีฟอลต์: ปิด
  bool get searchTokenizeEnabled => _searchTokenizeEnabled;

  ThemeMode _themeMode = _kDefaultThemeMode; // ดีฟอลต์: system
  ThemeMode get themeMode => _themeMode;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /* ───────────────────────── Prefs cache ───────────────────────── */
  SharedPreferences? _sp;
  Future<SharedPreferences> _prefs() async =>
      _sp ??= await SharedPreferences.getInstance();

  /* ───────────────────────── Load ───────────────────────── */
  /// โหลดค่าจากเครื่อง (ควรเรียกครั้งเดียวตอนบูตแอป)
  Future<void> load() async {
    if (_loaded) return; // กันโหลดซ้ำ
    final sp = await _prefs();

    // ค่าตัดคำภาษาไทย (ดีฟอลต์ปิด)
    _searchTokenizeEnabled =
        sp.getBool(_kSearchTokenizeKey) ?? _kDefaultTokenize;

    // โหมดธีม (ดีฟอลต์ system)
    final modeStr = sp.getString(_kThemeModeKey) ?? 'system';
    _themeMode = _parseThemeMode(modeStr);

    _loaded = true;
    notifyListeners();
  }

  /* ───────────────────────── Search tokenize ───────────────────────── */
  Future<void> setSearchTokenizeEnabled(bool enabled) async {
    if (_searchTokenizeEnabled == enabled) return; // ไม่เปลี่ยนก็ไม่ต้อง notify
    _searchTokenizeEnabled = enabled;
    notifyListeners(); // อัปเดต UI ก่อน
    final sp = await _prefs();
    await sp.setBool(_kSearchTokenizeKey, enabled);
  }

  Future<void> toggleSearchTokenize() =>
      setSearchTokenizeEnabled(!searchTokenizeEnabled);

  /* ───────────────────────── Theme mode ───────────────────────── */
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners(); // ให้ MaterialApp rebuild ด้วย themeMode ใหม่
    final sp = await _prefs();
    await sp.setString(_kThemeModeKey, _stringifyThemeMode(mode));
  }

  /// สลับโหมดแบบวน: system → light → dark → system ...
  Future<void> cycleThemeMode() async {
    final next = switch (_themeMode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    await setThemeMode(next);
  }

  /* ───────────────────────── Reset ───────────────────────── */
  /// รีเซ็ตกลับค่าโรงงานทั้งหมดของ Settings
  Future<void> resetToDefault() async {
    bool changed = false;

    if (_searchTokenizeEnabled != _kDefaultTokenize) {
      _searchTokenizeEnabled = _kDefaultTokenize;
      changed = true;
    }
    if (_themeMode != _kDefaultThemeMode) {
      _themeMode = _kDefaultThemeMode;
      changed = true;
    }

    if (changed) notifyListeners();

    final sp = await _prefs();
    await sp.remove(_kSearchTokenizeKey);
    await sp.remove(_kThemeModeKey);
  }

  /* ───────────────────────── Helpers ───────────────────────── */
  ThemeMode _parseThemeMode(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  String _stringifyThemeMode(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
      default:
        return 'system';
    }
  }
}
