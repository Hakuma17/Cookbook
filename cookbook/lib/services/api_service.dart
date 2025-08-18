// lib/services/api_service.dart
// รวมทุกการเรียก API + จัดการคุกกี้/เฮดเดอร์/เออเรอร์

import 'dart:convert'; // แปลง JSON
import 'dart:io'; // ตรวจแพลตฟอร์ม
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
import '../models/ingredient_group.dart'; // โมเดลกลุ่มวัตถุดิบ

// ─────────────────────────────────────────────────────────────
// 1) Exceptions แบบกำหนดเอง
// ─────────────────────────────────────────────────────────────
class ApiException implements Exception {
  final String message;

  /// ใช้ชื่อนี้ให้ตรงกับที่ส่วนอื่น ๆ ของแอปรู้จัก
  final int? statusCode;

  /// เก็บ errorCode (เช่น OTP_EXPIRED / RATE_LIMIT) ถ้า BE ส่งมา
  final String? code;

  /// แนบ payload ดิบไว้เผื่อ debug
  final Map<String, dynamic>? data;

  ApiException(this.message, {this.statusCode, this.code, this.data});

  @override
  String toString() => message;
}

class UnauthorizedException extends ApiException {
  UnauthorizedException(String message)
      : super(message, statusCode: 401, code: 'UNAUTHORIZED');
}

// ผลลัพธ์ toggle favorite (โครงสร้างตอบกลับ)
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

  // แปลง JSON → FavoriteToggleResult (ยืดหยุ่นกับรูปแบบ data)
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

// ─────────────────────────────────────────────────────────────
// 2) Service หลักรวมทุก API
// ─────────────────────────────────────────────────────────────
class ApiService {
  /* ─── http & session ─── */
  static final _client = http.Client(); // คลไคลเอนต์ HTTP
  static const _timeout = Duration(seconds: 30); // ไทม์เอาต์รวม
  static late final String baseUrl; // โคน URL ของเซิร์ฟเวอร์

  /// init() – กำหนด baseUrl ตามแพลตฟอร์ม (Android/Emulator/Web)
  static Future<void> init() async {
    if (kIsWeb) {
      baseUrl = 'http://localhost/cookbookapp/';
    } else if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      baseUrl = info.isPhysicalDevice
          ? 'http://192.168.137.1/cookbookapp/' // เครื่องจริงผ่าน LAN/Hotspot
          : 'http://10.0.2.2/cookbookapp/'; // Android Emulator
    } else {
      baseUrl = 'http://localhost/cookbookapp/';
    }
  }

  // helper: ทำ URL ให้เป็น absolute + แทน localhost ด้วย host ของ base (กันปัญหา emulator)
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

    // relative → absolute
    if (!u.hasScheme) {
      final p = v.startsWith('/') ? v.substring(1) : v;
      u = base.resolve(p);
    }

    // แก้ host localhost → host ของ base
    final isLocalHost =
        (u.host == 'localhost' || u.host == '127.0.0.1' || u.host == '::1');
    if (isLocalHost) {
      u = u.replace(host: base.host, port: base.hasPort ? base.port : null);
    }
    return u.toString();
  }

  /* ─── cookie & headers ─── */
  static Future<void> clearSession() async =>
      AuthService.clearToken(); // เคลียร์ token

  // ดึงค่า PHPSESSID จาก Set-Cookie แล้วเก็บไว้ (persist session)
  static Future<void> _captureCookie(http.BaseResponse r) async {
    final raw = r.headers['set-cookie'];
    final m = raw == null ? null : RegExp(r'PHPSESSID=([^;]+)').firstMatch(raw);
    if (m != null) {
      await AuthService.saveToken(m.group(1)!);
    }
  }

  // เฮดเดอร์มาตรฐาน (แนบ Cookie ถ้ามี)
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

  /* ─── low-level GET / POST ─── */

  // GET พื้นฐาน (public=true จะตัด Cookie ออก)
  static Future<http.Response> _get(Uri uri, {bool public = false}) async {
    final headers = await _headers();
    if (public) headers.remove('Cookie');
    final r = await _client.get(uri, headers: headers).timeout(_timeout);
    await _captureCookie(r);
    if (r.statusCode >= 300) _throwHttp('GET ${uri.path}', r);
    return r;
  }

  // POST พื้นฐาน + ตัวเลือก map401ToUnauthorized (ป้องกันตีความผิดใน public endpoints)
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

  // สั้น: POST แล้ว parse ต่อเลย (strict)
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

  /// ★★★ Lenient POST: สำหรับ OTP endpoints
  /// - ยอมรับโค้ด 4xx บางประเภทแล้ว "คืน JSON" ให้ FE แสดงผลเอง
  /// - ใช้กรณีต้องโชว์ error จำเพาะ (OTP_EXPIRED / RATE_LIMIT ฯลฯ)
  static Future<Map<String, dynamic>> _postLenient(
    String path,
    Map<String, String> body, {
    Set<int> okStatuses = const {200, 400, 401, 403, 404, 410, 422, 423, 429},
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final r = await _client
        .post(uri, headers: await _headers(), body: body)
        .timeout(_timeout);
    await _captureCookie(r);

    Map<String, dynamic>? json;
    try {
      json = (jsonDecode(r.body) as Map?)?.cast<String, dynamic>();
    } catch (_) {
      json = null;
    }

    if (okStatuses.contains(r.statusCode) && json != null) {
      // แนบสถานะไว้ใน payload เผื่อจออยากใช้
      json.putIfAbsent('_httpStatus', () => r.statusCode);
      return json;
    }

    // กรณีอื่น โยนรวม แต่ยังพยายามดึง message/errorCode จาก body
    final msg = (json?['message'] ??
            (json?['errors'] is List && (json!['errors'] as List).isNotEmpty
                ? (json['errors'] as List).join('\n')
                : 'POST $path ผิดพลาด'))
        .toString();
    final code = json?['errorCode']?.toString();
    throw ApiException(msg, statusCode: r.statusCode, code: code, data: json);
  }

  /* ─── Response & Error Processing ─── */

  // ตัวช่วยดึงข้อความจาก backend (message หรือ errors[])
  static String _serverMsg(dynamic parsed, http.Response r) {
    if (parsed is Map<String, dynamic>) {
      final m = parsed['message'];
      if (m is String && m.trim().isNotEmpty) return m.trim();
      final errs = parsed['errors'];
      if (errs is List && errs.isNotEmpty) {
        return errs.map((e) => e.toString()).join('\n');
      }
    }
    return 'เกิดข้อผิดพลาดจาก Server (HTTP ${r.statusCode})';
  }

  // แปลง/ตรวจ response จาก server (รองรับปิดการแมป 401)
  static dynamic _processResponse(
    http.Response r, {
    bool map401ToUnauthorized = true,
  }) {
    try {
      final parsed = jsonDecode(r.body.trim());

      // แมป 401 → Unauthorized เฉพาะกรณีต้องการ
      if (map401ToUnauthorized && r.statusCode == 401) {
        throw UnauthorizedException('Session หมดอายุ กรุณาเข้าสู่ระบบใหม่');
      }

      if (parsed is Map<String, dynamic>) {
        final code = parsed['status'] ?? parsed['code'];
        if (map401ToUnauthorized && (code == 401 || code == '401')) {
          throw UnauthorizedException('Session หมดอายุ กรุณาเข้าสู่ระบบใหม่');
        }
        if (parsed['success'] == false) {
          throw ApiException(
            _serverMsg(parsed, r),
            statusCode: r.statusCode,
            code: parsed['errorCode']?.toString(),
            data: parsed,
          );
        }
      }
      return parsed; // อนุญาตให้เป็น List/primitive ได้
    } on FormatException {
      throw ApiException('ไม่สามารถประมวลผลข้อมูลจาก Server ได้',
          statusCode: r.statusCode);
    }
  }

  // โยนข้อผิดพลาดเมื่อ HTTP code >= 300 (พยายามอ่าน message ก่อน)
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
      if (json is Map) {
        // ลองอ่าน message / errors จาก body + แนบ errorCode
        final msg = json['message'] ??
            ((json['errors'] is List && (json['errors'] as List).isNotEmpty)
                ? (json['errors'] as List).join('\n')
                : null);
        if (msg != null) {
          throw ApiException(msg.toString(),
              statusCode: r.statusCode,
              code: json['errorCode']?.toString(),
              data: json.cast<String, dynamic>());
        }
      }
    } catch (_) {}
    throw ApiException('$what ผิดพลาด', statusCode: r.statusCode);
  }

  /* ─── helpers: สร้าง URI ที่มี array query ─── */

  // รองรับ include_groups[0]=A&include_groups[1]=B
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
    // multi ด้วย index
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
  | Public API Endpoints (ฟังก์ชันเรียกใช้งานจริง)
  |------------------------------------------------------------------ */

  // ───────── INGREDIENTS ─────────
  static Future<List<Ingredient>> fetchIngredients() async {
    final r = await _get(Uri.parse('${baseUrl}get_ingredients.php'),
        public: !await AuthService.isLoggedIn()); // ถ้ายังไม่ล็อกอิน → public
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

  // กลุ่มวัตถุดิบ (รองรับหลายรูปแบบ data)
  static Future<List<IngredientGroup>> fetchIngredientGroups() async {
    try {
      final r = await _get(Uri.parse('${baseUrl}get_ingredient_groups.php'),
          public: !await AuthService.isLoggedIn());
      final j = _processResponse(r);

      List raw = const [];
      if (j is List) {
        raw = j;
      } else if (j is Map) {
        final any = j['groups'] ?? j['data'] ?? j['items'] ?? j['list'];
        if (any is List) raw = any;
      }
      return raw.map((e) => IngredientGroup.fromJson(e)).toList();
    } on ApiException catch (e) {
      // ถ้า endpoint ไม่มี/พัง → fallback ไป grouped ใน get_ingredients.php
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

  // toggle favorite (ส่งค่า true/false)
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
    // หมายเหตุ: บาง backend ใช้ INT 1–5 → ถ้าจะชัวร์อาจปัดเป็น .0
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
    // login: ปิดแมป 401 เพื่อให้ข้อความผิด/ถูกจาก backend โชว์ตรง
    final j = _processResponse(r, map401ToUnauthorized: false);
    return (j is Map<String, dynamic>) ? j : <String, dynamic>{'data': j};
  }

  static Future<Map<String, dynamic>> register(
      String email, String pwd, String cPwd, String name) async {
    // register: public endpoint → ปิดการแมป 401
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
    // public-ish: ปิดแมป 401 เช่นกัน
    final j = _processResponse(r, map401ToUnauthorized: false);
    return (j is Map<String, dynamic>) ? j : <String, dynamic>{'data': j};
  }

  // ───────── OTP / PASSWORD ─────────

  static Future<Map<String, dynamic>> sendOtp(String email) async {
    // ลืมรหัสผ่าน: public → ปิดแมป 401 (ยัง strict ได้)
    final r = await _post('reset_password.php', {'email': email},
        map401ToUnauthorized: false);
    final j = _processResponse(r, map401ToUnauthorized: false);
    return (j is Map<String, dynamic>) ? j : <String, dynamic>{'data': j};
  }

  /// ★ ใช้ lenient เพื่อให้ FE อ่าน errorCode/secondsLeft ได้
  static Future<Map<String, dynamic>> resendOtp(String email) async {
    return _postLenient('resend_otp.php', {'email': email});
  }

  /// ★ ใช้ lenient เพื่อให้ FE แสดงข้อความจำเพาะ (OTP_EXPIRED/INCORRECT/LOCKED)
  static Future<Map<String, dynamic>> verifyOtp(
      String email, String otp) async {
    final j =
        await _postLenient('verify_otp.php', {'email': email, 'otp': otp});

    // Normalize reset_token ให้อยู่ระดับบนสุดเสมอ (รองรับโฟลว์ลืมรหัสผ่าน)
    if (j['reset_token'] == null &&
        j['data'] is Map<String, dynamic> &&
        (j['data'] as Map<String, dynamic>)['reset_token'] != null) {
      j['reset_token'] = (j['data'] as Map<String, dynamic>)['reset_token'];
    }
    return j;
  }

  static Future<Map<String, dynamic>> changePassword(
      String oldP, String newP) async {
    final r = await _post(
        'change_password.php', {'old_password': oldP, 'new_password': newP});
    final j = _processResponse(r);
    return (j is Map<String, dynamic>) ? j : <String, dynamic>{'data': j};
  }

  // resetPassword: ใช้ reset_token (ไม่ใช่ otp) + ปิดแมป 401
  static Future<Map<String, dynamic>> resetPassword(
      String email, String otpOrToken, String newP) async {
    final r = await _post(
        'new_password.php',
        {
          'email': email,
          'reset_token': otpOrToken, // ชื่อฟิลด์ให้ตรงฝั่ง BE
          'new_password': newP,
        },
        map401ToUnauthorized: false);
    final j = _processResponse(r, map401ToUnauthorized: false);
    return (j is Map<String, dynamic>) ? j : <String, dynamic>{'data': j};
  }

  /// อัปโหลดรูปโปรไฟล์ (multipart)
  static Future<String> uploadProfileImage(File img) async {
    final req = http.MultipartRequest(
        'POST', Uri.parse('${baseUrl}upload_profile_image.php'));
    final headers = await _headers();
    headers.remove('Content-Type'); // ห้ามทับ boundary ของ multipart
    req.headers.addAll(headers);
    req.files.add(await http.MultipartFile.fromPath('profile_image', img.path));
    final streamed = await req.send().timeout(_timeout);
    final resp = await http.Response.fromStream(streamed);
    await _captureCookie(resp);
    final json = _processResponse(resp);
    // รองรับทั้ง relative/absolute path
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
    bool? tokenize, // เปิดโหมดตัดคำ
    String? group, // ค้นตามกลุ่ม
    List<String>? includeGroupNames,
    List<String>? excludeGroupNames,
    int? catId,
  }) async {
    // พารามิเตอร์เดี่ยว
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

    // พารามิเตอร์แบบ array
    final multi = <String, List<String>>{
      if ((includeGroupNames?.isNotEmpty ?? false))
        'include_groups': includeGroupNames!,
      if ((excludeGroupNames?.isNotEmpty ?? false))
        'exclude_groups': excludeGroupNames!,
    };

    // สร้าง URI ที่รองรับ [index]
    final uri = _buildUriWithMulti(
      'search_recipes_unified.php',
      single: singles,
      multi: multi,
    );

    final r = await _get(uri);
    final json = _processResponse(r);
    return SearchResponse.fromJson(json);
  }

  // ดึงสูตรตามชื่อกลุ่ม (ถ้า endpoint ไม่มี → fallback ไป unified)
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
      // endpoint ไม่มี/ไม่พร้อม → ใช้ unified แทน
      if (e.statusCode != null && e.statusCode! >= 400) {
        final res = await searchRecipes(
            group: group, page: page, limit: limit, sort: sort);
        return res.recipes;
      }
      rethrow;
    }
  }

  // suggest ชื่อสูตร
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

  // suggest วัตถุดิบ
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

  // suggest ชื่อกลุ่มวัตถุดิบ
  static Future<List<String>> getGroupSuggestions(String pattern) async {
    if (pattern.isEmpty) return [];
    try {
      final uri = Uri.parse('${baseUrl}get_group_suggestions.php').replace(
        queryParameters: {
          'q': pattern,
          'contains': '1', // ค้นแบบ contains
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

  // map รายชื่อวัตถุดิบ → ชื่อกลุ่ม (fallback GET ถ้า POST พัง)
  static Future<List<String>> mapIngredientsToGroups(List<String> names) async {
    final list = names
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (list.isEmpty) return <String>[];

    // แปลง response → List<String>
    List<String> _parseGroups(dynamic j) {
      List<String> out = [];

      if (j is Map) {
        if (j['groups'] is List) {
          out = (j['groups'] as List).map((e) => e.toString()).toList();
        } else if (j['data'] is List) {
          out = (j['data'] as List).map((e) => e.toString()).toList();
        } else if (j['items'] is List) {
          out = (j['items'] as List)
              .map((e) => e is Map
                  ? (e['group_name'] ??
                          e['group'] ??
                          e['catagorynew'] ??
                          e['name'] ??
                          '')
                      .toString()
                  : e.toString())
              .where((s) => s.trim().isNotEmpty)
              .cast<String>()
              .toList();
        }
      } else if (j is List) {
        out = j.map((e) => e.toString()).toList();
      }

      // unique + trim
      final seen = <String>{};
      final cleaned = <String>[];
      for (final g in out) {
        final s = g.trim();
        if (s.isEmpty) continue;
        if (seen.add(s)) cleaned.add(s);
      }
      return cleaned;
    }

    // สร้าง body names[0], names[1], ...
    final body = <String, String>{};
    for (var i = 0; i < list.length; i++) {
      body['names[$i]'] = list[i];
    }

    // 1) POST ก่อน
    try {
      final resp = await _post('map_ingredients_to_groups.php', body,
          map401ToUnauthorized: false); // public ไม่แมป 401
      final json = _processResponse(resp, map401ToUnauthorized: false);
      final groups = _parseGroups(json);
      if (groups.isNotEmpty) return groups;
    } catch (_) {
      // ไป GET ต่อ
    }

    // 2) GET fallback (?names[0]=...&names[1]=...)
    try {
      final uri = _buildUriWithMulti('map_ingredients_to_groups.php',
          multi: {'names': list});
      final r = await _get(uri, public: !await AuthService.isLoggedIn());
      final j = _processResponse(r);
      return _parseGroups(j);
    } catch (_) {
      return <String>[]; // พังทั้งหมด → คืนลิสต์ว่าง
    }
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

  // ดึงเฉพาะ id สูตรที่เป็น favorite (เบา/เร็ว)
  static Future<List<int>> fetchFavoriteIds() async {
    final uri = Uri.parse('${baseUrl}get_user_favorites.php')
        .replace(queryParameters: {'only_ids': '1'});
    final r = await _get(uri);
    final json = _processResponse(r);

    // รูปแบบ { data: [1,2,3] }
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

    // เผื่อรูปแบบอื่น ๆ
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

  // ดึงกลุ่มที่แพ้ (ถ้ามี)
  static Future<List<Map<String, dynamic>>> fetchAllergyGroups() async {
    if (!await AuthService.isLoggedIn()) return [];
    final r = await _get(Uri.parse('${baseUrl}get_allergy_list.php'));
    final j = _processResponse(r);
    final List groups =
        (j is Map && j['groups'] is List) ? j['groups'] : <dynamic>[];
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

  // เพิ่มทั้งกลุ่ม
  static Future<void> addAllergyGroup(List<int> ingredientIds) async {
    if (ingredientIds.isEmpty) return;
    final body = <String, String>{'action': 'add', 'mode': 'group'};
    for (var i = 0; i < ingredientIds.length; i++) {
      body['ingredient_ids[$i]'] = '${ingredientIds[i]}';
    }
    await _postAndProcess('manage_allergy.php', body);
  }

  // ลบทั้งกลุ่ม
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
      await _post('logout.php', {}); // แจ้งเซิร์ฟเวอร์ให้เคลียร์เซสชัน
    } catch (_) {}
    await clearSession(); // เคลียร์ token ฝั่งแอปเสมอ
  }
}
