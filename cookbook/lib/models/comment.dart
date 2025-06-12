// lib/models/comment.dart

class Comment {
  final int? userId;
  final String? profileName; // จาก user_name (alias ฝั่ง PHP)
  final String? pathImgProfile; // จาก avatar_url (alias ฝั่ง PHP)
  final int? rating; // review.rating (1-5)
  final String? comment;
  final DateTime? createdAt;

  Comment({
    this.userId,
    this.profileName,
    this.pathImgProfile,
    this.rating,
    this.comment,
    this.createdAt,
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

    return Comment(
      userId: parseInt(json['user_id']),
      profileName: parseString(json['user_name']), // เปลี่ยนตรงนี้
      pathImgProfile: parseString(json['avatar_url']), // และตรงนี้
      rating: parseInt(json['rating']),
      comment: parseString(json['comment']),
      createdAt: parseDate(json['created_at']),
    );
  }
}
