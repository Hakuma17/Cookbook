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

/// จัดการทุก API call กับ backend
class ApiService {
  /* ───── http & session ───── */
  static final _client = http.Client();
  static const _timeout = Duration(seconds: 30);
  static late final String baseUrl;

  /// ✅ 1. init() – กำหนด baseUrl ตามแพลตฟอร์ม
  static Future<void> init() async {
    if (kIsWeb) {
      baseUrl = 'http://localhost/cookbookapp/';
    } else if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      baseUrl = info.isPhysicalDevice
          ? 'http://192.168.137.1/cookbookapp/'
          : 'http://10.0.2.2/cookbookapp/';
    } else {
      baseUrl = 'http://localhost/cookbookapp/';
    }
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
    // ⭐️ always attach Accept header; remove Cookie if public
    final headers = await _headers();
    if (public) headers.remove('Cookie');
    final r = await _client.get(uri, headers: headers).timeout(_timeout);
    await _captureCookie(r);
    if (r.statusCode >= 300) _throwHttp('GET ${uri.path}', r);
    return r;
  }

  static Future<http.Response> _post(
      String path, Map<String, String> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final r = await _client
        .post(uri, headers: await _headers(), body: body)
        .timeout(_timeout);
    await _captureCookie(r);
    if (r.statusCode >= 300) _throwHttp('POST $path', r);
    return r;
  }

  static Future<dynamic> _postAndProcess(
      String p, Map<String, String> b) async {
    final response = await _post(p, b);
    return _processResponse(response);
  }

  /* ───── Response & Error Processing ───── */
  static dynamic _processResponse(http.Response r) {
    try {
      final json = jsonDecode(r.body.trim());
      if (r.statusCode == 401 ||
          json?['status'] == 401 ||
          json?['code'] == 401) {
        throw UnauthorizedException('Session หมดอายุ กรุณาเข้าสู่ระบบใหม่');
      }
      if (json?['success'] == false) {
        throw ApiException(json?['message'] ?? 'เกิดข้อผิดพลาดจาก Server',
            statusCode: r.statusCode);
      }
      return json;
    } on FormatException {
      throw ApiException('ไม่สามารถประมวลผลข้อมูลจาก Server ได้',
          statusCode: r.statusCode);
    }
  }

  static Never _throwHttp(String what, http.Response r) {
    if (r.statusCode == 401) {
      throw UnauthorizedException('Session หมดอายุ กรุณาเข้าสู่ระบบใหม่ (401)');
    }
    try {
      final json = jsonDecode(r.body);
      if (json['message'] != null) {
        throw ApiException(json['message'], statusCode: r.statusCode);
      }
    } catch (_) {}
    throw ApiException('$what ผิดพลาด', statusCode: r.statusCode);
  }

  /* |------------------------------------------------------------------
  | Public API Endpoints
  |------------------------------------------------------------------ */

  // ───────── INGREDIENTS ─────────
  static Future<List<Ingredient>> fetchIngredients() async {
    final r = await _get(Uri.parse('${baseUrl}get_ingredients.php'),
        public: !await AuthService.isLoggedIn());
    final json = _processResponse(r);

    // ⭐️ backend refactor support: "data" || "ingredients"
    final list = json['data'] ?? json['ingredients'] ?? [];
    if (list is! List) {
      throw ApiException('รูปแบบข้อมูลวัตถุดิบไม่ถูกต้อง');
    }

    // 🔍 dev log เมื่อได้ list ว่าง (ช่วยดีบัก)
    assert(() {
      if (list.isEmpty) {
        debugPrint('[ApiService] ⚠️ fetchIngredients() returned empty list.');
      }
      return true;
    }());

    return list.map((e) => Ingredient.fromJson(e)).toList();
  }

  // ───────── RECIPES ─────────
  static Future<List<Recipe>> fetchPopularRecipes() async {
    final r = await _get(Uri.parse('${baseUrl}get_popular_recipes.php'),
        public: !await AuthService.isLoggedIn());
    final json = _processResponse(r);
    return (json['data'] as List).map((e) => Recipe.fromJson(e)).toList();
  }

  static Future<List<Recipe>> fetchNewRecipes() async {
    final r = await _get(Uri.parse('${baseUrl}get_new_recipes.php'),
        public: !await AuthService.isLoggedIn());
    final json = _processResponse(r);
    return (json['data'] as List).map((e) => Recipe.fromJson(e)).toList();
  }

  static Future<RecipeDetail> fetchRecipeDetail(int id) async {
    final r = await _get(Uri.parse('${baseUrl}get_recipe_detail.php?id=$id'));
    final json = _processResponse(r);
    return RecipeDetail.fromJson(json['data'] as Map<String, dynamic>);
  }

  static Future<void> toggleFavorite(int recipeId, bool fav) async {
    await _postAndProcess('toggle_favorite.php', {
      'recipe_id': recipeId.toString(),
      'favorite': fav ? '1' : '0',
    });
  }

  // ───────── COMMENT ─────────
  static Future<Comment> postComment(
      int recipeId, String text, double rating) async {
    final res = await _postAndProcess('post_comment.php', {
      'recipe_id': recipeId.toString(),
      'comment': text,
      'rating': rating.toStringAsFixed(1),
    });
    return Comment.fromJson(res['data']);
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
    return jsonDecode(r.body);
  }

  static Future<Map<String, dynamic>> register(
      String email, String pwd, String cPwd, String name) async {
    final r = await _post('register.php', {
      'email': email,
      'password': pwd,
      'confirm_password': cPwd,
      'username': name,
    });
    return jsonDecode(r.body);
  }

  static Future<Map<String, dynamic>> googleSignIn(String idToken) async {
    final r = await _client.post(Uri.parse('${baseUrl}google_login.php'),
        headers: await _headers(),
        body: {'id_token': idToken}).timeout(_timeout);
    await _captureCookie(r);
    return jsonDecode(r.body);
  }

  // ───────── OTP / PASSWORD ─────────
  static Future<Map<String, dynamic>> sendOtp(String email) async {
    final r = await _post('reset_password.php', {'email': email});
    return jsonDecode(r.body);
  }

  static Future<Map<String, dynamic>> resendOtp(String email) async {
    final r = await _post('resend_otp.php', {'email': email});
    return jsonDecode(r.body);
  }

  static Future<Map<String, dynamic>> verifyOtp(
      String email, String otp) async {
    final r = await _post('verify_otp.php', {'email': email, 'otp': otp});
    return jsonDecode(r.body);
  }

  static Future<Map<String, dynamic>> changePassword(
      String oldP, String newP) async {
    final r = await _post(
        'change_password.php', {'old_password': oldP, 'new_password': newP});
    return jsonDecode(r.body);
  }

  static Future<Map<String, dynamic>> resetPassword(
      String email, String otp, String newP) async {
    final r = await _post(
        'new_password.php', {'email': email, 'otp': otp, 'new_password': newP});
    return jsonDecode(r.body);
  }

  static Future<String> uploadProfileImage(File img) async {
    final req = http.MultipartRequest(
        'POST', Uri.parse('${baseUrl}upload_profile_image.php'))
      ..headers.addAll(await _headers())
      ..files.add(await http.MultipartFile.fromPath('profile_image', img.path));

    final streamed = await req.send().timeout(_timeout);
    final resp = await http.Response.fromStream(streamed);
    await _captureCookie(resp);

    final json = _processResponse(resp);
    final path = json['data']?['relative_path'];
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
    return (json['data'] is Map<String, dynamic>) ? json['data'] : {};
  }

  // ───────── SEARCH ─────────
  static Future<SearchResponse> searchRecipes({
    String query = '',
    int page = 1,
    int limit = 26,
    String sort = 'latest',
    List<String>? ingredientNames,
    List<String>? excludeIngredientNames,
  }) async {
    final qp = <String, String>{
      'page': '$page',
      'limit': '$limit',
      'sort': sort,
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (ingredientNames?.isNotEmpty ?? false)
        'include': ingredientNames!.join(','),
      if (excludeIngredientNames?.isNotEmpty ?? false)
        'exclude': excludeIngredientNames!.join(','),
    };

    final uri = Uri.parse('${baseUrl}search_recipes_unified.php')
        .replace(queryParameters: qp);

    final r = await _get(uri);
    final json = _processResponse(r);
    return SearchResponse.fromJson(json);
  }

  static Future<List<String>> getRecipeSuggestions(String pattern) async {
    if (pattern.isEmpty) return [];
    try {
      final r = await _get(Uri.parse(
          '${baseUrl}get_recipe_suggestions.php?q=${Uri.encodeComponent(pattern)}'));
      final list = jsonDecode(r.body);
      if (list is List) return List<String>.from(list);
    } catch (_) {}
    return [];
  }

  static Future<List<String>> getIngredientSuggestions(String pattern) async {
    if (pattern.isEmpty) return [];
    try {
      final r = await _get(Uri.parse(
          '${baseUrl}get_ingredient_suggestions.php?term=${Uri.encodeComponent(pattern)}'));
      final json = _processResponse(r);
      if (json['data'] is List) {
        return List<String>.from(json['data']);
      }
    } catch (_) {}
    return [];
  }

  // ───────── FAVORITES / COMMENTS ─────────
  static Future<List<Recipe>> fetchFavorites() async {
    final r = await _get(Uri.parse('${baseUrl}get_user_favorites.php'));
    final json = _processResponse(r);
    return (json['data'] as List).map((e) => Recipe.fromJson(e)).toList();
  }

  static Future<List<Comment>> getComments(int recipeId) async {
    final r = await _get(Uri.parse('${baseUrl}get_comments.php?id=$recipeId'));
    final json = _processResponse(r);
    return (json['data'] as List).map((e) => Comment.fromJson(e)).toList();
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
    return (json['data'] as List)
        .map((e) => CartIngredient.fromJson(e))
        .toList();
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
    return (json['data'] as List).map((e) => Ingredient.fromJson(e)).toList();
  }

  static Future<void> addAllergy(int id) async {
    await _postAndProcess(
        'manage_allergy.php', {'action': 'add', 'ingredient_id': '$id'});
  }

  static Future<void> removeAllergy(int id) async {
    await _postAndProcess(
        'manage_allergy.php', {'action': 'remove', 'ingredient_id': '$id'});
  }

  // ───────── LOGOUT ─────────
  static Future<void> logout() async {
    try {
      await _post('logout.php', {});
    } catch (_) {}
    await clearSession();
  }
}
