import 'package:flutter/foundation.dart';
import 'recipe.dart';

// ✅ 1. เพิ่ม Helper functions เพื่อการ Parse ที่ปลอดภัยและสอดคล้องกับ Model อื่นๆ
int _toInt(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? fallback;
}

/// ตัวห่อผลลัพธ์การค้นหา
@immutable
class SearchResponse {
  const SearchResponse({
    required this.page,
    required this.tokens,
    required this.recipes,
  });

  /// หน้า (เริ่มที่ 1) ที่ backend ส่งกลับ
  final int page;

  /// รายการ token ที่ backend ตัดคำมาแล้ว
  ///  – ถ้า backend ไม่ส่งมา จะเป็น []
  final List<String> tokens;

  /// รายการสูตรอาหารในหน้าปัจจุบัน
  final List<Recipe> recipes;

  /// ✅ 2. เพิ่ม factory constructor สำหรับสร้าง Object จาก JSON
  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      page: _toInt(json['page'], fallback: 1),
      tokens: (json['tokens'] is List) ? List<String>.from(json['tokens']) : [],
      recipes: (json['data'] is List)
          ? (json['data'] as List).map((e) => Recipe.fromJson(e)).toList()
          : [],
    );
  }

  /// ✅ 3. เพิ่มเมธอดมาตรฐานสำหรับ Immutable class
  SearchResponse copyWith({
    int? page,
    List<String>? token,
    List<Recipe>? recipes,
  }) {
    return SearchResponse(
      page: page ?? this.page,
      tokens: tokens ?? this.tokens,
      recipes: recipes ?? this.recipes,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchResponse &&
        other.page == page &&
        listEquals(other.tokens, tokens) &&
        listEquals(other.recipes, recipes);
  }

  @override
  int get hashCode => page.hashCode ^ tokens.hashCode ^ recipes.hashCode;
}
