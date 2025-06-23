import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'package:cookbook/main.dart' show navKey;

class AuthService {
  static const _keyIsLoggedIn = 'isLoggedIn';
  static const _keyUserId = 'userId';
  static const _keyProfileName = 'profileName';
  static const _keyProfileImage = 'profileImage';
  static const _keyEmail = 'email';

  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  /* ───────────── getters ───────────── */

  static Future<bool> isLoggedIn() async =>
      (await _prefs).getBool(_keyIsLoggedIn) ?? false;

  static Future<int?> getUserId() async => (await _prefs).getInt(_keyUserId);
  static Future<String?> getProfileName() async =>
      (await _prefs).getString(_keyProfileName);
  static Future<String?> getProfileImage() async =>
      (await _prefs).getString(_keyProfileImage);

  /* ───────────── save / clear ───────────── */

  static Future<void> saveLogin({
    required int userId,
    required String profileName,
    required String profileImage,
    required String email,
  }) async {
    final p = await _prefs;
    await p.setBool(_keyIsLoggedIn, true);
    await p.setInt(_keyUserId, userId);
    await p.setString(_keyProfileName, profileName);
    await p.setString(_keyProfileImage, profileImage);
    await p.setString(_keyEmail, email);
  }

  static Future<void> saveLoginData(Map<String, dynamic> d) async {
    await saveLogin(
      userId: int.tryParse(d['user_id'].toString()) ?? 0,
      profileName: d['profile_name'] ?? '',
      profileImage: d['path_imgProfile'] ?? '',
      email: d['email'] ?? '',
    );
  }

  /// **เพิ่ม** พารามิเตอร์ `silent` (ใช้ตอน force-logout)
  static Future<void> logout({bool silent = false}) async {
    final p = await _prefs;
    await p.clear();
    ApiService.clearSession();

    // ถ้าไม่ silent → กระโดดกลับ Login ให้ผู้ใช้เห็น
    if (!silent) {
      // ใช้ navigatorKey จาก main.dart
      navKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  /* ───────────── helpers ───────────── */

  static Future<Map<String, dynamic>> getLoginData() async {
    final p = await _prefs;
    return {
      'isLoggedIn': p.getBool(_keyIsLoggedIn) ?? false,
      'userId': p.getInt(_keyUserId),
      'profileName': p.getString(_keyProfileName),
      'profileImage': p.getString(_keyProfileImage),
      'email': p.getString(_keyEmail),
    };
  }

  static Future<bool> checkAndRedirectIfLoggedOut(BuildContext ctx) async {
    if (await isLoggedIn()) return true;
    Navigator.of(ctx).pushReplacementNamed('/login');
    return false;
  }
}
