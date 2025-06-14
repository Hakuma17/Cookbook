class Comment {
  final int? userId;
  final String? profileName;
  final String? pathImgProfile;
  final int? rating;
  final String? comment;
  final DateTime? createdAt;
  final bool isMine;

  const Comment({
    this.userId,
    this.profileName,
    this.pathImgProfile,
    this.rating,
    this.comment,
    this.createdAt,
    this.isMine = false,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic v) {
      if (v == null) return null;
      return int.tryParse(v.toString());
    }

    String? parseString(dynamic v) {
      if (v == null) return null;
      return v.toString();
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    bool parseBool(dynamic v) {
      if (v is bool) return v;
      if (v is int) return v != 0;
      if (v is String) return v == '1' || v.toLowerCase() == 'true';
      return false;
    }

    return Comment(
      userId: parseInt(json['user_id']),
      profileName: parseString(json['user_name']),
      pathImgProfile: parseString(json['avatar_url']),
      rating: parseInt(json['rating']),
      comment: parseString(json['comment']),
      createdAt: parseDate(json['created_at']),
      isMine: parseBool(json['is_mine']),
    );
  }

  /// สำหรับ fallback ค่าเริ่มต้น เมื่อไม่มีคอมเมนต์ของผู้ใช้
  factory Comment.empty() {
    return Comment(
      userId: -1,
      profileName: '',
      pathImgProfile: '',
      rating: 0,
      comment: '',
      createdAt: DateTime.now(),
      isMine: true,
    );
  }

  /// สำหรับใช้เช็คว่าคอมเมนต์นี้ว่างหรือไม่
  bool get isEmpty =>
      (comment == null || comment!.trim().isEmpty) &&
      (rating == null || rating == 0);

  /// ความคิดเห็นมีข้อความไหม (safe)
  bool get hasContent => comment != null && comment!.trim().isNotEmpty;
}
