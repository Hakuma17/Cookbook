// lib/services/auth_service.dart
//
// Service จัดการสถานะการล็อกอิน + คุกกี้ + SharedPreferences
// เพิ่ม helpers: resume หน้ากรอก OTP (เก็บอีเมลที่ยังไม่ยืนยัน + เวลาเริ่มคูลดาวน์)

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  /* ───── prefs keys ───── */
  static const _kAuthToken = 'authToken'; // cookie PHPSESSID
  static const _kIsLoggedIn = 'isLoggedIn'; // flag ล็อกอิน
  static const _kUserId = 'userId'; // id ผู้ใช้
  static const _kProfileName = 'profileName'; // ชื่อโปรไฟล์
  static const _kProfileImage = 'profileImage'; // รูปโปรไฟล์
  static const _kEmail = 'email'; // อีเมล
  static const _kHasSeenOnboarding = 'hasSeenOnboarding'; // ผ่าน onboarding?

  // ↓ ใหม่: ใช้ “จำอีเมลที่ยังไม่ยืนยัน” เพื่อ resume flow
  static const _kPendingVerifyEmail =
      'pendingVerifyEmail'; // อีเมลที่ต้องยืนยัน
  static const _kPendingVerifyAtEpoch =
      'pendingVerifyAtEpoch'; // เวลาเริ่มคูลดาวน์ (ms epoch)
  static const int _kOtpCooldownSeconds = 60; // คูลดาวน์มาตรฐาน 60 วิ

  /* ───── prefs cache ───── */
  static final Future<SharedPreferences> _prefs =
      SharedPreferences.getInstance();

  /* ───── in-memory cache (sync read) ───── */
  static bool _cachedLoggedIn = false; // cache สถานะล็อกอิน
  static bool _cacheInitialized = false;

  /// init: โหลด cache ครั้งแรก (อ่านเร็วแบบ sync ได้)
  static Future<void> init() async {
    if (_cacheInitialized) return;
    final p = await _prefs;
    _cachedLoggedIn = p.getBool(_kIsLoggedIn) ?? false;
    _cacheInitialized = true;
  }

  /* ───────────── auth helpers ───────────── */
  /// เช็คล็อกอิน (async จาก prefs)
  static Future<bool> isLoggedIn() async {
    final p = await _prefs;
    return p.getBool(_kIsLoggedIn) ?? false;
  }

  /// เช็คล็อกอินแบบเร็ว (อ่านจากแคชในหน่วยความจำ)
  static bool isLoggedInSync() => _cachedLoggedIn;

  /// getters ทั่วไป
  static Future<int?> getUserId() async => (await _prefs).getInt(_kUserId);
  static Future<String?> getProfileName() async =>
      (await _prefs).getString(_kProfileName);
  static Future<String?> getProfileImage() async =>
      (await _prefs).getString(_kProfileImage);
  static Future<String?> getEmail() async => (await _prefs).getString(_kEmail);

  /* ───────────── Token Helpers ───────────── */
  /// บันทึกคุกกี้เซสชัน
  static Future<void> saveToken(String token) async {
    final p = await _prefs;
    await p.setString(_kAuthToken, token);
  }

  /// ดึงคุกกี้เซสชัน
  static Future<String?> getToken() async =>
      (await _prefs).getString(_kAuthToken);

  /// ลบคุกกี้เซสชัน
  static Future<void> clearToken() async => (await _prefs).remove(_kAuthToken);

  /* ───────── Onboarding Helpers ───────── */
  static Future<void> setOnboardingComplete() async =>
      (await _prefs).setBool(_kHasSeenOnboarding, true);

  static Future<bool> hasSeenOnboarding() async =>
      (await _prefs).getBool(_kHasSeenOnboarding) ?? false;

  /* ───────────── save / clear ───────────── */
  /// บันทึกข้อมูลตอนล็อกอินสำเร็จ
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

    // เคลียร์สถานะรอยืนยัน หากเข้าระบบได้แล้ว
    await clearPendingEmailVerify();

    _cachedLoggedIn = true; // อัปเดตแคช
  }

  /// แปลง map จาก BE → saveLogin
  static Future<void> saveLoginData(Map<String, dynamic> d) => saveLogin(
        userId: int.tryParse(d['user_id'].toString()) ?? 0,
        profileName: d['profile_name'] ?? '',
        profileImage: d['path_imgProfile'] ?? '',
        email: d['email'] ?? '',
      );

  /// อัปเดตข้อมูลโปรไฟล์ที่เก็บใน prefs เมื่อผู้ใช้แก้ไข
  static Future<void> updateLocalProfile({
    String? profileName,
    String? profileImage,
    String? email,
  }) async {
    final p = await _prefs;
    if (profileName != null) await p.setString(_kProfileName, profileName);
    if (profileImage != null) await p.setString(_kProfileImage, profileImage);
    if (email != null) await p.setString(_kEmail, email.trim());
  }

  /// ล็อกเอาท์ (ล้างทุกอย่าง)
  static Future<void> logout() async {
    final p = await _prefs;
    await p.remove(_kAuthToken);
    await p.remove(_kIsLoggedIn);
    await p.remove(_kUserId);
    await p.remove(_kProfileName);
    await p.remove(_kProfileImage);
    await p.remove(_kEmail);
    await clearPendingEmailVerify(); // ล้างสถานะรอยืนยันด้วย

    _cachedLoggedIn = false; // เคลียร์แคช
  }

  /* ───────────── misc helpers ───────────── */
  /// คืนสรุปข้อมูลล็อกอิน
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

  /// ดึงรายการแพ้อาหารของผู้ใช้ (เรียก BE)
  static Future<List<String>> getUserAllergies() async {
    if (!await isLoggedIn()) return [];
    final list = await ApiService.fetchAllergyIngredients();
    return list.map((ing) => ing.name).toList();
  }

  /// พยายามล็อกเอาท์ (BE + ล้างโลคอล) แบบปลอดภัย
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
  /// เรียก verify OTP ผ่าน ApiService
  static Future<Map<String, dynamic>> verifyOtp(String email, String otp) =>
      ApiService.verifyOtp(email, otp);

  /// ขอรหัสใหม่ (resend)
  static Future<Map<String, dynamic>> resendOtp(String email) =>
      ApiService.resendOtp(email);

  /* ═════════════ Pending Email Verify (resume flow) ═════════════
     ใช้กรณี: สมัครสำเร็จแต่ยังไม่ยืนยัน, หรือ login แล้วถูกแจ้ง UNVERIFIED
     เก็บอีเมล + เวลาที่เริ่มคูลดาวน์ เพื่อเปิดแอปมาใหม่จะพากลับไปหน้า OTP ได้
  */

  /// บันทึกอีเมลที่ต้องยืนยัน + เริ่มคูลดาวน์ถ้าต้องการ
  static Future<void> markPendingEmailVerify({
    required String email,
    bool startCooldown = true, // true = เริ่มจับเวลา 60 วิ
  }) async {
    final p = await _prefs;
    await p.setString(_kPendingVerifyEmail, email.trim());
    if (startCooldown) {
      await p.setInt(
        _kPendingVerifyAtEpoch,
        DateTime.now().millisecondsSinceEpoch,
      );
    } else {
      await p.remove(_kPendingVerifyAtEpoch);
    }
  }

  /// อ่านสถานะรอยืนยัน (คืน: {email, secondsLeft} หรือ null ถ้าไม่มี)
  static Future<Map<String, dynamic>?> getPendingEmailVerify() async {
    final p = await _prefs;
    final email = (p.getString(_kPendingVerifyEmail) ?? '').trim();
    if (email.isEmpty) return null;

    final startedMs = p.getInt(_kPendingVerifyAtEpoch);
    int secondsLeft = 0;
    if (startedMs != null && startedMs > 0) {
      final elapsedSec =
          ((DateTime.now().millisecondsSinceEpoch - startedMs) ~/ 1000);
      final remain = _kOtpCooldownSeconds - elapsedSec;
      secondsLeft = remain > 0 ? remain : 0;
    }
    return {'email': email, 'secondsLeft': secondsLeft};
  }

  /// ล้างสถานะรอยืนยัน (เรียกหลัง verify สำเร็จ/ล็อกอินสำเร็จ/ล็อกเอาท์)
  static Future<void> clearPendingEmailVerify() async {
    final p = await _prefs;
    await p.remove(_kPendingVerifyEmail);
    await p.remove(_kPendingVerifyAtEpoch);
  }
}
