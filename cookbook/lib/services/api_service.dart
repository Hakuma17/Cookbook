import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/recipe_detail.dart';
import '../models/comment.dart';
import '../models/cart_item.dart';
import '../models/cart_response.dart';
import '../models/cart_ingredient.dart';

/// ApiService: จัดการทุก API call กับ backend (PHP)
class ApiService {
  // ─── HTTP client & session ───────────────────────────────────────────────

  /// HTTP client เดียวสำหรับทุกคำขอ
  static final _client = http.Client();

  /// Timeout ระหว่างรอผลจาก server
  static const _timeout = Duration(seconds: 30);

  /// เก็บ PHPSESSID เมื่อ login สำเร็จ
  static String? _sessionCookie;

  /// Base URL ของ API (แก้พาธให้ตรงกับ deploy จริง)
  static String get baseUrl {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator default
      return 'http://10.0.2.2/cookbookapp/';
    }
    // iOS / Desktop
    return 'http://localhost/cookbookapp/';
  }

  // ─── Internal HTTP Helpers ───────────────────────────────────────────────

  /// เคลียร์ session cookie หลัง logout
  static void clearSession() {
    _sessionCookie = null;
  }

  /// GET ธรรมดา พร้อมแนบ session cookie (ถ้าเก็บไว้แล้ว)
  static Future<http.Response> _get(Uri uri) {
    final headers = <String, String>{};
    if (_sessionCookie != null) {
      headers['Cookie'] = 'PHPSESSID=$_sessionCookie';
    }
    return _client.get(uri, headers: headers).timeout(_timeout);
  }

  /// POST ธรรมดา พร้อมแนบ session cookie และจับ set-cookie เมื่อ login
  static Future<http.Response> _post(
      String path, Map<String, String> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{};
    if (_sessionCookie != null) {
      headers['Cookie'] = 'PHPSESSID=$_sessionCookie';
    }

    final resp =
        await _client.post(uri, headers: headers, body: body).timeout(_timeout);

    // ถ้ายังไม่มี session cookie ให้ลองอ่านจาก header
    if (_sessionCookie == null) {
      final raw = resp.headers['set-cookie'];
      if (raw != null) {
        final match = RegExp(r'PHPSESSID=([^;]+)').firstMatch(raw);
        if (match != null) {
          _sessionCookie = match.group(1);
        }
      }
    }
    return resp;
  }

  /// Wrapper สำหรับ GET ที่รับเป็น path
  static Future<http.Response> _getWithSession(String path) =>
      _get(Uri.parse('$baseUrl$path'));

  /// Wrapper สำหรับ POST ที่รับเป็น path
  static Future<http.Response> _postWithSession(
          String path, Map<String, String> body) =>
      _post(path, body);

  // ─── Data Endpoints ───────────────────────────────────────────────────────

  /// ดึงวัตถุดิบทั้งหมด
  static Future<List<Ingredient>> fetchIngredients() async {
    final resp = await _getWithSession('get_ingredients.php');
    if (resp.statusCode != 200) {
      throw Exception('ไม่สามารถโหลดวัตถุดิบได้');
    }
    final List jsonList = json.decode(resp.body);
    return jsonList.map((e) => Ingredient.fromJson(e)).toList();
  }

  /// ดึงสูตรยอดนิยม
  static Future<List<Recipe>> fetchPopularRecipes() async {
    final resp = await _getWithSession('get_popular_recipes.php');
    if (resp.statusCode != 200) {
      throw Exception('ไม่สามารถโหลดสูตรยอดนิยมได้');
    }
    final List jsonList = json.decode(resp.body);
    return jsonList.map((e) => Recipe.fromJson(e)).toList();
  }

  /// ดึงสูตรใหม่ล่าสุด
  static Future<List<Recipe>> fetchNewRecipes() async {
    final resp = await _getWithSession('get_new_recipes.php');
    if (resp.statusCode != 200) {
      throw Exception('ไม่สามารถโหลดสูตรใหม่ได้');
    }
    final List jsonList = json.decode(resp.body);
    return jsonList.map((e) => Recipe.fromJson(e)).toList();
  }

  /// ดึงรายละเอียดสูตร
  static Future<RecipeDetail> fetchRecipeDetail(int id) async {
    final resp = await _getWithSession('get_recipe_detail.php?id=$id');
    if (resp.statusCode != 200) {
      throw Exception('ไม่สามารถโหลดรายละเอียดสูตรได้');
    }
    final Map<String, dynamic> jsonMap = json.decode(resp.body);

    // รองรับกรณี backend ส่ง image_url เดียว
    if (jsonMap['image_urls'] == null && jsonMap['image_url'] != null) {
      jsonMap['image_urls'] = [jsonMap['image_url'].toString()];
    }
    // ค่า default servings ถ้าไม่ส่งมา
    jsonMap['current_servings'] ??= 1;

    return RecipeDetail.fromJson(jsonMap);
  }

  /// Alias เรียก fetchRecipeDetail
  static Future<RecipeDetail> getRecipeDetail(int id) => fetchRecipeDetail(id);

  // ─── Favorites & Ratings ─────────────────────────────────────────────────

  /// Toggle favorite สลับสถานะโปรด
  static Future<void> toggleFavorite(int recipeId, bool newStatus) async {
    final resp = await _postWithSession('toggle_favorite.php', {
      'recipe_id': recipeId.toString(),
      'favorite': newStatus ? '1' : '0',
    });
    if (resp.statusCode != 200) {
      throw Exception('ไม่สามารถเปลี่ยนสถานะโปรดได้');
    }
    final data = jsonDecode(resp.body);
    if (data['success'] != true && data['success'] != 'true') {
      throw Exception(data['message'] ?? 'เกิดข้อผิดพลาด');
    }
  }

  /// โพสต์เรตติ้งใหม่ แล้วคืน average_rating
  static Future<double> postRating(int recipeId, double rating) async {
    final result = await _postAndProcess('post_rating.php', {
      'recipe_id': recipeId.toString(),
      'rating': rating.toString(),
    });
    return (result['data']['average_rating'] as num).toDouble();
  }

  /// ดึงรายการโปรดของผู้ใช้
  static Future<List<Recipe>> fetchFavorites() async {
    final resp = await _getWithSession('get_user_favorites.php');
    if (resp.statusCode != 200) {
      throw Exception('ไม่สามารถโหลดสูตรโปรดได้');
    }
    final Map<String, dynamic> jsonMap = json.decode(resp.body);
    if (jsonMap['success'] != true) {
      throw Exception(jsonMap['message'] ?? 'เกิดข้อผิดพลาด');
    }
    final List data = jsonMap['data'];
    return data.map((e) => Recipe.fromJson(e)).toList();
  }

  // ─── Comments ─────────────────────────────────────────────────────────────

  /// ดึงความคิดเห็นทั้งหมดของสูตร
  static Future<List<Comment>> getComments(int recipeId) async {
    final resp = await _getWithSession('get_comments.php?id=$recipeId');
    if (resp.statusCode != 200) {
      throw Exception('ไม่สามารถโหลดความคิดเห็นได้');
    }
    final Map<String, dynamic> jsonMap = json.decode(resp.body);
    if (jsonMap['success'] != true) {
      throw Exception(jsonMap['message'] ?? 'เกิดข้อผิดพลาด');
    }
    final List dataList = jsonMap['data'] as List;
    return dataList.map((e) => Comment.fromJson(e)).toList();
  }

  /// โพสต์หรืออัปเดตรีวิว
  static Future<Comment> postComment(
      int recipeId, String text, double rating) async {
    final result = await _postAndProcess('post_comment.php', {
      'recipe_id': recipeId.toString(),
      'comment': text,
      'rating': rating.toStringAsFixed(1),
    });
    final data = result['data'];
    if (data == null) {
      throw Exception('ไม่สามารถโพสต์ความคิดเห็นได้');
    }
    return Comment.fromJson(data);
  }

  /// ลบความคิดเห็นของผู้ใช้
  static Future<void> deleteComment(int recipeId) async {
    final resp = await _postWithSession('delete_comment.php', {
      'recipe_id': recipeId.toString(),
    });
    if (resp.statusCode != 200) {
      throw Exception('ไม่สามารถลบความคิดเห็นได้');
    }
    final Map<String, dynamic> jsonMap = json.decode(resp.body);
    if (jsonMap['success'] != true && jsonMap['success'] != 'true') {
      throw Exception(jsonMap['message'] ?? 'เกิดข้อผิดพลาด');
    }
  }

  // ─── Cart ─────────────────────────────────────────────────────────────────

  /// อัปเดตจำนวนเสิร์ฟของสูตรในตะกร้า
  static Future<void> updateCart(int recipeId, double count) async {
    final resp = await _postWithSession('update_cart.php', {
      'recipe_id': recipeId.toString(),
      'nServings': count.toString(),
    });
    final Map<String, dynamic> jsonMap = jsonDecode(resp.body);
    if (jsonMap['success'] != true && jsonMap['success'] != 'true') {
      throw Exception(jsonMap['message'] ?? 'Unknown error');
    }
  }

  /// ดึงรายการเมนูในตะกร้า (List<CartItem>)
  static Future<List<CartItem>> fetchCartItems() async {
    final resp = await _getWithSession('get_cart_items.php');
    if (resp.statusCode != 200) {
      throw Exception('ไม่สามารถโหลดตะกร้าได้');
    }
    final Map<String, dynamic> jsonMap = json.decode(resp.body);
    if (jsonMap['success'] != true) {
      throw Exception(jsonMap['message'] ?? 'เกิดข้อผิดพลาด');
    }
    final List data = jsonMap['data'];
    return data.map((e) => CartItem.fromJson(e)).toList();
  }

  /// ดึงข้อมูลตะกร้า (รวมทั้ง count และ items) → คืนเป็น CartResponse
  static Future<CartResponse> fetchCartData() async {
    final resp = await _getWithSession('get_cart_items.php');
    if (resp.statusCode != 200) {
      throw Exception('ไม่สามารถโหลดตะกร้าได้');
    }
    final Map<String, dynamic> jsonMap = json.decode(resp.body);
    if (jsonMap['success'] != true) {
      throw Exception(jsonMap['message'] ?? 'เกิดข้อผิดพลาด');
    }

    // *** ปรับจุดอ่าน totalItems ให้ตรงกับ JSON ที่ backend ส่งมา ***
    final total = jsonMap['totalItems'] is num
        ? (jsonMap['totalItems'] as num).toInt()
        : int.tryParse(jsonMap['totalItems'].toString()) ?? 0;

    final List data = jsonMap['data'];
    final items = data.map((e) => CartItem.fromJson(e)).toList();

    return CartResponse(totalItems: total, items: items);
  }

  /// ล้างตะกร้าวัตถุดิบทั้งหมด
  static Future<void> clearCart() async {
    final resp = await _postWithSession('clear_cart.php', {});
    final Map<String, dynamic> jsonMap = json.decode(resp.body);
    if (jsonMap['success'] != true && jsonMap['success'] != 'true') {
      throw Exception(jsonMap['message'] ?? 'ไม่สามารถล้างตะกร้าได้');
    }
  }

  /// ดึงวัตถุดิบรวมในตะกร้า
  static Future<List<CartIngredient>> fetchCartIngredients() async {
    final resp = await _getWithSession('get_cart_ingredients.php');
    if (resp.statusCode != 200) {
      throw Exception('ไม่สามารถโหลดวัตถุดิบในตะกร้าได้');
    }
    final jsonMap = jsonDecode(resp.body);
    if (jsonMap['success'] != true) {
      throw Exception(jsonMap['message'] ?? 'เกิดข้อผิดพลาด');
    }
    final List list = jsonMap['data'] as List<dynamic>;
    return list.map((e) => CartIngredient.fromJson(e)).toList();
  }

  /// เพิ่มเมนูใหม่ลงตะกร้า
  static Future<void> addCartItem(int recipeId, double nServings) async {
    final resp = await _postWithSession('add_cart_item.php', {
      'recipe_id': recipeId.toString(),
      'nServings': nServings.toString(),
    });
    final Map<String, dynamic> jsonMap = jsonDecode(resp.body);
    if (jsonMap['success'] != true && jsonMap['success'] != 'true') {
      throw Exception(jsonMap['message'] ?? 'ไม่สามารถเพิ่มสูตรลงตะกร้าได้');
    }
  }

  /// ลบเมนูออกจากตะกร้า
  static Future<void> removeCartItem(int recipeId) async {
    final resp = await _postWithSession('remove_cart_item.php', {
      'recipe_id': recipeId.toString(),
    });
    final Map<String, dynamic> jsonMap = jsonDecode(resp.body);
    if (jsonMap['success'] != true && jsonMap['success'] != 'true') {
      throw Exception(jsonMap['message'] ?? 'ไม่สามารถลบสูตรจากตะกร้าได้');
    }
  }

  // ─── Auth / Password / OTP ────────────────────────────────────────────────

  /// ล็อกอิน email/password
  static Future<Map<String, dynamic>> login(String email, String password) =>
      _postAndProcess('login.php', {
        'email': email,
        'password': password,
      });

  /// ลงทะเบียน user ใหม่
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

  /// ขอ OTP (reset password)
  static Future<Map<String, dynamic>> sendOtp(String email) async {
    final uri = Uri.parse('${baseUrl}reset_password.php');
    final resp =
        await _client.post(uri, body: {'email': email}).timeout(_timeout);
    return _safeProcess(resp);
  }

  /// ยืนยัน OTP
  static Future<Map<String, dynamic>> verifyOtp(String email, String otp) =>
      _postAndProcess('verify_otp.php', {
        'email': email,
        'otp': otp,
      });

  /// รีเซตรหัสผ่านใหม่
  static Future<Map<String, dynamic>> resetPassword(
          String email, String otp, String newPassword) =>
      _postAndProcess('new_password.php', {
        'email': email,
        'otp': otp,
        'new_password': newPassword,
      });

  // ─── Internal Utilities ───────────────────────────────────────────────────

  /// POST แล้ว parse response เป็น Map {'success','message','data'}
  static Future<Map<String, dynamic>> _postAndProcess(
      String path, Map<String, String> body) async {
    final resp = await _post(path, body);
    return _safeProcess(resp);
  }

  /// ช่วย parse HTTP response body ให้อยู่ในรูป Map
  static Map<String, dynamic> _safeProcess(http.Response resp) {
    Map<String, dynamic>? jsonMap;
    try {
      jsonMap = jsonDecode(resp.body.trim());
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

  /// แปลงค่าต่างๆ ให้อยู่ใน boolean
  static bool _parseBool(dynamic val) {
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    if (val is num) return val != 0;
    return false;
  }
}
