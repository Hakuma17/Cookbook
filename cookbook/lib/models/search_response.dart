// models/search_response.dart
// ------------------------------------------------------------
// ตัวห่อผลลัพธ์การค้นหา (รับจาก   search_recipes_unified.php)
// ------------------------------------------------------------

import 'recipe.dart';

class SearchResponse {
  const SearchResponse({
    required this.page,
    required this.tokens,
    required this.recipes,
  });

  /// หน้า (เริ่มที่ 1) ที่ backend ส่งกลับ
  final int page;

  /// รายการ token ที่ backend ตัดคำมาแล้ว
  ///   – ถ้า backend ไม่ส่งมา จะเป็น []
  final List<String> tokens;

  /// รายการสูตรอาหารในหน้าปัจจุบัน
  final List<Recipe> recipes;
}
