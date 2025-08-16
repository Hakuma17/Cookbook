// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';

import 'package:cookbook/services/auth_service.dart';

import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/recipe_detail.dart';
import '../models/comment.dart';
import '../models/cart_item.dart';
import '../models/cart_response.dart';
import '../models/cart_ingredient.dart';
import '../models/search_response.dart';
// ★★★ NEW: โมเดลการ์ดกลุ่ม
import '../models/ingredient_group.dart';

// ─────────────────────────────────────────────────────────────
// 1. Custom Exceptions
// ─────────────────────────────────────────────────────────────
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class UnauthorizedException extends ApiException {
  UnauthorizedException(String message) : super(message, statusCode: 401);
}

/// โครงสร้างผลลัพธ์ของการสลับเมนูโปรดจาก backend
class FavoriteToggleResult {
  final int recipeId;
  final bool isFavorited;
  final int favoriteCount;
  final int? totalUserFavorites;

  const FavoriteToggleResult({
    required this.recipeId,
    required this.isFavorited,
    required this.favoriteCount,
    this.totalUserFavorites,
  });

  factory FavoriteToggleResult.fromJson(dynamic json,
      {required int fallbackRecipeId}) {
    final Map d;
    if (json is Map && json['data'] is Map) {
      d = Map<String, dynamic>.from(json['data'] as Map);
    } else if (json is Map) {
      d = Map<String, dynamic>.from(json);
    } else {
      d = const {};
    }
    final rid = int.tryParse('${d['recipe_id'] ?? fallbackRecipeId}') ??
        fallbackRecipeId;
    final isFav = d['is_favorited'] == true || d['is_favorited'] == 1;
    final favCnt = int.tryParse('${d['favorite_count'] ?? 0}') ?? 0;
    final total = d['total_user_favorites'] == null
        ? null
        : int.tryParse('${d['total_user_favorites']}');
    return FavoriteToggleResult(
      recipeId: rid,
      isFavorited: isFav,
      favoriteCount: favCnt,
      totalUserFavorites: total,
    );
  }
}

/// จัดการทุก API call กับ backend
class ApiService {
  /* ───── http & session ───── */
  static final _client = http.Client();
  static const _timeout = Duration(seconds: 30);
  static late final String baseUrl;

  /// init() – กำหนด baseUrl ตามแพลตฟอร์ม
  static Future<void> init() async {
    if (kIsWeb) {
      baseUrl = 'http://localhost/cookbookapp/';
    } else if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      baseUrl = info.isPhysicalDevice
          ? 'http://192.168.137.1/cookbookapp/' // ✨ เปลี่ยนได้ตาม LAN/Hotspot ที่ใช้จริง
          : 'http://10.0.2.2/cookbookapp/'; // Emulator
    } else {
      baseUrl = 'http://localhost/cookbookapp/';
    }
  }

  // ✨ NEW: Helper รวมศูนย์ ทำ URL ให้เป็น absolute + แก้ localhost → host ของ base
  static String normalizeUrl(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return '';

    Uri base;
    try {
      base = Uri.parse(baseUrl);
    } catch (_) {
      return v;
    }

    Uri u;
    try {
      u = Uri.parse(v);
    } catch (_) {
      return v;
    }

    // 1) relative → absolute
    if (!u.hasScheme) {
      final p = v.startsWith('/') ? v.substring(1) : v;
      u = base.resolve(p);
    }

    // 2) localhost → base.host (รองรับ Android Emulator)
    final isLocalHost =
        (u.host == 'localhost' || u.host == '127.0.0.1' || u.host == '::1');
    if (isLocalHost) {
      u = u.replace(host: base.host, port: base.hasPort ? base.port : null);
    }

    return u.toString();
  }

  /* ───── cookie & header helper ───── */
  static Future<void> clearSession() async => AuthService.clearToken();

  static Future<void> _captureCookie(http.BaseResponse r) async {
    final raw = r.headers['set-cookie'];
    final m = raw == null ? null : RegExp(r'PHPSESSID=([^;]+)').firstMatch(raw);
    if (m != null) {
      await AuthService.saveToken(m.group(1)!);
    }
  }

  static Future<Map<String, String>> _headers({bool json = false}) async {
    final token = await AuthService.getToken();
    return {
      if (json)
        'Content-Type': 'application/json'
      else
        'Content-Type': 'application/x-www-form-urlencoded',
      'Accept': 'application/json',
      if (token != null) 'Cookie': 'PHPSESSID=$token',
    };
  }

  /* ───── low-level GET / POST ───── */

  static Future<http.Response> _get(Uri uri, {bool public = false}) async {
    final headers = await _headers();
    if (public) headers.remove('Cookie');
    final r = await _client.get(uri, headers: headers).timeout(_timeout);
    await _captureCookie(r);
    if (r.statusCode >= 300) _throwHttp('GET ${uri.path}', r);
    return r;
  }

  // ★★★ CHANGED: _post/_postAndProcess/_processResponse/_throwHttp
  // เพิ่ม flag map401ToUnauthorized (ค่าเริ่มต้น = true)
  // เพื่อรองรับ public endpoints (login/register/otp/reset password)
  // ที่ backend อาจตอบ 401 เพื่อบอก “ข้อมูลไม่ถูกต้อง”
  // โดยไม่ควรถูกตีความว่า “Session หมดอายุ”
  static Future<http.Response> _post(
    String path,
    Map<String, String> body, {
    bool map401ToUnauthorized = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final r = await _client
        .post(uri, headers: await _headers(), body: body)
        .timeout(_timeout);
    await _captureCookie(r);
    if (r.statusCode >= 300) {
      _throwHttp('POST $path', r, map401ToUnauthorized: map401ToUnauthorized);
    }
    return r;
  }

  static Future<dynamic> _postAndProcess(
    String p,
    Map<String, String> b, {
    bool map401ToUnauthorized = true,
  }) async {
    final response =
        await _post(p, b, map401ToUnauthorized: map401ToUnauthorized);
    return _processResponse(response,
        map401ToUnauthorized: map401ToUnauthorized);
  }

  /* ───── Response & Error Processing ───── */
  static dynamic _processResponse(
    http.Response r, {
    bool map401ToUnauthorized = true,
  }) {
    try {
      final parsed = jsonDecode(r.body.trim());

      // ★ จุดเปลี่ยน: ให้ปิดการแมป 401 → UnauthorizedException ได้
      if (map401ToUnauthorized && r.statusCode == 401) {
        throw UnauthorizedException('Session หมดอายุ กรุณาเข้าสู่ระบบใหม่');
      }

      if (parsed is Map<String, dynamic>) {
        final code = parsed['status'] ?? parsed['code'];
        if (map401ToUnauthorized && (code == 401 || code == '401')) {
          throw UnauthorizedException('Session หมดอายุ กรุณาเข้าสู่ระบบใหม่');
        }
        if (parsed['success'] == false) {
          throw ApiException(parsed['message'] ?? 'เกิดข้อผิดพลาดจาก Server',
              statusCode: r.statusCode);
        }
      }

      return parsed; // อนุญาตให้เป็น List/primitive ได้
    } on FormatException {
      throw ApiException('ไม่สามารถประมวลผลข้อมูลจาก Server ได้',
          statusCode: r.statusCode);
    }
  }

  static Never _throwHttp(
    String what,
    http.Response r, {
    bool map401ToUnauthorized = true,
  }) {
    if (map401ToUnauthorized && r.statusCode == 401) {
      throw UnauthorizedException('Session หมดอายุ กรุณาเข้าสู่ระบบใหม่ (401)');
    }
    try {
      final json = jsonDecode(r.body);
      if (json is Map && json['message'] != null) {
        throw ApiException(json['message'], statusCode: r.statusCode);
      }
    } catch (_) {}
    throw ApiException('$what ผิดพลาด', statusCode: r.statusCode);
  }

  /* ───── helpers: multi query/array ───── */

  /// [NEW] สร้าง URI ที่รองรับ query แบบ array (เช่น include_groups[0]=…)
  /// ใช้ index แทน include_groups[] เพื่อหลบข้อจำกัดของ Uri.replace ที่ไม่รองรับ key ซ้ำ
  static Uri _buildUriWithMulti(
    String path, {
    Map<String, String> single = const {},
    Map<String, List<String>> multi = const {},
  }) {
    final parts = <String>[];
    // single
    single.forEach((k, v) {
      if (v.isEmpty) return;
      parts
          .add('${Uri.encodeQueryComponent(k)}=${Uri.encodeQueryComponent(v)}');
    });
    // multi with [index]
    multi.forEach((k, list) {
      for (var i = 0; i < list.length; i++) {
        final key = '$k[$i]';
        final val = list[i];
        if (val.trim().isEmpty) continue;
        parts.add(
            '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(val)}');
      }
    });
    final qs = parts.join('&');
    final url = '$baseUrl$path${qs.isNotEmpty ? '?$qs' : ''}';
    return Uri.parse(url);
  }

  /* |------------------------------------------------------------------
  | Public API Endpoints
  |------------------------------------------------------------------ */

  // ───────── INGREDIENTS ─────────
  static Future<List<Ingredient>> fetchIngredients() async {
    final r = await _get(Uri.parse('${baseUrl}get_ingredients.php'),
        public: !await AuthService.isLoggedIn());
    final json = _processResponse(r);
    final list = json is Map
        ? (json['data'] ?? json['ingredients'] ?? [])
        : (json is List ? json : []);
    if (list is! List) throw ApiException('รูปแบบข้อมูลวัตถุดิบไม่ถูกต้อง');
    assert(() {
      if (list.isEmpty) {
        debugPrint('[ApiService] fetchIngredients() returned empty list.');
      }
      return true;
    }());
    return list.map((e) => Ingredient.fromJson(e)).toList();
  }

  /// [NEW] ดึง “กลุ่มวัตถุดิบ” สำหรับหน้า Home
  static Future<List<IngredientGroup>> fetchIngredientGroups() async {
    try {
      final r = await _get(Uri.parse('${baseUrl}get_ingredient_groups.php'),
          public: !await AuthService.isLoggedIn());
      final j = _processResponse(r);

      // ✨ รองรับได้ทั้ง 2 รูปแบบ: 1) [{...}] 2) { groups:[...] } / { data:[...] }
      List raw = const [];
      if (j is List) {
        raw = j;
      } else if (j is Map) {
        final any = j['groups'] ?? j['data'] ?? j['items'] ?? j['list'];
        if (any is List) raw = any;
      }
      return raw.map((e) => IngredientGroup.fromJson(e)).toList();
    } on ApiException catch (e) {
      // fallback: โหมด grouped ในไฟล์เดิม
      if (e.statusCode != null && e.statusCode! >= 400) {
        final r2 = await _get(
            Uri.parse('${baseUrl}get_ingredients.php?grouped=1'),
            public: !await AuthService.isLoggedIn());
        final j2 = _processResponse(r2);

        List raw = const [];
        if (j2 is List) {
          raw = j2;
        } else if (j2 is Map) {
          final any = j2['groups'] ?? j2['data'] ?? j2['items'] ?? j2['list'];
          if (any is List) raw = any;
        }
        return raw.map((e) => IngredientGroup.fromJson(e)).toList();
      }
      rethrow;
    }
  }

  // ───────── RECIPES (feeds) ─────────
  static Future<List<Recipe>> fetchPopularRecipes() async {
    final r = await _get(Uri.parse('${baseUrl}get_popular_recipes.php'),
        public: !await AuthService.isLoggedIn());
    final json = _processResponse(r);
    final list = json is Map ? (json['data'] as List) : (json as List);
    return list.map((e) => Recipe.fromJson(e)).toList();
  }

  static Future<List<Recipe>> fetchNewRecipes() async {
    final r = await _get(Uri.parse('${baseUrl}get_new_recipes.php'),
        public: !await AuthService.isLoggedIn());
    final json = _processResponse(r);
    final list = json is Map ? (json['data'] as List) : (json as List);
    return list.map((e) => Recipe.fromJson(e)).toList();
  }

  static Future<RecipeDetail> fetchRecipeDetail(int id) async {
    final r = await _get(Uri.parse('${baseUrl}get_recipe_detail.php?id=$id'));
    final json = _processResponse(r);
    return RecipeDetail.fromJson(
        (json is Map ? json['data'] : json) as Map<String, dynamic>);
  }

  /// toggleFavorite คืนผลจริงจาก backend
  static Future<FavoriteToggleResult> toggleFavorite(
      int recipeId, bool fav) async {
    final json = await _postAndProcess('toggle_favorite.php', {
      'recipe_id': recipeId.toString(),
      'favorite': fav ? '1' : '0',
    });
    return FavoriteToggleResult.fromJson(json, fallbackRecipeId: recipeId);
  }

  // ───────── COMMENT ─────────
  static Future<Comment> postComment(
      int recipeId, String text, double rating) async {
    // ✨ NOTE: backend บางตัวใช้ INT 1–5 ถ้าอยากชัวร์สามารถ round ก่อนส่งได้
    final res = await _postAndProcess('post_comment.php', {
      'recipe_id': recipeId.toString(),
      'comment': text,
      'rating': rating.toStringAsFixed(1),
    });
    return Comment.fromJson(
        (res is Map && res['data'] is Map) ? res['data'] : (res as Map));
  }

  static Future<void> deleteComment(int recipeId) async {
    await _postAndProcess('delete_comment.php', {'recipe_id': '$recipeId'});
  }

  // ───────── AUTH ─────────
  static Future<Map<String, dynamic>> login(String email, String pwd) async {
    final r = await _client.post(Uri.parse('${baseUrl}login.php'),
        headers: await _headers(),
        body: {'email': email, 'password': pwd}).timeout(_timeout);
    await _captureCookie(r);
    // ★ login: ไม่แมป 401 → UnauthorizedException (ให้เป็น ApiException ตาม message)
    final j = _processResponse(r, map401ToUnauthorized: false);
    return (j is Map<String, dynamic>) ? j : <String, dynamic>{'data': j};
  }

  static Future<Map<String, dynamic>> register(
      String email, String pwd, String cPwd, String name) async {
    // ★ register: public endpoint → ปิดการแมป 401
    final r = await _post(
        'register.php',
        {
          'email': email,
          'password': pwd,
          'confirm_password': cPwd,
          'username': name,
        },
        map401ToUnauthorized: false);
    final j = _processResponse(r, map401ToUnauthorized: false);
    return (j is Map<String, dynamic>) ? j : <String, dynamic>{'data': j};
  }

  static Future<Map<String, dynamic>> googleSignIn(String idToken) async {
    final r = await _client.post(Uri.parse('${baseUrl}google_login.php'),
        headers: await _headers(),
        body: {'id_token': idToken}).timeout(_timeout);
    await _captureCookie(r);
    // ★ public-ish: ปิดการแมป 401
    final j = _processResponse(r, map401ToUnauthorized: false);
    return (j is Map<String, dynamic>) ? j : <String, dynamic>{'data': j};
  }

  // ───────── OTP / PASSWORD ─────────
  static Future<Map<String, dynamic>> sendOtp(String email) async {
    // ★ public: ปิดการแมป 401 เพื่อให้ข้อความ backend โชว์ตรงไปตรงมา
    final r = await _post('reset_password.php', {'email': email},
        map401ToUnauthorized: false);
    final j = _processResponse(r, map401ToUnauthorized: false);
    return (j is Map<String, dynamic>) ? j : <String, dynamic>{'data': j};
  }

  static Future<Map<String, dynamic>> resendOtp(String email) async {
    final r = await _post('resend_otp.php', {'email': email},
        map401ToUnauthorized: false);
    final j = _processResponse(r, map401ToUnauthorized: false);
    return (j is Map<String, dynamic>) ? j : <String, dynamic>{'data': j};
  }

  static Future<Map<String, dynamic>> verifyOtp(
      String email, String otp) async {
    // ★★ ทางเลือก B: verify_otp.php จะตอบกลับ reset_token
    //    { success:true, reset_token:"..." } หรือ { data:{ reset_token:"..." } }
    final r = await _post('verify_otp.php', {'email': email, 'otp': otp},
        map401ToUnauthorized: false);
    final j = _processResponse(r, map401ToUnauthorized: false);

    // ★★★ Normalize: ดึง reset_token มาวางไว้ระดับบนสุดเสมอ
    if (j is Map<String, dynamic>) {
      final data = j['data'];
      if (j['reset_token'] == null &&
          data is Map<String, dynamic> &&
          data['reset_token'] != null) {
        j['reset_token'] = data['reset_token'];
      }
      return j;
    }
    return <String, dynamic>{'data': j};
  }

  static Future<Map<String, dynamic>> changePassword(
      String oldP, String newP) async {
    final r = await _post(
        'change_password.php', {'old_password': oldP, 'new_password': newP});
    final j = _processResponse(r);
    return (j is Map<String, dynamic>) ? j : <String, dynamic>{'data': j};
  }

  // ★★★ CHANGED: resetPassword – เพื่อรองรับ “ทางเลือก B”
  //    - พารามิเตอร์ตัวที่ 2 (ชื่อเดิม otp) ตอนนี้ตีความเป็น **reset_token**
  //    - ส่งให้ backend เป็น field ชื่อ 'reset_token' (ไม่ใช่ 'otp')
  //    - ปิดการแมป 401 → เพื่อไม่ให้ขึ้นว่า Session หมดอายุเวลา token ไม่ถูกต้อง
  static Future<Map<String, dynamic>> resetPassword(
      String email, String otpOrToken, String newP) async {
    final r = await _post(
        'new_password.php',
        {
          'email': email,
          'reset_token': otpOrToken, // ⬅️ เปลี่ยนจาก 'otp' → 'reset_token'
          'new_password': newP,
        },
        map401ToUnauthorized: false);
    final j = _processResponse(r, map401ToUnauthorized: false);
    return (j is Map<String, dynamic>) ? j : <String, dynamic>{'data': j};
  }

  /// multipart upload profile image
  static Future<String> uploadProfileImage(File img) async {
    final req = http.MultipartRequest(
        'POST', Uri.parse('${baseUrl}upload_profile_image.php'));
    final headers = await _headers();
    headers.remove('Content-Type'); // อย่าทับ boundary ของ multipart
    req.headers.addAll(headers);
    req.files.add(await http.MultipartFile.fromPath('profile_image', img.path));
    final streamed = await req.send().timeout(_timeout);
    final resp = await http.Response.fromStream(streamed);
    await _captureCookie(resp);
    final json = _processResponse(resp);
    // ✨ กรณี backend ให้ทั้ง absolute/relative ให้รองรับได้ทั้งสอง
    final path = (json is Map && json['data'] is Map)
        ? (json['data']['relative_path'] ?? json['data']['image_url'])
        : null;
    if (path is! String || path.isEmpty) {
      throw ApiException('ไม่พบ path ของรูปภาพที่อัปโหลด');
    }
    return path;
  }

  static Future<Map<String, dynamic>> updateProfile(
      {required String profileName, required String imageUrl}) async {
    final r = await _client
        .post(Uri.parse('${baseUrl}update_profile.php'),
            headers: await _headers(json: true),
            body: jsonEncode(
                {'profile_name': profileName, 'profile_image': imageUrl}))
        .timeout(_timeout);
    await _captureCookie(r);

    final json = _processResponse(r);
    return (json is Map && json['data'] is Map<String, dynamic>)
        ? json['data']
        : {};
  }

  // ───────── SEARCH ─────────
  static Future<SearchResponse> searchRecipes({
    String query = '',
    int page = 1,
    int limit = 26,
    String sort = 'latest',
    List<String>? ingredientNames,
    List<String>? excludeIngredientNames,
    bool? tokenize, // NEW
    String? group, // NEW
    // [NEW] เปลี่ยนชื่อให้สอดคล้องกับ SearchScreen
    List<String>? includeGroupNames,
    List<String>? excludeGroupNames,
    int? catId,
  }) async {
    // single params
    final singles = <String, String>{
      'page': '$page',
      'limit': '$limit',
      'sort': sort,
      'tokenize': (tokenize ?? false) ? '1' : '0',
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (catId != null) 'cat_id': '$catId',
      if (group?.trim().isNotEmpty ?? false) 'group': group!.trim(),
      if (ingredientNames?.isNotEmpty ?? false)
        'include': ingredientNames!.join(','),
      if (excludeIngredientNames?.isNotEmpty ?? false)
        'exclude': excludeIngredientNames!.join(','),
    };

    // multi params (array)
    final multi = <String, List<String>>{
      if ((includeGroupNames?.isNotEmpty ?? false))
        'include_groups': includeGroupNames!,
      if ((excludeGroupNames?.isNotEmpty ?? false))
        'exclude_groups': excludeGroupNames!,
    };

    // [NEW] ใช้ตัวช่วยที่สร้าง query แบบ include_groups[0]=A&include_groups[1]=B
    final uri = _buildUriWithMulti(
      'search_recipes_unified.php',
      single: singles,
      multi: multi,
    );

    final r = await _get(uri);
    final json = _processResponse(r);
    return SearchResponse.fromJson(json);
  }

  /// [NEW] ดึงสูตรจาก “ชื่อกลุ่ม” โดยตรง (ใช้ endpoint ใหม่ ถ้ามี; fallback ไป unified)
  static Future<List<Recipe>> fetchRecipesByGroup({
    required String group,
    int page = 1,
    int limit = 26,
    String sort = 'latest',
  }) async {
    try {
      final uri = _buildUriWithMulti(
        'get_recipes_by_group.php',
        single: {
          'group': group,
          'page': '$page',
          'limit': '$limit',
          'sort': sort,
        },
      );
      final r = await _get(uri);
      final j = _processResponse(r);
      final list = j is Map ? (j['data'] as List) : (j as List);
      return list.map((e) => Recipe.fromJson(e)).toList();
    } on ApiException catch (e) {
      // fallback ไป unified ถ้า endpoint ไม่มี
      if (e.statusCode != null && e.statusCode! >= 400) {
        final res = await searchRecipes(
            group: group, page: page, limit: limit, sort: sort);
        return res.recipes;
      }
      rethrow;
    }
  }

  static Future<List<String>> getRecipeSuggestions(String pattern,
      {bool withMeta = false}) async {
    if (pattern.isEmpty) return [];
    try {
      final uri = Uri.parse('${baseUrl}get_recipe_suggestions.php').replace(
          queryParameters: {'q': pattern, if (withMeta) 'with_meta': '1'});
      final r = await _get(uri);
      final parsed = _processResponse(r);

      if (withMeta) {
        if (parsed is List) {
          return parsed
              .map((e) =>
                  e is Map ? (e['name']?.toString() ?? '') : e.toString())
              .where((s) => s.isNotEmpty)
              .toList();
        }
      } else {
        if (parsed is List) return List<String>.from(parsed);
      }
    } catch (_) {}
    return [];
  }

  static Future<List<String>> getIngredientSuggestions(String pattern) async {
    if (pattern.isEmpty) return [];
    try {
      final r = await _get(Uri.parse(
          '${baseUrl}get_ingredient_suggestions.php?term=${Uri.encodeComponent(pattern)}'));
      final json = _processResponse(r);
      if (json is Map && json['data'] is List) {
        return List<String>.from(json['data']);
      }
      if (json is List) return List<String>.from(json);
    } catch (_) {}
    return [];
  }

  /// [CHANGED] Suggest “ชื่อกลุ่มวัตถุดิบ” → ชี้ไป get_group_suggestions.php
  /// - ส่ง q, contains=1 (ค้นแบบ contains) และ limit (เช่น 15)
  /// - รองรับทั้งรูปแบบ {data:[...]} และ {items:[{group_name,recipe_count}]}
  static Future<List<String>> getGroupSuggestions(String pattern) async {
    if (pattern.isEmpty) return [];
    try {
      final uri = Uri.parse('${baseUrl}get_group_suggestions.php').replace(
        queryParameters: {
          'q': pattern,
          'contains': '1', // [NEW] ให้ค้นแบบ contains
          'limit': '15',
        },
      );
      final r = await _get(uri, public: !await AuthService.isLoggedIn());
      final j = _processResponse(r);

      if (j is Map) {
        if (j['data'] is List) {
          return List<String>.from(j['data']);
        }
        if (j['items'] is List) {
          return (j['items'] as List)
              .map((e) => e is Map
                  ? (e['group_name'] ?? e['group'] ?? e['catagorynew'] ?? '')
                  : e.toString())
              .where((s) => s.toString().trim().isNotEmpty)
              .cast<String>()
              .toList();
        }
      }
      if (j is List) return List<String>.from(j);
    } catch (_) {}
    return [];
  }

  // ───────── FAVORITES / COMMENTS ─────────
  static Future<List<Recipe>> fetchFavorites() async {
    final r = await _get(Uri.parse('${baseUrl}get_user_favorites.php'));
    final json = _processResponse(r);
    final list = json is Map ? (json['data'] as List) : (json as List);
    return list.map((e) => Recipe.fromJson(e)).toList();
  }

  static Future<List<Comment>> getComments(int recipeId) async {
    final r = await _get(Uri.parse('${baseUrl}get_comments.php?id=$recipeId'));
    final json = _processResponse(r);
    final list = json is Map ? (json['data'] as List) : (json as List);
    return list.map((e) => Comment.fromJson(e)).toList();
  }

  /// ใช้เช็คสถานะหัวใจรวดเร็ว ไม่ต้อง deserialize Recipe ทั้งก้อน
  static Future<List<int>> fetchFavoriteIds() async {
    final uri = Uri.parse('${baseUrl}get_user_favorites.php')
        .replace(queryParameters: {'only_ids': '1'});
    final r = await _get(uri);
    final json = _processResponse(r);

    // 1) กรณีได้ { data: [1,2,3] }
    final data = (json is Map) ? json['data'] : json;
    if (data is List) {
      final ids = data
          .map((e) {
            if (e is int) return e;
            if (e is String) return int.tryParse(e);
            if (e is Map) {
              final v = e['id'] ?? e['recipe_id'];
              return v == null ? null : int.tryParse(v.toString());
            }
            return null;
          })
          .whereType<int>()
          .where((i) => i > 0)
          .toList();
      return ids;
    }

    // 2) เผื่อบางเวอร์ชันส่ง { ids:[...] } / { favorite_ids:[...] } / { favorites:[...] }
    final alt = (json is Map)
        ? (json['ids'] ?? json['favorite_ids'] ?? json['favorites'])
        : null;
    if (alt is List) {
      return alt
          .map((v) => int.tryParse(v.toString()))
          .whereType<int>()
          .where((i) => i > 0)
          .toList();
    }

    return <int>[];
  }

  // ───────── CART ─────────
  static Future<void> updateCart(int recipeId, double count) async {
    await _postAndProcess('update_cart.php', {
      'recipe_id': '$recipeId',
      'nServings': '$count',
    });
  }

  static Future<CartResponse> fetchCartData() async {
    final r = await _get(Uri.parse('${baseUrl}get_cart_items.php'));
    final json = _processResponse(r);
    return CartResponse.fromJson(json);
  }

  static Future<void> clearCart() async {
    await _postAndProcess('clear_cart.php', {});
  }

  static Future<List<CartIngredient>> fetchCartIngredients() async {
    final r = await _get(Uri.parse('${baseUrl}get_cart_ingredients.php'));
    final json = _processResponse(r);
    final list = json is Map ? (json['data'] as List) : (json as List);
    return list.map((e) => CartIngredient.fromJson(e)).toList();
  }

  static Future<void> addCartItem(int id, double n) async {
    await _postAndProcess(
        'add_cart_item.php', {'recipe_id': '$id', 'nServings': '$n'});
  }

  static Future<void> removeCartItem(int id) async {
    await _postAndProcess('remove_cart_item.php', {'recipe_id': '$id'});
  }

  // ───────── ALLERGY ─────────
  static Future<List<Ingredient>> fetchAllergyIngredients() async {
    if (!await AuthService.isLoggedIn()) return [];
    final r = await _get(Uri.parse('${baseUrl}get_allergy_list.php'));
    final json = _processResponse(r);
    final list = json is Map ? (json['data'] as List) : (json as List);
    return list.map((e) => Ingredient.fromJson(e)).toList();
  }

  /// [NEW] ดึงสรุป “กลุ่มที่แพ้” จาก get_allergy_list.php
  static Future<List<Map<String, dynamic>>> fetchAllergyGroups() async {
    if (!await AuthService.isLoggedIn()) return [];
    final r = await _get(Uri.parse('${baseUrl}get_allergy_list.php'));
    final j = _processResponse(r);
    final List groups =
        (j is Map && j['groups'] is List) ? j['groups'] : <dynamic>[];
    // คืนเป็น Map ง่าย ๆ: {group_name, representative_ingredient_id}
    return groups
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<void> addAllergy(int id) async {
    await _postAndProcess(
        'manage_allergy.php', {'action': 'add', 'ingredient_id': '$id'});
  }

  static Future<void> removeAllergy(int id) async {
    await _postAndProcess(
        'manage_allergy.php', {'action': 'remove', 'ingredient_id': '$id'});
  }

  /// [NEW] เพิ่ม “ทั้งกลุ่ม”
  static Future<void> addAllergyGroup(List<int> ingredientIds) async {
    if (ingredientIds.isEmpty) return;
    final body = <String, String>{'action': 'add', 'mode': 'group'};
    for (var i = 0; i < ingredientIds.length; i++) {
      body['ingredient_ids[$i]'] = '${ingredientIds[i]}';
    }
    await _postAndProcess('manage_allergy.php', body);
  }

  /// [NEW] ลบ “ทั้งกลุ่ม”
  static Future<void> removeAllergyGroup(List<int> ingredientIds) async {
    if (ingredientIds.isEmpty) return;
    final body = <String, String>{'action': 'remove', 'mode': 'group'};
    for (var i = 0; i < ingredientIds.length; i++) {
      body['ingredient_ids[$i]'] = '${ingredientIds[i]}';
    }
    await _postAndProcess('manage_allergy.php', body);
  }

  // ───────── LOGOUT ─────────
  static Future<void> logout() async {
    try {
      await _post('logout.php', {});
    } catch (_) {}
    await clearSession();
  }
}
