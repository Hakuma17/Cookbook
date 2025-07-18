// lib/services/api_service.dart
// ──────────────────────────────────────────────────────────────
// 2025-07-14 refactor: รวม header/cookie helper -- ไม่เปลี่ยนพฤติกรรม
// ──────────────────────────────────────────────────────────────
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';

import 'package:cookbook/main.dart' show navKey; // navigatorKey
import 'package:cookbook/services/auth_service.dart';

import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/recipe_detail.dart';
import '../models/comment.dart';
import '../models/cart_item.dart';
import '../models/cart_response.dart';
import '../models/cart_ingredient.dart';
import '../models/search_response.dart';

/// จัดการทุก API call กับ backend (PHP)
class ApiService {
  /* ───── http & session ───── */
  static final _client = http.Client();
  static const _timeout = Duration(seconds: 30);
  static String? _sessionCookie;
  static late final String baseUrl;

  /// เรียก 1× ก่อน runApp()
  static Future<void> initBaseUrl() async {
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      baseUrl = info.isPhysicalDevice
          ? 'http://192.168.137.1/cookbookapp/'
          : 'http://10.0.2.2/cookbookapp/';
    } else {
      baseUrl = 'http://localhost/cookbookapp/';
    }
  }

  /* ───── cookie & header helper ───── */
  static void clearSession() => _sessionCookie = null;

  static void _captureCookie(http.BaseResponse r) {
    final raw = r.headers['set-cookie'];
    final m = raw == null ? null : RegExp(r'PHPSESSID=([^;]+)').firstMatch(raw);
    if (m != null) _sessionCookie = m.group(1);
  }

  static Map<String, String> _headers({bool json = false}) => {
        if (json)
          'Content-Type': 'application/json'
        else
          'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
        if (_sessionCookie != null) 'Cookie': 'PHPSESSID=$_sessionCookie',
      };

  /* ───── ping session ───── */
  static Future<bool> pingSession() async {
    try {
      final res = await _get(Uri.parse('${baseUrl}ping.php'));
      final j = jsonDecode(res.body);
      return j['valid'] == true;
    } catch (_) {
      return false;
    }
  }

  /* ───── low-level GET / POST ───── */
  static Future<http.Response> _get(Uri uri, {bool public = false}) async {
    final r = await _client
        .get(uri, headers: public ? null : _headers())
        .timeout(_timeout);
    _captureCookie(r);
    if (r.statusCode != 200) _throwHttp('GET ${uri.path}', r);
    return r;
  }

  static Future<http.Response> _post(
      String path, Map<String, String> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final r = await _client
        .post(uri, headers: _headers(), body: body)
        .timeout(_timeout);
    _captureCookie(r);
    if (r.statusCode != 200) _throwHttp('POST $path', r);
    return r;
  }

  static Future<http.Response> _getWithSession(String p) =>
      _get(Uri.parse('$baseUrl$p'));

  static Future<http.Response> _postWithSession(
          String p, Map<String, String> b) =>
      _post(p, b);

  /* ───── JSON wrapper ───── */
  static Future<Map<String, dynamic>> _postAndProcess(
          String p, Map<String, String> b) async =>
      _safeProcess(await _post(p, b));

  static Map<String, dynamic> _safeProcess(http.Response r) {
    Map<String, dynamic>? j;
    try {
      j = jsonDecode(r.body.trim());
    } catch (_) {}
    if (j?['code'] == 401 || j?['status'] == 401 || r.statusCode == 401) {
      _forceLogout();
      throw Exception('หมดเวลาการเข้าสู่ระบบ (401)');
    }
    final ok = j != null && (_truthy(j['success']) || _truthy(j['valid']));
    return {
      'success': ok,
      'message':
          j?['message'] ?? (ok ? 'สำเร็จ' : 'เกิดข้อผิดพลาด (${r.statusCode})'),
      'data': (j?['data'] is Map) ? j!['data'] : <String, dynamic>{},
      'debug': j?['debug'],
    };
  }

  static bool _truthy(dynamic v) => v is bool
      ? v
      : v is num
          ? v != 0
          : v.toString().toLowerCase() == 'true';

  /* ═════ logout & error ═════ */
  static Future<void> _forceLogout() async {
    await AuthService.logout(silent: true);
    navKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  static Never _throwHttp(String what, http.Response r) {
    if (r.statusCode == 401) {
      _forceLogout();
      throw Exception('หมดเวลาการเข้าสู่ระบบ (401)');
    }
    throw Exception('$what (${r.statusCode})');
  }

  // ─── Data Endpoints ──────────────────────────────────────
  static Future<List<Ingredient>> fetchIngredients() async {
    final logged = await AuthService.isLoggedIn();
    final r = await _get(
      Uri.parse('${baseUrl}get_ingredients.php'),
      public: !logged,
    );
    final j = jsonDecode(r.body);
    if (j['success'] != true || j['data'] is! List) {
      throw Exception(j['message'] ?? 'โหลดวัตถุดิบล้มเหลว');
    }
    return (j['data'] as List).map((e) => Ingredient.fromJson(e)).toList();
  }

  static Future<List<Recipe>> fetchPopularRecipes() async {
    final logged = await AuthService.isLoggedIn();
    final r = await _get(Uri.parse('${baseUrl}get_popular_recipes.php'),
        public: !logged);
    final j = jsonDecode(r.body);
    if (j['success'] != true || j['data'] is! List) {
      throw Exception(j['message'] ?? 'โหลดสูตรยอดนิยมล้มเหลว');
    }
    return (j['data'] as List).map((e) => Recipe.fromJson(e)).toList();
  }

  static Future<List<Recipe>> fetchNewRecipes() async {
    final logged = await AuthService.isLoggedIn();
    final r =
        await _get(Uri.parse('${baseUrl}get_new_recipes.php'), public: !logged);
    final j = jsonDecode(r.body);
    if (j['success'] != true || j['data'] is! List) {
      throw Exception(j['message'] ?? 'โหลดสูตรใหม่ล้มเหลว');
    }
    return (j['data'] as List).map((e) => Recipe.fromJson(e)).toList();
  }

  static Future<RecipeDetail> fetchRecipeDetail(int id) async {
    final r = await _getWithSession('get_recipe_detail.php?id=$id');
    final j = jsonDecode(r.body);
    if (j['success'] != true || j['data'] is! Map) {
      throw Exception(j['message'] ?? 'โหลดรายละเอียดสูตรล้มเหลว');
    }
    final d = j['data'] as Map<String, dynamic>;
    d['image_urls'] ??= d['image_url'] != null ? [d['image_url']] : [];
    d['current_servings'] ??= 1;
    return RecipeDetail.fromJson(d);
  }

  /// Alias
  static Future<RecipeDetail> getRecipeDetail(int id) => fetchRecipeDetail(id);

  // ─── Favorites & Ratings ────────────────────────────────
  static Future<int> toggleFavorite(int recipeId, bool fav) async {
    final r = await _postAndProcess('toggle_favorite.php', {
      'recipe_id': recipeId.toString(),
      'favorite': fav ? '1' : '0',
    });
    if (!r['success']) throw Exception(r['message']);
    return int.tryParse(r['data']['favorite_count'].toString()) ?? 0;
  }

  static Future<double> postRating(int recipeId, double rating) async {
    final r = await _postAndProcess('post_rating.php', {
      'recipe_id': recipeId.toString(),
      'rating': rating.toString(),
    });
    return (r['data']['average_rating'] as num).toDouble();
  }

  static Future<List<Recipe>> fetchFavorites() async {
    final r = await _getWithSession('get_user_favorites.php');
    final j = jsonDecode(r.body);
    if (j['success'] != true) throw Exception(j['message']);
    return (j['data'] as List).map((e) => Recipe.fromJson(e)).toList();
  }

  // ─── Comments ───────────────────────────────────────────
  static Future<List<Comment>> getComments(int recipeId) async {
    final r = await _getWithSession('get_comments.php?id=$recipeId');
    final j = jsonDecode(r.body);
    if (j['success'] != true) throw Exception(j['message']);
    return (j['data'] as List).map((e) => Comment.fromJson(e)).toList();
  }

  static Future<Comment> postComment(
      int recipeId, String text, double rating) async {
    final r = await _postAndProcess('post_comment.php', {
      'recipe_id': recipeId.toString(),
      'comment': text,
      'rating': rating.toStringAsFixed(1),
    });
    if (!r['success']) throw Exception(r['message']);
    return Comment.fromJson(r['data']);
  }

  static Future<void> deleteComment(int recipeId) async {
    final r =
        await _postAndProcess('delete_comment.php', {'recipe_id': '$recipeId'});
    if (!r['success']) throw Exception(r['message']);
  }

  // ─── Cart ───────────────────────────────────────────────
  static Future<void> updateCart(int recipeId, double count) async {
    final r = await _postAndProcess('update_cart.php', {
      'recipe_id': '$recipeId',
      'nServings': '$count',
    });
    if (!r['success']) throw Exception(r['message']);
  }

  static Future<CartResponse> fetchCartData() async {
    final r = await _getWithSession('get_cart_items.php');
    final j = jsonDecode(r.body);
    if (j['success'] != true) throw Exception(j['message']);
    return CartResponse(
      totalItems: int.tryParse(j['totalItems'].toString()) ??
          (j['data'] as List).length,
      items: (j['data'] as List).map((e) => CartItem.fromJson(e)).toList(),
    );
  }

  static Future<void> clearCart() async {
    final r = await _postAndProcess('clear_cart.php', {});
    if (!r['success']) throw Exception(r['message']);
  }

  static Future<List<CartIngredient>> fetchCartIngredients() async {
    final r = await _getWithSession('get_cart_ingredients.php');
    final j = jsonDecode(r.body);
    if (j['success'] != true) throw Exception(j['message']);
    return (j['data'] as List).map((e) => CartIngredient.fromJson(e)).toList();
  }

  static Future<void> addCartItem(int id, double n) async {
    final r = await _postAndProcess(
        'add_cart_item.php', {'recipe_id': '$id', 'nServings': '$n'});
    if (!r['success']) throw Exception(r['message']);
  }

  static Future<void> removeCartItem(int id) async {
    final r =
        await _postAndProcess('remove_cart_item.php', {'recipe_id': '$id'});
    if (!r['success']) throw Exception(r['message']);
  }

  // ─── Allergies ──────────────────────────────────────────
  static Future<List<Ingredient>> fetchAllergyIngredients() async {
    if (!await AuthService.isLoggedIn()) return [];
    final r = await _getWithSession('get_allergy_list.php');
    final j = jsonDecode(r.body);
    if (j['success'] != true) throw Exception(j['message']);
    return (j['data'] as List).map((e) => Ingredient.fromJson(e)).toList();
  }

  static Future<void> addAllergy(int id) async {
    final r = await _postAndProcess(
        'manage_allergy.php', {'action': 'add', 'ingredient_id': '$id'});
    if (!r['success']) throw Exception(r['message']);
  }

  static Future<void> removeAllergy(int id) async {
    final r = await _postAndProcess(
        'manage_allergy.php', {'action': 'remove', 'ingredient_id': '$id'});
    if (!r['success']) throw Exception(r['message']);
  }

  // ─── Auth / Password / OTP ─────────────────────────────
  static Future<Map<String, dynamic>> changePassword(
          String oldP, String newP) =>
      _postAndProcess(
          'change_password.php', {'old_password': oldP, 'new_password': newP});

  static Future<Map<String, dynamic>> login(String email, String pwd) async {
    final r = await _client.post(Uri.parse('${baseUrl}login.php'),
        headers: _headers(),
        body: {'email': email, 'password': pwd}).timeout(_timeout);
    _captureCookie(r);
    return _safeProcess(r);
  }

  static Future<void> logout() async {
    try {
      await _post('logout.php', {}); // hit server; ignore error
    } catch (_) {}
    clearSession();
  }

  static Future<Map<String, dynamic>> register(
          String email, String pwd, String cPwd, String name) =>
      _postAndProcess('register.php', {
        'email': email,
        'password': pwd,
        'confirm_password': cPwd,
        'username': name,
      });

  static Future<Map<String, dynamic>> googleSignIn(String idToken) async {
    final r = await _client.post(Uri.parse('${baseUrl}google_login.php'),
        headers: _headers(), body: {'id_token': idToken}).timeout(_timeout);
    _captureCookie(r);
    return _safeProcess(r);
  }

  static Future<Map<String, dynamic>> sendOtp(String email) =>
      _postAndProcess('reset_password.php', {'email': email});

  static Future<Map<String, dynamic>> verifyOtp(String email, String otp) =>
      _postAndProcess('verify_otp.php', {'email': email, 'otp': otp});

  static Future<Map<String, dynamic>> resetPassword(
          String email, String otp, String newP) =>
      _postAndProcess('new_password.php',
          {'email': email, 'otp': otp, 'new_password': newP});

  // ─── Profile Image & Update ────────────────────────────
  static Future<String> uploadProfileImage(File img) async {
    final req = http.MultipartRequest(
        'POST', Uri.parse('${baseUrl}upload_profile_image.php'))
      ..headers.addAll(_headers())
      ..files.add(await http.MultipartFile.fromPath('profile_image', img.path));

    final streamed = await req.send().timeout(_timeout);
    final resp = await http.Response.fromStream(streamed);
    _captureCookie(resp);

    if (resp.statusCode != 200) {
      throw Exception('อัปโหลดรูปไม่สำเร็จ (${resp.statusCode})');
    }
    final j = jsonDecode(resp.body);
    if (j['success'] != true) throw Exception(j['message']);
    final path = j['data']?['relative_path'];
    if (path is! String) throw Exception('ไม่มี relative path ส่งกลับมา');
    return path;
  }

  static Future<Map<String, dynamic>> updateProfile(
      {required String profileName, required String imageUrl}) async {
    final r = await _client
        .post(Uri.parse('${baseUrl}update_profile.php'),
            headers: _headers(json: true),
            body: jsonEncode(
                {'profile_name': profileName, 'profile_image': imageUrl}))
        .timeout(_timeout);
    _captureCookie(r);
    final j = jsonDecode(r.body);
    if (j['success'] != true) throw Exception(j['message']);
    return (j['data'] is Map) ? j['data'] : {};
  }

  // ─── Search / Suggest ─────────────────────────────────
  static Future<SearchResponse> searchRecipes({
    required String query,
    int page = 1,
    int limit = 26,
    String sort = 'latest',
    String mode = 'recipe',
    List<String>? ingredientNames,
    List<int>? includeIngredientIds,
    List<String>? excludeIngredientNames,
    List<int>? excludeIngredientIds,
    int? categoryId,
  }) async {
    final qp = <String, String>{
      'page': '$page',
      'limit': '$limit',
      'sort': sort,
      'mode': mode,
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (categoryId != null) 'cat_id': '$categoryId',
      if (ingredientNames?.isNotEmpty ?? false)
        'include': ingredientNames!.join(','),
      if (excludeIngredientNames?.isNotEmpty ?? false)
        'exclude': excludeIngredientNames!.join(','),
    };
    includeIngredientIds?.forEach((id) => qp['include_ids[]'] = '$id');
    excludeIngredientIds?.forEach((id) => qp['exclude_ids[]'] = '$id');

    final uri = Uri.parse('${baseUrl}search_recipes_unified.php')
        .replace(queryParameters: qp);
    final r = await _get(uri);
    final j = jsonDecode(r.body);
    if (j['success'] != true) throw Exception(j['message']);
    return SearchResponse(
      page: j['page'] ?? 1,
      tokens: List<String>.from(j['tokens'] ?? []),
      recipes: (j['data'] as List).map((e) => Recipe.fromJson(e)).toList(),
    );
  }

  static Future<List<String>> getRecipeSuggestions(String pattern) async {
    if (pattern.isEmpty) return [];
    try {
      final r = await _client
          .get(Uri.parse(
              '${baseUrl}get_recipe_suggestions.php?q=${Uri.encodeComponent(pattern)}'))
          .timeout(_timeout);
      final list = jsonDecode(r.body);
      if (list is List) return List<String>.from(list);
    } catch (_) {}
    return [];
  }

  static Future<List<Recipe>> searchRecipesByIngredientNames(List<String> names,
      {String sort = 'popular', int limit = 26}) async {
    final clean =
        names.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (clean.isEmpty) return [];
    final uri = Uri.parse('${baseUrl}search_recipes_unified.php')
        .replace(queryParameters: {
      'ingredients': clean.join(','),
      'sort': sort,
      'limit': '$limit',
    });
    final r = await _client.get(uri).timeout(_timeout);
    final j = jsonDecode(r.body);
    if (j['success'] != true) throw Exception(j['message']);
    return (j['data'] as List).map((e) => Recipe.fromJson(e)).toList();
  }

  static Future<List<String>> getIngredientSuggestions(String pattern) async {
    if (pattern.isEmpty) return [];
    try {
      final r = await _client
          .get(Uri.parse(
              '${baseUrl}get_ingredient_suggestions.php?term=${Uri.encodeComponent(pattern)}'))
          .timeout(_timeout);
      final j = jsonDecode(r.body);
      if (j['success'] == true) return List<String>.from(j['data']);
    } catch (_) {}
    return [];
  }
}
