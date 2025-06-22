import 'dart:io';
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

  static final _client = http.Client();
  static const _timeout = Duration(seconds: 30);
  static String? _sessionCookie;

  /// Base URL ของ API (แก้พาธให้ตรงกับ deploy จริง)clearSession
  static String get baseUrl {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator default
      return 'http://10.0.2.2/cookbookapp/';
    }
    // iOS / Desktop
    return 'http://localhost/cookbookapp/';
  }

  // ─── Internal HTTP Helpers ───────────────────────────────────────────────

  static void clearSession() {
    _sessionCookie = null;
  }

  static Future<http.Response> _get(Uri uri) {
    final headers = <String, String>{};
    if (_sessionCookie != null) {
      headers['Cookie'] = 'PHPSESSID=$_sessionCookie';
    }
    return _client.get(uri, headers: headers).timeout(_timeout);
  }

  static Future<http.Response> _post(
      String path, Map<String, String> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{};
    if (_sessionCookie != null) {
      headers['Cookie'] = 'PHPSESSID=$_sessionCookie';
    }
    final resp =
        await _client.post(uri, headers: headers, body: body).timeout(_timeout);

    // Capture PHPSESSID from Set-Cookie header once
    if (_sessionCookie == null) {
      final raw = resp.headers['set-cookie'];
      if (raw != null) {
        final m = RegExp(r'PHPSESSID=([^;]+)').firstMatch(raw);
        if (m != null) _sessionCookie = m.group(1);
      }
    }
    return resp;
  }

  static Future<http.Response> _getWithSession(String path) =>
      _get(Uri.parse('$baseUrl$path'));

  static Future<http.Response> _postWithSession(
          String path, Map<String, String> body) =>
      _post(path, body);

  /// POST แล้ว parse response เป็น Map {'success','message','data','debug'}
  static Future<Map<String, dynamic>> _postAndProcess(
      String path, Map<String, String> body) async {
    final resp = await _post(path, body);
    return _safeProcess(resp);
  }

  /// แปลง HTTP response → {success,message,data,debug}
  static Map<String, dynamic> _safeProcess(http.Response resp) {
    Map<String, dynamic>? j;
    try {
      j = jsonDecode(resp.body.trim());
    } catch (_) {
      j = null;
    }

    final ok = j != null &&
        (_parseBool(j['success']) || _parseBool(j['valid'] ?? false));

    final msg = j?['message'] ??
        (ok ? 'สำเร็จ' : 'เกิดข้อผิดพลาด (${resp.statusCode})');

    // ▸ ทำให้ result['data'] เป็น Map ไม่เป็น null
    final rawData = j?['data'];
    final safeData =
        (rawData is Map<String, dynamic>) ? rawData : <String, dynamic>{};

    return {
      'success': ok,
      'message': msg,
      'data': safeData,
      'debug': j?['debug'],
    };
  }

  static bool _parseBool(dynamic v) {
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    if (v is num) return v != 0;
    return false;
  }

  // ─── Data Endpoints ───────────────────────────────────────────────────────

  /// GET: ดึงวัตถุดิบทั้งหมด
  static Future<List<Ingredient>> fetchIngredients() async {
    final resp = await _getWithSession('get_ingredients.php');
    if (resp.statusCode != 200) {
      throw Exception('ไม่สามารถโหลดวัตถุดิบได้ (${resp.statusCode})');
    }

    final Map<String, dynamic> j = jsonDecode(resp.body);

    if (j['success'] != true || j['data'] is! List) {
      throw Exception(j['message'] ?? 'โหลดวัตถุดิบล้มเหลว');
    }

    return (j['data'] as List)
        .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET: ดึงสูตรยอดนิยม
  static Future<List<Recipe>> fetchPopularRecipes() async {
    final resp = await _getWithSession('get_popular_recipes.php');
    if (resp.statusCode != 200) {
      throw Exception('ไม่สามารถโหลดสูตรยอดนิยมได้ (${resp.statusCode})');
    }

    //
    final Map<String, dynamic> j = jsonDecode(resp.body);
    if (j['success'] != true || j['data'] is! List) {
      throw Exception(j['message'] ?? 'โหลดสูตรยอดนิยมล้มเหลว');
    }

    return (j['data'] as List)
        .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET: ดึงสูตรใหม่ล่าสุด
  static Future<List<Recipe>> fetchNewRecipes() async {
    final resp = await _getWithSession('get_new_recipes.php');
    if (resp.statusCode != 200) {
      throw Exception('ไม่สามารถโหลดสูตรใหม่ได้ (${resp.statusCode})');
    }

    // ✅ เปลี่ยนจาก List เป็น Map เพราะ API คืน { success: true, data: [...] }
    final Map<String, dynamic> j = jsonDecode(resp.body);
    if (j['success'] != true || j['data'] is! List) {
      throw Exception(j['message'] ?? 'โหลดสูตรใหม่ล้มเหลว');
    }

    return (j['data'] as List)
        .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET: ดึงรายละเอียดสูตร
  static Future<RecipeDetail> fetchRecipeDetail(int id) async {
    final resp = await _getWithSession('get_recipe_detail.php?id=$id');
    if (resp.statusCode != 200) {
      throw Exception('ไม่สามารถโหลดรายละเอียดสูตรได้ (${resp.statusCode})');
    }

    final Map<String, dynamic> json = jsonDecode(resp.body);
    if (json['success'] != true || json['data'] is! Map) {
      throw Exception(json['message'] ?? 'โหลดรายละเอียดสูตรล้มเหลว');
    }

    final Map<String, dynamic> data = json['data'];

    // Normalise fields
    if (data['image_urls'] == null && data['image_url'] != null) {
      data['image_urls'] = [data['image_url'].toString()];
    }
    data['current_servings'] ??= 1;

    return RecipeDetail.fromJson(data);
  }

  /// Alias for fetchRecipeDetail
  static Future<RecipeDetail> getRecipeDetail(int id) => fetchRecipeDetail(id);

  // ─── Favorites & Ratings ─────────────────────────────────────────────────

  /// POST: สลับสถานะโปรด
  static Future<void> toggleFavorite(int recipeId, bool fav) async {
    final result = await _postAndProcess('toggle_favorite.php', {
      'recipe_id': recipeId.toString(),
      'favorite': fav ? '1' : '0',
    });
    if (!result['success']) {
      throw Exception(result['message']);
    }
  }

  /// POST: โพสต์เรตติ้งใหม่ → คืน average_rating
  static Future<double> postRating(int recipeId, double rating) async {
    final result = await _postAndProcess('post_rating.php', {
      'recipe_id': recipeId.toString(),
      'rating': rating.toString(),
    });
    return (result['data']['average_rating'] as num).toDouble();
  }

  /// GET: ดึงรายการโปรดของผู้ใช้
  static Future<List<Recipe>> fetchFavorites() async {
    final resp = await _getWithSession('get_user_favorites.php');
    if (resp.statusCode != 200) {
      throw Exception('ไม่สามารถโหลดสูตรโปรดได้ (${resp.statusCode})');
    }
    final Map<String, dynamic> j = jsonDecode(resp.body);
    if (j['success'] != true) {
      throw Exception(j['message'] ?? 'ไม่สามารถโหลดสูตรโปรดได้');
    }
    return (j['data'] as List).map((e) => Recipe.fromJson(e)).toList();
  }

  // ─── Comments ─────────────────────────────────────────────────────────────

  /// GET: ดึงความคิดเห็นทั้งหมด
  static Future<List<Comment>> getComments(int recipeId) async {
    final resp = await _getWithSession('get_comments.php?id=$recipeId');
    if (resp.statusCode != 200) {
      throw Exception('ไม่สามารถโหลดความคิดเห็นได้ (${resp.statusCode})');
    }
    final Map<String, dynamic> j = jsonDecode(resp.body);
    if (j['success'] != true) {
      throw Exception(j['message'] ?? 'ไม่สามารถโหลดความคิดเห็นได้');
    }
    return (j['data'] as List).map((e) => Comment.fromJson(e)).toList();
  }

  /// POST: สร้าง/อัปเดตรีวิว
  static Future<Comment> postComment(
      int recipeId, String text, double rating) async {
    final result = await _postAndProcess('post_comment.php', {
      'recipe_id': recipeId.toString(),
      'comment': text,
      'rating': rating.toStringAsFixed(1),
    });
    if (!result['success']) {
      throw Exception(result['message']);
    }
    return Comment.fromJson(result['data']);
  }

  /// POST: ลบความคิดเห็น
  static Future<void> deleteComment(int recipeId) async {
    final result = await _postAndProcess('delete_comment.php', {
      'recipe_id': recipeId.toString(),
    });
    if (!result['success']) {
      throw Exception(result['message']);
    }
  }

  // ─── Cart ─────────────────────────────────────────────────────────────────

  /// POST: อัปเดตจำนวนเสิร์ฟในตะกร้า
  static Future<void> updateCart(int recipeId, double count) async {
    final result = await _postAndProcess(
      'update_cart.php',
      {
        'recipe_id': recipeId.toString(),
        'nServings': count.toString(),
      },
    );
    if (!result['success']) throw Exception(result['message']);
  }

  /// GET: ดึงรายการเมนูทั้งหมด + ingredients
  static Future<CartResponse> fetchCartData() async {
    final resp = await _getWithSession('get_cart_items.php');
    if (resp.statusCode != 200) {
      throw Exception('ไม่สามารถโหลดตะกร้าได้ (${resp.statusCode})');
    }
    final Map<String, dynamic> j = jsonDecode(resp.body);
    if (j['success'] != true) {
      throw Exception(j['message'] ?? 'ไม่สามารถโหลดตะกร้าได้');
    }
    return CartResponse(
      totalItems: int.tryParse(j['totalItems'].toString()) ??
          (j['data'] as List).length,
      items: (j['data'] as List).map((e) => CartItem.fromJson(e)).toList(),
    );
  }

  /// POST: ล้างตะกร้า
  static Future<void> clearCart() async {
    final result = await _postAndProcess('clear_cart.php', {});
    if (!result['success']) throw Exception(result['message']);
  }

  /// GET: ดึงวัตถุดิบรวมในตะกร้า
  static Future<List<CartIngredient>> fetchCartIngredients() async {
    final resp = await _getWithSession('get_cart_ingredients.php');
    if (resp.statusCode != 200) {
      throw Exception('ไม่สามารถโหลดวัตถุดิบในตะกร้าได้ (${resp.statusCode})');
    }
    final Map<String, dynamic> j = jsonDecode(resp.body);
    if (j['success'] != true) {
      throw Exception(j['message'] ?? 'ไม่สามารถโหลดวัตถุดิบในตะกร้าได้');
    }
    return (j['data'] as List).map((e) => CartIngredient.fromJson(e)).toList();
  }

  /// POST: เพิ่มเมนูใหม่ลงตะกร้า
  static Future<void> addCartItem(int recipeId, double nServings) async {
    final result = await _postAndProcess('add_cart_item.php', {
      'recipe_id': recipeId.toString(),
      'nServings': nServings.toString(),
    });
    if (!result['success']) throw Exception(result['message']);
  }

  /// POST: ลบเมนูออกจากตะกร้า
  static Future<void> removeCartItem(int recipeId) async {
    final result = await _postAndProcess('remove_cart_item.php', {
      'recipe_id': recipeId.toString(),
    });
    if (!result['success']) throw Exception(result['message']);
  }

  // ─── Allergies (รวม get/add/remove ผ่าน manage_allergy.php) ────────────────

  /// GET: ดึงรายการวัตถุดิบที่แพ้
  static Future<List<Ingredient>> fetchAllergyIngredients() async {
    final resp = await _getWithSession('get_allergy_list.php');
    if (resp.statusCode != 200) {
      throw Exception('โหลดข้อมูลวัตถุดิบที่แพ้ไม่สำเร็จ (${resp.statusCode})');
    }

    final Map<String, dynamic> j = jsonDecode(resp.body);
    if (j['success'] != true) {
      throw Exception(j['message'] ?? 'โหลดข้อมูลวัตถุดิบที่แพ้ไม่สำเร็จ');
    }

    return (j['data'] as List).map((e) => Ingredient.fromJson(e)).toList();
  }

  /// POST: เพิ่มวัตถุดิบที่แพ้
  static Future<void> addAllergy(int ingredientId) async {
    final result = await _postAndProcess('manage_allergy.php', {
      'action': 'add',
      'ingredient_id': ingredientId.toString(),
    });
    if (!result['success']) throw Exception(result['message']);
  }

  /// POST: ลบวัตถุดิบที่แพ้
  static Future<void> removeAllergy(int ingredientId) async {
    final result = await _postAndProcess('manage_allergy.php', {
      'action': 'remove',
      'ingredient_id': ingredientId.toString(),
    });
    if (!result['success']) throw Exception(result['message']);
  }

  // ─── Auth / Password / OTP ────────────────────────────────────────────────

  /// POST: เปลี่ยนรหัสผ่าน
  static Future<Map<String, dynamic>> changePassword(
      String oldPassword, String newPassword) {
    return _postAndProcess('change_password.php', {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }

  /// POST: ล็อกอิน
  static Future<Map<String, dynamic>> login(String email, String password) =>
      _postAndProcess('login.php', {
        'email': email,
        'password': password,
      });

  /// POST: ออกจากระบบ
  static Future<void> logout() async {
    clearSession();
    try {
      await _postWithSession('logout.php', {});
    } catch (_) {}
  }

  /// POST: สมัครสมาชิก
  static Future<Map<String, dynamic>> register(String email, String password,
          String confirmPassword, String username) =>
      _postAndProcess('register.php', {
        'email': email,
        'password': password,
        'confirm_password': confirmPassword,
        'username': username,
      });

  /// POST: Google Sign-In
  static Future<Map<String, dynamic>> googleSignIn(String idToken) =>
      _postAndProcess('google_login.php', {
        'id_token': idToken,
      });

  /// POST: ขอ OTP (reset password)
  static Future<Map<String, dynamic>> sendOtp(String email) =>
      _postAndProcess('reset_password.php', {
        'email': email,
      });

  /// POST: ยืนยัน OTP
  static Future<Map<String, dynamic>> verifyOtp(String email, String otp) =>
      _postAndProcess('verify_otp.php', {
        'email': email,
        'otp': otp,
      });

  /// POST: รีเซตรหัสผ่านใหม่
  static Future<Map<String, dynamic>> resetPassword(
          String email, String otp, String newPassword) =>
      _postAndProcess('new_password.php', {
        'email': email,
        'otp': otp,
        'new_password': newPassword,
      });

  static Future<String> uploadProfileImage(File imageFile) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${baseUrl}upload_profile_image.php'),
    );

    if (_sessionCookie != null) {
      req.headers['Cookie'] = 'PHPSESSID=$_sessionCookie';
    }

    req.files.add(
      await http.MultipartFile.fromPath('profile_image', imageFile.path),
    );

    final streamed = await req.send().timeout(_timeout);
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode != 200) {
      throw Exception('อัปโหลดรูปไม่สำเร็จ (${resp.statusCode})');
    }

    Map<String, dynamic> j;
    try {
      j = jsonDecode(resp.body);
    } catch (e) {
      throw Exception('Response ไม่ใช่ JSON: ${resp.body}');
    }

    if (j['success'] != true) {
      throw Exception(j['message'] ?? 'อัปโหลดรูปไม่สำเร็จ');
    }

    // ✅ ใช้ relative_path แทน image_url
    final path = j['data']?['relative_path'];
    if (path == null || path is! String) {
      throw Exception('ไม่มี relative path ส่งกลับมา');
    }

    return path;
  }

  /// POST: อัปเดตโปรไฟล์ (ชื่อ + URL รูป) — คืน data ใหม่กลับมาด้วย
  static Future<Map<String, dynamic>> updateProfile({
    required String profileName,
    required String imageUrl,
  }) async {
    final uri = Uri.parse('${baseUrl}update_profile.php');
    final resp = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (_sessionCookie != null) 'Cookie': 'PHPSESSID=$_sessionCookie',
      },
      body: jsonEncode({
        'profile_name': profileName,
        'profile_image': imageUrl,
      }),
    );

    Map<String, dynamic> j;
    try {
      j = jsonDecode(resp.body);
    } catch (e) {
      throw Exception('Response ไม่ใช่ JSON: ${resp.body}');
    }

    if (j['success'] != true) {
      throw Exception(j['message']);
    }

    return (j['data'] is Map<String, dynamic>) ? j['data'] : {};
  }

// ─── Search ────────────────────────────────────────────────────────────────

  /// GET: ค้นหาสูตรอาหาร
  /// - query         : คำค้น (≥ 2 ตัวอักษร)
  /// - sort          : popular | trending | latest | recommended  (default: latest)
  /// - page          : หน้า (เริ่ม 1)
  /// - includeIds    : ingredient_id ที่ “ต้องมี”   (include_ids[])
  /// - excludeIds    : ingredient_id ที่ “ต้องไม่มี” (exclude_ids[])
  /// - categoryId    : หมวดอาหารจริง (ตาราง category) – ส่ง cat_id
  static Future<List<Recipe>> searchRecipes({
    required String query,
    int page = 1,
    String sort = 'latest', // ★ เปลี่ยนจาก category → sort
    List<int>? includeIngredientIds,
    List<int>? excludeIngredientIds,
    int? categoryId,
  }) async {
    // 1) สร้าง queryEntries (รองรับ key ซ้ำ)
    final entries = <MapEntry<String, String>>[
      MapEntry('q', query),
      MapEntry('page', page.toString()),
      MapEntry('sort', sort),
    ];

    if (categoryId != null) {
      entries.add(MapEntry('cat_id', categoryId.toString()));
    }

    if (includeIngredientIds?.isNotEmpty ?? false) {
      entries.addAll(includeIngredientIds!
          .map((id) => MapEntry('include_ids[]', id.toString())));
    }

    if (excludeIngredientIds?.isNotEmpty ?? false) {
      entries.addAll(excludeIngredientIds!
          .map((id) => MapEntry('exclude_ids[]', id.toString())));
    }

    // 2) เรียก API
    final uri = Uri.parse('${baseUrl}get_search_recipes.php')
        .replace(queryParameters: Map.fromEntries(entries));

    final resp = await _get(uri);
    if (resp.statusCode != 200) {
      throw Exception('ค้นหาไม่สำเร็จ (${resp.statusCode})');
    }

    final Map<String, dynamic> j = jsonDecode(resp.body);
    if (j['success'] != true) {
      throw Exception(j['message'] ?? 'ค้นหาไม่สำเร็จ');
    }

    return (j['data'] as List)
        .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET: ค้นหาสูตรอาหารจาก “รายชื่อวัตถุดิบ”
  /// - names : รายชื่อวัตถุดิบคั่นด้วย ,
  /// - sort  : (เลือกได้เหมือนด้านบน)  default = popular
  static Future<List<Recipe>> searchRecipesByIngredientNames(
    List<String> names, {
    String sort = 'popular',
  }) async {
    final uri = Uri.parse('${baseUrl}get_search_recipes.php').replace(
      queryParameters: {
        'ingredients': names.join(','),
        'sort': sort,
      },
    );

    final resp = await _client.get(uri).timeout(_timeout);
    if (resp.statusCode != 200) {
      throw Exception('ค้นหาสูตรจากวัตถุดิบล้มเหลว (${resp.statusCode})');
    }

    final Map<String, dynamic> j = jsonDecode(resp.body);
    if (j['success'] != true) {
      throw Exception(j['message'] ?? 'ค้นหาสูตรไม่สำเร็จ');
    }

    return (j['data'] as List)
        .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
