/// user_profile.dart — ข้อมูลผู้ใช้ในระบบ
class UserProfile {
  final int userId;
  final String name;
  final String imageUrl;

  UserProfile({
    required this.userId,
    required this.name,
    required this.imageUrl,
  });

  /// สร้างจาก JSON ที่ได้จาก API เช่น update_profile.php
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] ?? 0, // ถ้าไม่ได้ส่ง user_id ก็ใช้ 0
      name: json['profile_name'] ?? '',
      imageUrl: json['image_url'] ?? '',
    );
  }

  /// ใช้เก็บลง SharedPreferences (เก็บเป็น Map → JSON string)
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'profile_name': name,
      'image_url': imageUrl,
    };
  }
}
