// lib/models/ingredient.dart

/// โมเดลสำหรับวัตถุดิบ (Ingredient)
class Ingredient {
  final int id;
  final String name;
  final String imageUrl; // URL เต็มของรูปภาพวัตถุดิบ
  final String category; // หมวดหมู่วัตถุดิบ เช่น ผัก, เนื้อสัตว์, เครื่องปรุง

  Ingredient({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.category,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v == null) return 0;
      return v is int ? v : int.tryParse(v.toString()) ?? 0;
    }

    String parseString(dynamic v, [String fallback = '']) {
      if (v == null) return fallback;
      final s = v.toString();
      return s.isEmpty ? fallback : s;
    }

    return Ingredient(
      id: parseInt(json['ingredient_id']),
      name: parseString(json['name'], 'ไม่ระบุชื่อ'),
      imageUrl: parseString(json['image_url'], ''),
      category: parseString(json['category'], '-'),
    );
  }
}
