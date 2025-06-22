/// ข้อมูลวัตถุดิบ (Ingredient) ที่ดึงจาก API
class Ingredient {
  final int id; // ingredient_id
  final String name; // ชื่อ (ภาษาไทย / ค่า default)
  final String imageUrl; // URL เต็มของรูปภาพ
  final String category; // หมวดหมู่ เช่น “ผัก”, “เนื้อสัตว์”
  final String? displayName; // ชื่อทางการตลาด / ชื่อตามฉลาก (อาจเป็น null)

  const Ingredient({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.category,
    this.displayName,
  });

  /* ───────────────────────── factory ───────────────────────── */

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    int _int(dynamic v) =>
        v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);

    String _str(dynamic v, {String fallback = ''}) {
      if (v == null) return fallback;
      final s = v.toString();
      return s.isEmpty ? fallback : s;
    }

    return Ingredient(
      id: _int(json['ingredient_id']),
      name: _str(json['name'], fallback: 'ไม่ระบุชื่อ'),
      imageUrl: _str(json['image_url']),
      category: _str(json['category'], fallback: '-'),
      displayName: json['display_name']?.toString(),
    );
  }

  /* ───────────────────────── toJson ───────────────────────── */

  Map<String, dynamic> toJson() => {
        'ingredient_id': id,
        'name': name,
        'image_url': imageUrl,
        'category': category,
        'display_name': displayName,
      };
}
