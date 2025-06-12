// lib/models/recipe.dart

/// โมเดลสำหรับเก็บข้อมูลสูตรอาหารที่เรียกมาจาก API
class Recipe {
  final int id;
  final String name;

  /// พาธไฟล์ดั้งเดิม (ยังเก็บไว้เผื่อใช้)
  final String? imagePath;

  /// URL เต็มของรูปภาพ (ใช้กับ Image.network)
  final String imageUrl;

  /// ระยะเวลาเตรียมอาหาร (หน่วย: นาที) ถ้าไม่มีข้อมูลจะเป็น 0
  final int prepTime;

  /// คะแนนเฉลี่ย เช่น 4.8
  final double averageRating;

  /// จำนวนรีวิว เช่น 25
  final int reviewCount;

  Recipe({
    required this.id,
    required this.name,
    this.imagePath,
    required this.imageUrl,
    required this.prepTime,
    required this.averageRating,
    required this.reviewCount,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 0;
    }

    double parseDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    String parseString(dynamic v, {String fallback = ''}) {
      if (v == null) return fallback;
      final s = v.toString();
      return s.isEmpty ? fallback : s;
    }

    // imagePath ให้เป็น null ถ้าไม่มีหรือเป็นสตริงว่าง
    final rawImagePath = json['image_path'];
    final imgPath = rawImagePath != null && rawImagePath.toString().isNotEmpty
        ? rawImagePath.toString()
        : null;

    return Recipe(
      id: parseInt(json['recipe_id']),
      name: parseString(json['name'], fallback: 'ไม่มีชื่อสูตร'),
      imagePath: imgPath,
      imageUrl: parseString(json['image_url'], fallback: ''),
      prepTime: parseInt(json['prep_time']),
      averageRating: parseDouble(json['average_rating']),
      reviewCount: parseInt(json['review_count']),
    );
  }

  /// แปลงกลับเป็น JSON หากต้องส่งออกกลับไปยัง backend
  Map<String, dynamic> toJson() {
    return {
      'recipe_id': id,
      'name': name,
      'image_path': imagePath,
      'image_url': imageUrl,
      'prep_time': prepTime,
      'average_rating': averageRating,
      'review_count': reviewCount,
    };
  }
}
