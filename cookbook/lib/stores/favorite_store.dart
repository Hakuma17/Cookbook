import 'package:flutter/foundation.dart';

class FavoriteStore extends ChangeNotifier {
  FavoriteStore({Set<int>? initialIds}) {
    if (initialIds != null) {
      _ids.addAll(initialIds.where((e) => e > 0));
    }
  }

  final Set<int> _ids = {};

  // ---- Read-only helpers ----
  Set<int> get ids => Set<int>.unmodifiable(_ids);
  int get length => _ids.length;
  bool get isEmpty => _ids.isEmpty;
  bool get isNotEmpty => _ids.isNotEmpty;

  bool contains(int id) => _ids.contains(id);

  /// เซ็ตสถานะตามผลจริงจากเซิร์ฟเวอร์
  Future<void> set(int id, bool isFavorited) async {
    if (id <= 0) return;
    final changed = isFavorited ? _ids.add(id) : _ids.remove(id);
    if (changed) notifyListeners();
  }

  /// toggle ตามค่าที่ส่งเข้ามา (ไว้เข้ากับโค้ดเดิม)
  Future<void> toggle(int id, bool shouldFav) async {
    if (id <= 0) return;
    final changed = shouldFav ? _ids.add(id) : _ids.remove(id);
    if (changed) notifyListeners();
  }

  /// แทนที่ทั้งหมดด้วยเซ็ตใหม่
  Future<void> replace(Set<int> ids) async {
    final next = ids.where((e) => e > 0).toSet();
    if (setEquals(_ids, next)) return; // ไม่เปลี่ยน ไม่ต้อง notify
    _ids
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  /// แทนที่ทั้งหมดจาก Iterable (สะดวกกับ .map/.where)
  Future<void> replaceWith(Iterable<int> ids) async {
    await replace(ids.toSet());
  }

  /// ลบหลายรายการรวดเดียว
  Future<void> removeMany(Iterable<int> ids) async {
    bool changed = false;
    for (final id in ids) {
      if (id <= 0) continue;
      changed |= _ids.remove(id);
    }
    if (changed) notifyListeners();
  }

  /// ล้างทั้งหมด (เช่น ตอน logout)
  Future<void> clear() async {
    if (_ids.isEmpty) return;
    _ids.clear();
    notifyListeners();
  }

  /// (ทางเลือก) ใช้กับผลลัพธ์จาก ApiService.toggleFavorite(...)
  Future<void> applyServerResult(dynamic result) async {
    // รองรับอ็อบเจกต์ที่มี field recipeId/isFavorited (เช่น FavoriteToggleResult)
    final rid = result.recipeId as int? ?? 0;
    final fav = result.isFavorited as bool? ?? false;
    await set(rid, fav);
  }
}
