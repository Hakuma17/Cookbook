/// ปริมาณวัตถุดิบที่ใช้ในสูตร (Ingredient + Quantity)
///
/// - ใช้ทั้งสำหรับแสดงผลใน UI และคำนวณโภชนาการ
class IngredientQuantity {
  final int ingredientId; // ingredient_id
  final String name; // ชื่อวัตถุดิบมาตรฐาน (ingredients.name)
  final String imageUrl; // URL ภาพวัตถุดิบ (ขนาดเล็ก)
  final double quantity; // จำนวนที่ใช้ตามสูตร
  final String unit; // หน่วย เช่น “ช้อนโต๊ะ”, “กรัม”
  final double gramsActual; // น้ำหนักกรัมจริง (สำหรับคำนวณ nutrition)
  final String description; // คำอธิบายเฉพาะ (เช่น “หมูสามชั้นหั่นชิ้น”)

  const IngredientQuantity({
    required this.ingredientId,
    required this.name,
    required this.imageUrl,
    required this.quantity,
    required this.unit,
    required this.gramsActual,
    required this.description,
  });

  /* ───────────────────────── factory ───────────────────────── */

  factory IngredientQuantity.fromJson(Map<String, dynamic> json) {
    int _int(dynamic v) =>
        v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);
    double _dbl(dynamic v) => v == null
        ? 0.0
        : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
    String _str(dynamic v) => v?.toString() ?? '';

    return IngredientQuantity(
      ingredientId: _int(json['ingredient_id']),
      name: _str(json['name']),
      imageUrl: _str(json['image_url']),
      quantity: _dbl(json['quantity']),
      unit: _str(json['unit']),
      gramsActual: _dbl(json['grams_actual']),
      description: _str(json['descrip']), // backend field = “descrip”
    );
  }

  /* ───────────────────────── toJson ───────────────────────── */

  Map<String, dynamic> toJson() => {
        'ingredient_id': ingredientId,
        'name': name,
        'image_url': imageUrl,
        'quantity': quantity,
        'unit': unit,
        'grams_actual': gramsActual,
        'descrip': description,
      };
}
