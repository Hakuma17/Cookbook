import 'package:flutter/foundation.dart';
import 'recipe.dart';

//   1. เพิ่ม Helper functions เพื่อการ Parse ที่ปลอดภัยและสอดคล้องกับ Model อื่นๆ
int _toInt(dynamic v, {int fallback = 1}) {
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
    this.total,
  });

  /// หน้า (เริ่มที่ 1) ที่ backend ส่งกลับ
  final int page;

  /// รายการ token ที่ backend ตัดคำมาแล้ว
  ///  – ถ้า backend ไม่ส่งมา จะเป็น []
  final List<String> tokens;

  /// รายการสูตรอาหารในหน้าปัจจุบัน
  final List<Recipe> recipes;

  /// จำนวนผลลัพธ์ทั้งหมด (ถ้ามี)
  ///  – ถ้า backend ไม่ส่งมา จะเป็น null
  final int? total;

  ///   2. เพิ่ม factory constructor สำหรับสร้าง Object จาก JSON
  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    // [Compat] บางเวอร์ชันอาจใช้ key 'current_page'
    final page = _toInt(json['page'] ?? json['current_page'], fallback: 1);

    // [Compat] เผื่อ backend ใช้ชื่ออื่น เช่น 'terms'
    final tokens = (json['tokens'] is List)
        ? List<String>.from(json['tokens'])
        : (json['terms'] is List)
            ? List<String>.from(json['terms'])
            : <String>[];

    // [Compat] data vs recipes
    final list = (json['data'] is List)
        ? (json['data'] as List)
        : (json['recipes'] is List)
            ? (json['recipes'] as List)
            : const <dynamic>[];

    // [Compat] total count keys can vary
    int? parseTotal(Map<String, dynamic> m) {
      dynamic raw = m['total'] ??
          m['total_count'] ??
          m['count'] ??
          m['totalItems'] ??
          m['total_recipes'];
      if (raw == null && m['meta'] is Map) {
        final meta = m['meta'] as Map;
        raw = meta['total'] ?? meta['total_count'] ?? meta['count'];
      }
      if (raw == null && m['pagination'] is Map) {
        final pg = m['pagination'] as Map;
        raw = pg['total'] ?? pg['total_count'] ?? pg['count'];
      }
      if (raw == null) return null;
      if (raw is int) return raw;
      return int.tryParse(raw.toString());
    }

    final total = parseTotal(json);

    return SearchResponse(
      page: page,
      tokens: tokens,
      recipes: list
          .map((e) => Recipe.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      total: total,
    );
  }

  ///   3. เพิ่มเมธอดมาตรฐานสำหรับ Immutable class
  SearchResponse copyWith({
    int? page,
    List<String>? token,
    List<Recipe>? recipes,
    int? total,
  }) {
    return SearchResponse(
      page: page ?? this.page,
      // [OLD] tokens: tokens ?? this.tokens,
      // ↑ แอบพิมพ์ผิดในเวอร์ชันก่อน (token) → แก้ให้ถูกต้อง
      tokens: token ?? tokens,
      recipes: recipes ?? this.recipes,
      total: total ?? this.total,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchResponse &&
        other.page == page &&
        listEquals(other.tokens, tokens) &&
        listEquals(other.recipes, recipes) &&
        other.total == total;
  }

  @override
  int get hashCode =>
      page.hashCode ^
      tokens.hashCode ^
      recipes.hashCode ^
      (total ?? 0).hashCode;
}
