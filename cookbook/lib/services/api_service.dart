import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/recipe_detail.dart';
import '../models/comment.dart';

class ApiService {
  static final _client = http.Client();
  static const _timeout = Duration(seconds: 30);

  // ── เก็บ PHPSESSID หลังล็อกอินสำเร็จ ──────────────────────────────────
  static String? _sessionCookie;

  /// Base URL สำหรับเรียก PHP
  /// - Android emulator ใช้ 10.0.2.2
  /// - iOS หรือ Desktop ใช้ localhost
  static String get baseUrl {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2/cookbookapp/';
    }
    return 'http://localhost/cookbookapp/';
  }

  // ── Internal helpers for GET/POST with cookie ───────────────────────────

  /// ใช้แทน _client.get() เพื่อแนบ Cookie header ถ้ามี
  static Future<http.Response> _get(Uri uri) {
    final headers = <String, String>{};
    if (_sessionCookie != null) headers['Cookie'] = _sessionCookie!;
    return _client.get(uri, headers: headers).timeout(_timeout);
  }

  /// ใช้แทน _client.post() เพื่อแนบ Cookie header ถ้ามี
  /// และจับ Set-Cookie หลังล็อกอิน/ลงทะเบียน
  static Future<http.Response> _post(
      String path, Map<String, String> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{};
    if (_sessionCookie != null) headers['Cookie'] = _sessionCookie!;
    final resp =
        await _client.post(uri, headers: headers, body: body).timeout(_timeout);

    // ถ้านี่ยังไม่มี session cookie ให้เก็บจาก header
    if (_sessionCookie == null) {
      final raw = resp.headers['set-cookie'];
      if (raw != null) {
        // ตัดเอาแค่ "PHPSESSID=xxx"
        _sessionCookie = raw.split(';').first;
      }
    }
    return resp;
  }

  // ── Data Endpoints ───────────────────────────────────────────────────────

  /// ดึงวัตถุดิบทั้งหมด (List<Ingredient>)
  static Future<List<Ingredient>> fetchIngredients() async {
    final resp = await _get(Uri.parse('${baseUrl}get_ingredients.php'));
    if (resp.statusCode != 200) {
      throw Exception('ไม่สามารถโหลดวัตถุดิบได้');
    }
    final List jsonList = json.decode(resp.body);
    return jsonList
        .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// ดึงสูตรยอดนิยม (List<Recipe>)
  static Future<List<Recipe>> fetchPopularRecipes() async {
    final resp = await _get(Uri.parse('${baseUrl}get_popular_recipes.php'));
    if (resp.statusCode != 200) {
      throw Exception('ไม่สามารถโหลดสูตรยอดนิยมได้');
    }
    final List jsonList = json.decode(resp.body);
    return jsonList
        .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// ดึงสูตรอัปเดตใหม่ (List<Recipe>)
  static Future<List<Recipe>> fetchNewRecipes() async {
    final resp = await _get(Uri.parse('${baseUrl}get_new_recipes.php'));
    if (resp.statusCode != 200) {
      throw Exception('ไม่สามารถโหลดสูตรใหม่ได้');
    }
    final List jsonList = json.decode(resp.body);
    return jsonList
        .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Recipe Detail ────────────────────────────────────────────────────────

  /// ดึงรายละเอียดสูตรอาหาร (RecipeDetail)
  static Future<RecipeDetail> fetchRecipeDetail(int id) async {
    final resp =
        await _get(Uri.parse('${baseUrl}get_recipe_detail.php?id=$id'));
    if (resp.statusCode != 200) {
      throw Exception('ไม่สามารถโหลดรายละเอียดสูตรได้');
    }

    final Map<String, dynamic> jsonMap =
        json.decode(resp.body) as Map<String, dynamic>;

    // ** fallback**: ถ้า API ยังส่งแค่ 'image_url' เดียวมา ให้ห่อเป็น List
    if (jsonMap['image_urls'] == null && jsonMap['image_url'] != null) {
      jsonMap['image_urls'] = [jsonMap['image_url'].toString()];
    }
    // เช็คว่ามี current_servings มั้ย ถ้าไม่ให้ default = 1
    jsonMap['current_servings'] ??= 1;

    return RecipeDetail.fromJson(jsonMap);
  }

  /// alias ให้โค้ดเก่าเรียก getRecipeDetail ได้
  static Future<RecipeDetail> getRecipeDetail(int id) => fetchRecipeDetail(id);

  // ── Favorite & Rating ───────────────────────────────────────────────────

  /// สลับสถานะโปรด (เพิ่ม/ลบ)
  static Future<void> toggleFavorite(int recipeId, bool newStatus) async {
    final resp = await _post('toggle_favorite.php', {
      'recipe_id': recipeId.toString(),
      'favorite': newStatus ? '1' : '0',
    });
    if (resp.statusCode != 200) {
      throw Exception('ไม่สามารถเปลี่ยนสถานะโปรดได้');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['success'] != true && data['success'] != 'true') {
      throw Exception(data['message'] ?? 'เกิดข้อผิดพลาด');
    }
  }

  /// ส่งคะแนนดาว → คืน average ใหม่
  static Future<double> postRating(int recipeId, double rating) async {
    final result = await _postAndProcess('post_rating.php', {
      'recipe_id': recipeId.toString(),
      'rating': rating.toString(),
    });
    return (result['data']['average_rating'] as num).toDouble();
  }

  // ── Comments ──────────────────────────────────────────────────────────────

  /// ดึงความคิดเห็นทั้งหมด
  static Future<List<Comment>> getComments(int recipeId) async {
    final resp =
        await _get(Uri.parse('${baseUrl}get_comments.php?id=$recipeId'));
    if (resp.statusCode != 200) {
      throw Exception('ไม่สามารถโหลดความคิดเห็นได้');
    }
    final List jsonList = json.decode(resp.body);
    return jsonList
        .map((e) => Comment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// ส่งความคิดเห็นใหม่ → คืน Comment ที่สร้าง
  static Future<Comment> postComment(
      int recipeId, String text, double rating) async {
    final result = await _postAndProcess('post_comment.php', {
      'recipe_id': recipeId.toString(),
      'comment': text,
      'rating': rating.toString(),
    });
    return Comment.fromJson(result['data'] as Map<String, dynamic>);
  }

  // ── Cart ───────────────────────────────────────────────────────────────────

  /// เพิ่มหรืออัปเดตตะกร้า (nServings)
  static Future<void> updateCart(int recipeId, int count) async {
    final resp = await _post('update_cart.php', {
      'recipe_id': recipeId.toString(),
      'count': count.toString(),
    });
    if (resp.statusCode != 200) {
      throw Exception('Server error: ${resp.statusCode}');
    }
    final Map<String, dynamic> jsonMap =
        jsonDecode(resp.body) as Map<String, dynamic>;
    if (jsonMap['success'] != true && jsonMap['success'] != 'true') {
      throw Exception(jsonMap['message'] ?? 'Unknown error');
    }
  }

  // ── Auth / Password Reset / Helpers ────────────────────────────────────────

  /// ล็อกอินด้วย Email/Password
  static Future<Map<String, dynamic>> login(String email, String password) =>
      _postAndProcess('login.php', {
        'email': email,
        'password': password,
      });

  /// ลงทะเบียน
  static Future<Map<String, dynamic>> register(
          String email, String password, String confirmPassword) =>
      _postAndProcess('register.php', {
        'email': email,
        'password': password,
        'confirm_password': confirmPassword,
      });

  /// Google Sign-In
  static Future<Map<String, dynamic>> googleSignIn(String idToken) =>
      _postAndProcess('google_login.php', {
        'id_token': idToken,
      });

  /// ส่ง OTP
  static Future<Map<String, dynamic>> sendOtp(String email) async {
    final uri = Uri.parse('${baseUrl}reset_password.php');
    final resp =
        await _client.post(uri, body: {'email': email}).timeout(_timeout);
    return _safeProcess(resp);
  }

  static Future<Map<String, dynamic>> verifyOtp(
          String email, String otp) async =>
      _postAndProcess('verify_otp.php', {
        'email': email,
        'otp': otp,
      });

  static Future<Map<String, dynamic>> resetPassword(
          String email, String otp, String newPassword) async =>
      _postAndProcess('new_password.php', {
        'email': email,
        'otp': otp,
        'new_password': newPassword,
      });

  // ── Internal Helpers ───────────────────────────────────────────────────────

  static Map<String, dynamic> _safeProcess(http.Response resp) {
    Map<String, dynamic>? jsonMap;
    try {
      jsonMap = jsonDecode(resp.body.trim()) as Map<String, dynamic>?;
    } catch (_) {
      jsonMap = null;
    }
    final bool success = jsonMap != null
        ? (_parseBool(jsonMap['success']) ||
            _parseBool(jsonMap['valid'] ?? false))
        : false;
    final String message = jsonMap?['message'] ??
        (success ? 'สำเร็จ' : 'เกิดข้อผิดพลาด (${resp.statusCode})');

    return {
      'success': success,
      'message': message,
      'data': jsonMap?['data'] ?? jsonMap,
    };
  }

  static Future<Map<String, dynamic>> _postAndProcess(
      String path, Map<String, String> body) async {
    final resp = await _post(path, body);
    return _safeProcess(resp);
  }

  static bool _parseBool(dynamic val) {
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    if (val is num) return val != 0;
    return false;
  }
}
