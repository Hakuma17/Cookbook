// lib/services/auth_service.dart
//
// Service จัดการสถานะการล็อกอิน + คุกกี้ + SharedPreferences
// เพิ่มการเก็บ/อ่าน googleId เพื่อให้ UI รู้ว่าบัญชีเชื่อม Google หรือไม่

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
  static const _kGoogleId = 'googleId'; // ★ ใหม่: เก็บ google_id
  static const _kHasSeenOnboarding = 'hasSeenOnboarding'; // ผ่าน onboarding?

  // ★ ใหม่: โปรไฟล์ข้อความใต้ชื่อ
  static const _kProfileInfo = 'profileInfo';

  // ↓ ใหม่: ใช้ “จำอีเมลที่ยังไม่ยืนยัน” เพื่อ resume flow
  static const _kPendingVerifyEmail =
      'pendingVerifyEmail'; // อีเมลที่ต้องยืนยัน
  static const _kPendingVerifyAtEpoch =
      'pendingVerifyAtEpoch'; // เวลาเริ่มคูลดาวน์
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
  static Future<bool> isLoggedIn() async {
    final p = await _prefs;
    return p.getBool(_kIsLoggedIn) ?? false;
  }

  static bool isLoggedInSync() => _cachedLoggedIn;

  /* ───────────── getters ───────────── */
  static Future<int?> getUserId() async => (await _prefs).getInt(_kUserId);
  static Future<String?> getProfileName() async =>
      (await _prefs).getString(_kProfileName);
  static Future<String?> getProfileImage() async =>
      (await _prefs).getString(_kProfileImage);
  static Future<String?> getEmail() async => (await _prefs).getString(_kEmail);
  static Future<String?> getGoogleId() async =>
      (await _prefs).getString(_kGoogleId);
  // ★ getter ใหม่
  static Future<String?> getProfileInfo() async =>
      (await _prefs).getString(_kProfileInfo);

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
  /// บันทึกข้อมูลตอนล็อกอินสำเร็จ
  static Future<void> saveLogin({
    required int userId,
    required String profileName,
    required String profileImage,
    required String email,
    String? googleId, // ★ optional
    String? profileInfo, // ★ ใหม่: เก็บข้อความใต้โปรไฟล์
  }) async {
    final p = await _prefs;
    await p.setBool(_kIsLoggedIn, true);
    await p.setInt(_kUserId, userId);
    await p.setString(_kProfileName, profileName);
    await p.setString(_kProfileImage, profileImage);
    await p.setString(_kEmail, email.trim());
    if (profileInfo != null) {
      await p.setString(_kProfileInfo, profileInfo);
    }
    // เก็บ googleId ถ้ามี (ถ้า null/ว่าง = ลบออก)
    if (googleId != null && googleId.trim().isNotEmpty) {
      await p.setString(_kGoogleId, googleId.trim());
    } else {
      await p.remove(_kGoogleId);
    }

    await clearPendingEmailVerify(); // เคลียร์สถานะรอยืนยัน หากเข้าระบบได้แล้ว
    _cachedLoggedIn = true; // อัปเดตแคช
  }

  /// แปลง map จาก BE → saveLogin (แบบ merge) เพื่อ "ไม่ทับ" โปรไฟล์ท้องถิ่นถ้ามีอยู่แล้ว
  /// - รองรับคีย์ทั้ง snake_case และ camelCase
  /// - ชื่อ, รูป, และข้อมูลใต้โปรไฟล์: ถ้า local มีค่าอยู่แล้ว จะไม่ถูกทับด้วยค่าที่ได้จากการล็อกอินอีก
  static Future<void> saveLoginData(Map<String, dynamic> d) async {
    final p = await _prefs;

    // 1) ดึงค่าที่เข้ามาจาก BE (รองรับหลายชื่อคีย์)
    final userId = int.tryParse(
            d['user_id']?.toString() ?? d['userId']?.toString() ?? '0') ??
        0;
    final incomingName =
        (d['profile_name'] ?? d['profileName'] ?? '').toString();

    // image: รองรับทั้ง image_url (absolute), path_imgProfile (relative), profileImage
    final imgUrl = (d['image_url'] ?? d['profileImage'] ?? '').toString();
    final imgPath = (d['path_imgProfile'] ?? '').toString();
    final incomingImage = (imgUrl.isNotEmpty ? imgUrl : imgPath);

    final incomingEmail = (d['email'] ?? '').toString();
    final incomingGoogleId = (d['google_id'] ?? d['googleId'])?.toString();
    final incomingInfo =
        (d['profile_info'] ?? d['profileInfo'] ?? '').toString();

    // 2) ค่าในเครื่องปัจจุบัน (ถ้ามีอยู่แล้ว ไม่ควรถูกทับหลังล็อกอิน)
    final localName = p.getString(_kProfileName);
    final localImage = p.getString(_kProfileImage);
    final localInfo = p.getString(_kProfileInfo);

    // กติกา merge:
    // - ถ้า local มีค่า (ไม่ว่าง) → ใช้ local
    // - ถ้า local ไม่มีค่า → ใช้ incoming
    String finalName = (localName != null && localName.trim().isNotEmpty)
        ? localName
        : incomingName;
    String finalImage = (localImage != null && localImage.trim().isNotEmpty)
        ? localImage
        : incomingImage;
    String finalInfo = (localInfo != null && localInfo.trim().isNotEmpty)
        ? localInfo
        : incomingInfo;

    // 3) เซฟลง prefs โดยยังคงเก็บ googleId และอื่น ๆ ปกติ
    await saveLogin(
      userId: userId,
      profileName: finalName,
      profileImage: finalImage,
      email: incomingEmail,
      googleId: incomingGoogleId,
      profileInfo: finalInfo,
    );
  }

  /// อัปเดตข้อมูลโปรไฟล์ที่เก็บใน prefs เมื่อผู้ใช้แก้ไข
  static Future<void> updateLocalProfile({
    String? profileName,
    String? profileImage,
    String? email,
    String? googleId, // เผื่อใช้ในอนาคต
    String? profileInfo, // ★ ใหม่
  }) async {
    final p = await _prefs;
    if (profileName != null) await p.setString(_kProfileName, profileName);
    if (profileImage != null) await p.setString(_kProfileImage, profileImage);
    if (email != null) await p.setString(_kEmail, email.trim());
    if (googleId != null) {
      if (googleId.trim().isEmpty) {
        await p.remove(_kGoogleId);
      } else {
        await p.setString(_kGoogleId, googleId.trim());
      }
    }
    if (profileInfo != null) {
      await p.setString(_kProfileInfo, profileInfo);
    }
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
    await p.remove(_kGoogleId); // ★
    await p.remove(_kProfileInfo); // ★
    await clearPendingEmailVerify();

    _cachedLoggedIn = false;
  }

  /* ───────────── misc helpers ───────────── */
  /// คืนสรุปข้อมูลล็อกอิน (รวม googleId ด้วย)
  static Future<Map<String, dynamic>> getLoginData() async {
    final p = await _prefs;
    final gid = p.getString(_kGoogleId);
    return {
      'isLoggedIn': await isLoggedIn(),
      'userId': p.getInt(_kUserId),
      'profileName': p.getString(_kProfileName),
      'profileImage': p.getString(_kProfileImage),
      'email': p.getString(_kEmail),
      'googleId': gid, // camelCase
      'google_id': gid, // snake_case (ให้หน้า UI ใช้ได้ทั้งสองแบบ)
      // ★ ใส่ profileInfo ให้ FE หยิบใช้ได้เลย
      'profileInfo': p.getString(_kProfileInfo),
      'profile_info': p.getString(_kProfileInfo),
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
  static Future<Map<String, dynamic>> verifyOtp(String email, String otp) =>
      ApiService.verifyOtp(email, otp);

  static Future<Map<String, dynamic>> resendOtp(String email) =>
      ApiService.resendOtp(email);

  /* ═════════════ Pending Email Verify (resume flow) ═════════════ */
  static Future<void> markPendingEmailVerify({
    required String email,
    bool startCooldown = true,
  }) async {
    final p = await _prefs;
    await p.setString(_kPendingVerifyEmail, email.trim());
    if (startCooldown) {
      await p.setInt(
          _kPendingVerifyAtEpoch, DateTime.now().millisecondsSinceEpoch);
    } else {
      await p.remove(_kPendingVerifyAtEpoch);
    }
  }

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

  static Future<void> clearPendingEmailVerify() async {
    final p = await _prefs;
    await p.remove(_kPendingVerifyEmail);
    await p.remove(_kPendingVerifyAtEpoch);
  }
}
