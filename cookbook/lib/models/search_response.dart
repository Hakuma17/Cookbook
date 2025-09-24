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
    // [Compat] page
    final page = _toInt(json['page'] ?? json['current_page'], fallback: 1);

    // [Compat] tokens
    List<String> parseTokens(Map<String, dynamic> m) {
      if (m['tokens'] is List) return List<String>.from(m['tokens']);
      if (m['terms'] is List) return List<String>.from(m['terms']);
      if (m['data'] is Map) {
        final dm = m['data'] as Map;
        if (dm['tokens'] is List) return List<String>.from(dm['tokens']);
        if (dm['terms'] is List) return List<String>.from(dm['terms']);
      }
      return <String>[];
    }

    final tokens = parseTokens(json);

    // [Compat] items list can live in many places
    List<dynamic> parseItems(Map<String, dynamic> m) {
      if (m['data'] is List) return (m['data'] as List);
      if (m['recipes'] is List) return (m['recipes'] as List);
      if (m['items'] is List) return (m['items'] as List);
      if (m['results'] is List) return (m['results'] as List);
      if (m['data'] is Map) {
        final dm = m['data'] as Map;
        if (dm['items'] is List) return (dm['items'] as List);
        if (dm['recipes'] is List) return (dm['recipes'] as List);
        if (dm['rows'] is List) return (dm['rows'] as List);
        if (dm['list'] is List) return (dm['list'] as List);
      }
      if (m['payload'] is Map) {
        final p = m['payload'] as Map;
        if (p['items'] is List) return (p['items'] as List);
        if (p['recipes'] is List) return (p['recipes'] as List);
      }
      return const <dynamic>[];
    }

    final list = parseItems(json);

    // [Compat] total count keys can vary and be nested
    int? parseTotal(Map<String, dynamic> m) {
      dynamic raw = m['total'] ??
          m['total_count'] ??
          m['totalItems'] ??
          m['total_items'] ??
          m['count'] ??
          m['total_recipes'] ??
          m['recordsTotal'] ??
          m['totalRows'] ??
          m['total_rows'] ??
          m['total_results'] ??
          m['totalResults'];
      if (raw == null && m['meta'] is Map) {
        final meta = m['meta'] as Map;
        raw = meta['total'] ?? meta['total_count'] ?? meta['count'];
      }
      if (raw == null && m['pagination'] is Map) {
        final pg = m['pagination'] as Map;
        raw = pg['total'] ?? pg['total_count'] ?? pg['count'];
      }
      if (raw == null && m['data'] is Map) {
        final dm = m['data'] as Map;
        raw = dm['total'] ??
            dm['total_count'] ??
            dm['totalItems'] ??
            dm['total_items'] ??
            dm['count'] ??
            dm['recordsTotal'] ??
            dm['total_rows'];
      }
      if (raw == null && m['payload'] is Map) {
        final p = m['payload'] as Map;
        raw = p['total'] ?? p['count'] ?? p['total_count'];
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
