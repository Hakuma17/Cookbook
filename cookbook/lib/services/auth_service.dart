// lib/services/auth_service.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'package:cookbook/main.dart' show navKey;
import 'package:cookbook/models/ingredient.dart';
import 'api_service.dart';

class AuthService {
  /* ───── prefs keys ───── */
  static const _kIsLoggedIn = 'isLoggedIn';
  static const _kUserId = 'userId';
  static const _kProfileName = 'profileName';
  static const _kProfileImage = 'profileImage';
  static const _kEmail = 'email';

  /* ───── prefs cache ───── */
  static final Future<SharedPreferences> _prefs =
      SharedPreferences.getInstance();

  /* ───── session ping cache (TTL 90s) ───── */
  static bool? _cachedValid;
  static DateTime _lastPing = DateTime.fromMillisecondsSinceEpoch(0);
  static const _pingTTL = Duration(seconds: 90);

  /* ───────────── auth helpers ───────────── */
  static Future<bool> isLoggedIn() async {
    final p = await _prefs;
    if (!(p.getBool(_kIsLoggedIn) ?? false)) return false;

    if (DateTime.now().difference(_lastPing) < _pingTTL &&
        _cachedValid != null) {
      return _cachedValid!;
    }

    try {
      final ok = await ApiService.pingSession();
      _cachedValid = ok;
      _lastPing = DateTime.now();
      if (!ok) await logout(silent: true);
      return ok;
    } catch (_) {
      await logout(silent: true);
      return false;
    }
  }

  static Future<int?> getUserId() async => (await _prefs).getInt(_kUserId);
  static Future<String?> getProfileName() async =>
      (await _prefs).getString(_kProfileName);
  static Future<String?> getProfileImage() async =>
      (await _prefs).getString(_kProfileImage);
  static Future<String?> getEmail() async => (await _prefs).getString(_kEmail);

  /* ───────────── save / clear ───────────── */
  static Future<void> saveLogin({
    required int userId,
    required String profileName,
    required String profileImage,
    required String email,
  }) async {
    final p = await _prefs;
    await Future.wait([
      p.setBool(_kIsLoggedIn, true),
      p.setInt(_kUserId, userId),
      p.setString(_kProfileName, profileName),
      p.setString(_kProfileImage, profileImage),
      p.setString(_kEmail, email.trim()),
    ]);
    _cachedValid = true;
    _lastPing = DateTime.now();
  }

  static Future<void> saveLoginData(Map<String, dynamic> d) => saveLogin(
        userId: int.tryParse(d['user_id'].toString()) ?? 0,
        profileName: d['profile_name'] ?? '',
        profileImage: d['path_imgProfile'] ?? '',
        email: d['email'] ?? '',
      );

  static Future<void> logout({bool silent = false}) async {
    final p = await _prefs;
    await p.clear();
    ApiService.clearSession();
    _cachedValid = false;
    if (!silent) {
      navKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  /* ───────────── misc helpers ───────────── */
  static Future<Map<String, dynamic>> getLoginData() async {
    final p = await _prefs;
    return {
      'isLoggedIn': p.getBool(_kIsLoggedIn) ?? false,
      'userId': p.getInt(_kUserId),
      'profileName': p.getString(_kProfileName),
      'profileImage': p.getString(_kProfileImage),
      'email': p.getString(_kEmail),
    };
  }

  static Future<bool> checkAndRedirectIfLoggedOut(BuildContext ctx) async {
    if (await isLoggedIn()) return true;
    Navigator.of(ctx).pushReplacementNamed('/login');
    return false;
  }

  static Future<List<String>> getUserAllergies() async {
    if (!await isLoggedIn()) return [];
    final list = await ApiService.fetchAllergyIngredients();
    return list.map((ing) => ing.name).toList();
  }

  static Future<bool> tryLogout() async {
    try {
      await ApiService.logout();
      await logout(silent: true);
      return true;
    } catch (_) {
      await logout(silent: true);
      return false;
    }
  }

  /* ═════════════ OTP SECTION ═════════════ */

  /// ✅ ยืนยัน OTP (ใช้ทั้งสมัครใหม่และลืมรหัสผ่าน)
  static Future<Map<String, dynamic>> verifyOtp(
      String email, String otp) async {
    try {
      return await ApiService.verifyOtp(email, otp);
    } on SocketException {
      return {'success': false, 'message': 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// ✅ ขอ OTP ใหม่ (เฉพาะ flow สมัครสมาชิก)
  static Future<Map<String, dynamic>> resendOtp(String email) async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}resend_otp.php');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {'email': email.trim()},
      ).timeout(const Duration(seconds: 30));

      return jsonDecode(response.body) as Map<String, dynamic>;
    } on SocketException {
      return {'success': false, 'message': 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
