import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'json_parser.dart';

/// ข้อมูลรีวิว/ความคิดเห็นของผู้ใช้ต่อสูตรอาหาร
@immutable
class Comment extends Equatable {
  final int? userId;
  final String? profileName;
  final String? avatarUrl;
  final int? rating;
  final String? comment;
  final DateTime? createdAt;
  final bool isMine;

  const Comment({
    this.userId,
    this.profileName,
    this.avatarUrl,
    this.rating,
    this.comment,
    this.createdAt,
    this.isMine = false,
  });

  /* ───────────────────────── factory ───────────────────────── */

  /// 1. เปลี่ยนมาใช้ JsonParser จากส่วนกลาง
  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      userId: JsonParser.parseInt(json['user_id']),
      profileName: JsonParser.parseString(json['user_name']),
      avatarUrl: JsonParser.parseString(json['avatar_url']),
      rating: JsonParser.parseInt(json['rating']),
      comment: JsonParser.parseString(json['comment']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      isMine: JsonParser.parseBool(json['is_mine']),
    );
  }

  /* ───────────────────────── toJson ───────────────────────── */

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'user_name': profileName,
        'avatar_url': avatarUrl,
        'rating': rating,
        'comment': comment,
        'created_at': createdAt?.toIso8601String(),
        'is_mine': isMine,
      };

  /* ───────────────────────── helpers ───────────────────────── */

  /// 2. ปรับปรุง copyWith ให้รองรับการตั้งค่าเป็น null
  Comment copyWith({
    ValueGetter<int?>? userId,
    ValueGetter<String?>? profileName,
    ValueGetter<String?>? avatarUrl,
    ValueGetter<int?>? rating,
    ValueGetter<String?>? comment,
    ValueGetter<DateTime?>? createdAt,
    bool? isMine,
  }) {
    return Comment(
      userId: userId != null ? userId() : this.userId,
      profileName: profileName != null ? profileName() : this.profileName,
      avatarUrl: avatarUrl != null ? avatarUrl() : this.avatarUrl,
      rating: rating != null ? rating() : this.rating,
      comment: comment != null ? comment() : this.comment,
      createdAt: createdAt != null ? createdAt() : this.createdAt,
      isMine: isMine ?? this.isMine,
    );
  }

  /// คอมเมนต์ “เปล่า” ไว้ใช้เป็น placeholder ของผู้ใช้ (ยังไม่รีวิว)
  factory Comment.empty() => Comment(
        userId: -1,
        isMine: true,
        createdAt: DateTime.now(),
      );

  /// ไม่มีข้อความ & ไม่ให้ดาว  → ถือว่า “ว่าง”
  bool get isEmpty =>
      (comment == null || comment!.trim().isEmpty) &&
      (rating == null || rating == 0);

  /// มีเนื้อความจริง ๆ ให้แสดงผล
  bool get hasContent => comment != null && comment!.trim().isNotEmpty;

  ///  3. เพิ่ม props สำหรับ Equatable
  @override
  List<Object?> get props => [
        userId,
        profileName,
        avatarUrl,
        rating,
        comment,
        createdAt,
        isMine,
      ];
}
