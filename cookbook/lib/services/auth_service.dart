import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  static const _keyIsLoggedIn = 'isLoggedIn';
  static const _keyUserId = 'userId';
  static const _keyProfileName = 'profileName';
  static const _keyProfileImage = 'profileImage';
  static const _keyEmail = 'email';

  static Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  /// เช็คว่าล็อกอินอยู่หรือไม่
  static Future<bool> isLoggedIn() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  /// ดึง userId (ถ้า login)
  static Future<int?> getUserId() async {
    final prefs = await _prefs;
    return prefs.getInt(_keyUserId);
  }

  /// ดึงชื่อผู้ใช้
  static Future<String?> getProfileName() async {
    final prefs = await _prefs;
    return prefs.getString(_keyProfileName);
  }

  /// ดึงรูปโปรไฟล์
  static Future<String?> getProfileImage() async {
    final prefs = await _prefs;
    return prefs.getString(_keyProfileImage);
  }

  /// เซฟข้อมูลผู้ใช้หลังจาก login แบบใช้ค่าแยก
  static Future<void> saveLogin({
    required int userId,
    required String profileName,
    required String profileImage,
    required String email,
  }) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setInt(_keyUserId, userId);
    await prefs.setString(_keyProfileName, profileName);
    await prefs.setString(_keyProfileImage, profileImage);
    await prefs.setString(_keyEmail, email);
  }

  /// เซฟข้อมูลผู้ใช้แบบรับ JSON ทั้งก้อน (ใช้ใน login screen)
  static Future<void> saveLoginData(Map<String, dynamic> data) async {
    await saveLogin(
      userId: int.tryParse(data['user_id'].toString()) ?? 0,
      profileName: data['profile_name'] ?? '',
      profileImage: data['path_imgProfile'] ?? '',
      email: data['email'] ?? '',
    );
  }

  /// เคลียร์ข้อมูลเมื่อ logout
  static Future<void> logout() async {
    final prefs = await _prefs;
    await prefs.clear();
    ApiService.clearSession(); // ← เพิ่มบรรทัดนี้
  }

  /// ดึงข้อมูลล็อกอินทั้งหมดในครั้งเดียว (userId, name, image)
  static Future<Map<String, dynamic>> getLoginData() async {
    final prefs = await _prefs;
    return {
      'isLoggedIn': prefs.getBool(_keyIsLoggedIn) ?? false,
      'userId': prefs.getInt(_keyUserId),
      'profileName': prefs.getString(_keyProfileName),
      'profileImage': prefs.getString(_keyProfileImage),
      'email': prefs.getString(_keyEmail),
    };
  }

  /// เช็คว่า login แล้วหรือยัง → ถ้าไม่ login จะ redirect ไปหน้า login
  static Future<bool> checkAndRedirectIfLoggedOut(BuildContext context) async {
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!isLoggedIn) {
      Navigator.of(context).pushReplacementNamed('/login');
      return false;
    }
    return true;
  }
}
