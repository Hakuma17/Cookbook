/// lib/models/comment.dart
///
/// ข้อมูลรีวิว/ความคิดเห็นของผู้ใช้ต่อสูตรอาหาร
///
/// * ถ้า `isMine == true` หมายถึงเป็นคอมเมนต์ของผู้ใช้คนปัจจุบัน
class Comment {
  final int? userId; // user_id (nullable ─ guest?)
  final String? profileName; // ชื่อในโปรไฟล์
  final String? avatarUrl; // URL รูปโปรไฟล์
  final int? rating; // ดาว 1 – 5 (nullable = ยังไม่ให้ดาว)
  final String? comment; // เนื้อความรีวิว
  final DateTime? createdAt; // เวลาโพสต์
  final bool isMine; // ของเราหรือไม่? (frontend ใช้โชว์ปุ่มลบ/แก้ไข)

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

  factory Comment.fromJson(Map<String, dynamic> json) {
    int? _int(dynamic v) => v == null ? null : int.tryParse(v.toString());
    String? _str(dynamic v) => v?.toString();
    DateTime? _dt(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    bool _bool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) return v == '1' || v.toLowerCase() == 'true';
      return false;
    }

    return Comment(
      userId: _int(json['user_id']),
      profileName: _str(json['user_name']), // ตาม API
      avatarUrl: _str(json['avatar_url']), // ตาม API
      rating: _int(json['rating']),
      comment: _str(json['comment']),
      createdAt: _dt(json['created_at']),
      isMine: _bool(json['is_mine']), // ตาม API
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

  /// สำเนาใหม่โดยปรับบางฟิลด์ตามต้องการ
  Comment copyWith({
    int? userId,
    String? profileName,
    String? avatarUrl,
    int? rating,
    String? comment,
    DateTime? createdAt,
    bool? isMine,
  }) {
    return Comment(
      userId: userId ?? this.userId,
      profileName: profileName ?? this.profileName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      isMine: isMine ?? this.isMine,
    );
  }

  /// คอมเมนต์ “เปล่า” ไว้ใช้เป็น placeholder ของผู้ใช้ (ยังไม่รีวิว)
  factory Comment.empty() => Comment(
        userId: -1,
        profileName: '',
        avatarUrl: '',
        rating: 0,
        comment: '',
        createdAt: DateTime.now(),
        isMine: true,
      );

  /// ไม่มีข้อความ & ไม่ให้ดาว  → ถือว่า “ว่าง”
  bool get isEmpty =>
      (comment == null || comment!.trim().isEmpty) &&
      (rating == null || rating == 0);

  /// มีเนื้อความจริง ๆ ให้แสดงผล
  bool get hasContent => comment != null && comment!.trim().isNotEmpty;
}
