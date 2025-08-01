// lib/stores/settings_store.dart
//
// Store กลางสำหรับ “การตั้งค่าแอป” โดยเฉพาะสวิตช์การค้นหาแบบตัดคำภาษาไทย
// - ใช้ SharedPreferences เก็บค่าไว้ในเครื่อง
// - ค่าเริ่มต้น (ดีฟอลต์) ของการตัดคำ = ปิด (false)
// - เรียก load() ครั้งเดียวตอนบูตแอป เพื่อดึงค่าจากเครื่องขึ้นมา
//
// การใช้งาน (ตัวอย่างใน main.dart):
//   ChangeNotifierProvider(
//     create: (_) => SettingsStore()..load(),
//     child: const MyApp(),
//   )
//
// การอ่านค่าในหน้า/วิดเจ็ต:
//   context.watch<SettingsStore>().searchTokenizeEnabled
//
// การสลับค่า:
//   context.read<SettingsStore>().setSearchTokenizeEnabled(true/false)

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore extends ChangeNotifier {
  // ─────────────────────────────────────────────────────────
  // Keys สำหรับ SharedPreferences
  // ─────────────────────────────────────────────────────────
  static const String _kSearchTokenizeKey = 'search_tokenize_enabled';

  // ─────────────────────────────────────────────────────────
  // State ภายใน (ค่าเริ่มต้น = ปิด)
  // ─────────────────────────────────────────────────────────
  bool _searchTokenizeEnabled = false; // ✅ ดีฟอลต์ปิด
  bool get searchTokenizeEnabled => _searchTokenizeEnabled;

  bool _loaded = false; // ไว้เช็กว่ามีการ load() แล้วหรือยัง
  bool get isLoaded => _loaded;

  // ─────────────────────────────────────────────────────────
  // โหลดค่าจาก SharedPreferences (เรียกครั้งเดียวตอนเริ่มแอป)
  // ─────────────────────────────────────────────────────────
  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    _searchTokenizeEnabled =
        sp.getBool(_kSearchTokenizeKey) ?? false; // ← ดีฟอลต์ปิด
    _loaded = true;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────
  // สลับสวิตช์ “ตัดคำภาษาไทย”
  // - อัปเดตค่าในหน่วยความจำ + บันทึกลง SharedPreferences
  // - แจ้ง UI ผ่าน notifyListeners()
  // ─────────────────────────────────────────────────────────
  Future<void> setSearchTokenizeEnabled(bool enabled) async {
    if (_searchTokenizeEnabled == enabled) return;
    _searchTokenizeEnabled = enabled;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kSearchTokenizeKey, enabled);
  }

  // ─────────────────────────────────────────────────────────
  // (ออปชัน) เคลียร์ค่าทุกอย่างของ Settings ภายในเครื่อง
  // ใช้ในกรณีต้องการรีเซ็ตเป็นค่าโรงงาน
  // ─────────────────────────────────────────────────────────
  Future<void> resetToDefault() async {
    _searchTokenizeEnabled = false; // ค่าโรงงาน = ปิด
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kSearchTokenizeKey);
  }
}
