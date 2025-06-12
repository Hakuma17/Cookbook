import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _keyIsLoggedIn = 'isLoggedIn';
  static const _keyUserId = 'userId';
  static const _keyProfileName = 'profileName';
  static const _keyProfileImage = 'profileImage';

  // ดึง SharedPreferences instance เดียวใช้ซ้ำ
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

  /// เซฟข้อมูลผู้ใช้หลังจาก login
  static Future<void> saveLogin({
    required int userId,
    required String profileName,
    required String profileImage,
  }) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setInt(_keyUserId, userId);
    await prefs.setString(_keyProfileName, profileName);
    await prefs.setString(_keyProfileImage, profileImage);
  }

  /// เคลียร์ข้อมูลเมื่อ logout
  static Future<void> logout() async {
    final prefs = await _prefs;
    await prefs.clear();
  }
}
