import 'package:flutter/foundation.dart';

// ✅ 1. เพิ่ม Helper functions เพื่อการ Parse ที่ปลอดภัย
int _toInt(dynamic v) => v is int ? v : (int.tryParse(v.toString()) ?? 0);
String _toString(dynamic v) => v?.toString() ?? '';

/// ข้อมูลผู้ใช้ในระบบ
@immutable
class UserProfile {
  final int userId;
  final String name;
  final String imageUrl;

  const UserProfile({
    required this.userId,
    required this.name,
    required this.imageUrl,
  });

  /// สร้างจาก JSON ที่ได้จาก API
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: _toInt(json['user_id']),
      name: _toString(json['profile_name']),
      imageUrl: _toString(json['image_url']),
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

  /// ✅ 2. เพิ่มเมธอดมาตรฐานสำหรับ Immutable class
  UserProfile copyWith({
    int? userId,
    String? name,
    String? imageUrl,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile && other.userId == userId;
  }

  @override
  int get hashCode => userId.hashCode;
}
