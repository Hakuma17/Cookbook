import 'package:flutter/foundation.dart';

class FavoriteStore extends ChangeNotifier {
  FavoriteStore({Set<int>? initialIds}) {
    if (initialIds != null) _ids.addAll(initialIds);
  }

  final Set<int> _ids = {};

  bool contains(int id) => _ids.contains(id);

  /// ใช้ในกรณี "สั่งให้เป็นค่า X ตามผลจริงจากเซิร์ฟเวอร์"
  /// เช่น r.isFavorited จาก ApiService.toggleFavorite(...) เพื่อกัน desync
  Future<void> set(int id, bool isFavorited) async {
    // คงพฤติกรรมให้ชัดเจน: isFavorited=true → add, false → remove
    if (isFavorited) {
      _ids.add(id);
    } else {
      _ids.remove(id);
    }
    notifyListeners();
  }

  /// toggle เดิม (คงไว้เพื่อเข้ากับโค้ดที่เรียกใช้เดิม)
  /// หมายเหตุ: ฟังก์ชันนี้ "เชื่อค่าที่ส่งเข้ามา" (shouldFav) โดยไม่ได้ตรวจสอบกับเซิร์ฟเวอร์
  /// แนะนำให้ใช้ร่วมกับผลจริงจาก backend หรือเปลี่ยนมาเรียก set(...) แทนในจุดที่ต้องการความแม่นยำ
  Future<void> toggle(int id, bool shouldFav) async {
    if (shouldFav) {
      _ids.add(id);
    } else {
      _ids.remove(id);
    }
    notifyListeners();
  }

  /// แทนที่รายการทั้งหมด (เช่น หลังล็อกอินเสร็จ แล้ว preload favorite ids)
  Future<void> replace(Set<int> ids) async {
    _ids
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  // ★★★ [NEW] ล้างรายการทั้งหมดเวลา logout / เปลี่ยนบัญชี
  Future<void> clear() async {
    if (_ids.isEmpty) return;
    _ids.clear();
    notifyListeners();
  }
}
