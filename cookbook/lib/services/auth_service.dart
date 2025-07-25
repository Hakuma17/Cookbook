// lib/services/auth_service.dart
//
// Service จัดการสถานะการล็อกอิน + คุกกี้ + SharedPreferences
//
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  /* ───── prefs keys ───── */
  static const _kAuthToken = 'authToken';
  static const _kIsLoggedIn = 'isLoggedIn';
  static const _kUserId = 'userId';
  static const _kProfileName = 'profileName';
  static const _kProfileImage = 'profileImage';
  static const _kEmail = 'email';
  static const _kHasSeenOnboarding = 'hasSeenOnboarding';

  /* ───── prefs cache ───── */
  static final Future<SharedPreferences> _prefs =
      SharedPreferences.getInstance();

  /* ───── in‑memory cache (sync read) ───── */
  static bool _cachedLoggedIn = false; // ค่าเริ่มจะ false จนกว่าจะ init
  static bool _cacheInitialized = false;

  /// เรียกครั้งแรกตอนเปิดแอปเพื่อ sync cache (ไม่จำเป็นต้องรอ Future ทุกครั้ง)
  static Future<void> init() async {
    if (_cacheInitialized) return;
    final p = await _prefs;
    _cachedLoggedIn = p.getBool(_kIsLoggedIn) ?? false;
    _cacheInitialized = true;
  }

  /* ───────────── auth helpers ───────────── */
  /// Async – ตรวจ SharedPreferences ตรง ๆ
  static Future<bool> isLoggedIn() async {
    final p = await _prefs;
    return p.getBool(_kIsLoggedIn) ?? false;
  }

  /// Sync – คืนค่าจากแคชในหน่วยความจำ (ต้องเรียก init() สักครั้งก่อน)
  static bool isLoggedInSync() => _cachedLoggedIn;

  static Future<int?> getUserId() async => (await _prefs).getInt(_kUserId);
  static Future<String?> getProfileName() async =>
      (await _prefs).getString(_kProfileName);
  static Future<String?> getProfileImage() async =>
      (await _prefs).getString(_kProfileImage);
  static Future<String?> getEmail() async => (await _prefs).getString(_kEmail);

  /* ───────────── Token Helpers ───────────── */
  static Future<void> saveToken(String token) async {
    final p = await _prefs;
    await p.setString(_kAuthToken, token);
  }

  static Future<String?> getToken() async =>
      (await _prefs).getString(_kAuthToken);

  static Future<void> clearToken() async => (await _prefs).remove(_kAuthToken);

  /* ───────── Onboarding Helpers ───────── */
  static Future<void> setOnboardingComplete() async =>
      (await _prefs).setBool(_kHasSeenOnboarding, true);

  static Future<bool> hasSeenOnboarding() async =>
      (await _prefs).getBool(_kHasSeenOnboarding) ?? false;

  /* ───────────── save / clear ───────────── */
  static Future<void> saveLogin({
    required int userId,
    required String profileName,
    required String profileImage,
    required String email,
  }) async {
    final p = await _prefs;
    await p.setBool(_kIsLoggedIn, true);
    await p.setInt(_kUserId, userId);
    await p.setString(_kProfileName, profileName);
    await p.setString(_kProfileImage, profileImage);
    await p.setString(_kEmail, email.trim());

    // ↳ อัปเดตแคช sync
    _cachedLoggedIn = true;
  }

  static Future<void> saveLoginData(Map<String, dynamic> d) => saveLogin(
        userId: int.tryParse(d['user_id'].toString()) ?? 0,
        profileName: d['profile_name'] ?? '',
        profileImage: d['path_imgProfile'] ?? '',
        email: d['email'] ?? '',
      );

  static Future<void> logout() async {
    final p = await _prefs;
    await p.remove(_kAuthToken);
    await p.remove(_kIsLoggedIn);
    await p.remove(_kUserId);
    await p.remove(_kProfileName);
    await p.remove(_kProfileImage);
    await p.remove(_kEmail);

    // ↳ เคลียร์แคช sync
    _cachedLoggedIn = false;
  }

  /* ───────────── misc helpers ───────────── */
  static Future<Map<String, dynamic>> getLoginData() async {
    final p = await _prefs;
    return {
      'isLoggedIn': await isLoggedIn(),
      'userId': p.getInt(_kUserId),
      'profileName': p.getString(_kProfileName),
      'profileImage': p.getString(_kProfileImage),
      'email': p.getString(_kEmail),
    };
  }

  static Future<List<String>> getUserAllergies() async {
    if (!await isLoggedIn()) return [];
    final list = await ApiService.fetchAllergyIngredients();
    return list.map((ing) => ing.name).toList();
  }

  static Future<bool> tryLogout() async {
    try {
      await ApiService.logout();
      await logout();
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  /* ═════════════ OTP SECTION ═════════════ */
  static Future<Map<String, dynamic>> verifyOtp(String email, String otp) =>
      ApiService.verifyOtp(email, otp);

  static Future<Map<String, dynamic>> resendOtp(String email) =>
      ApiService.resendOtp(email);
}
