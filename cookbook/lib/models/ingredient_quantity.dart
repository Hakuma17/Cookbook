class IngredientQuantity {
  final int ingredientId;
  final String name; // ชื่อมาตรฐานของวัตถุดิบ (จาก ingredients.name)
  final String imageUrl; // URL ของภาพวัตถุดิบ
  final double quantity; // จำนวนที่ใช้ในสูตร
  final String unit; // หน่วย เช่น "ช้อนโต๊ะ", "กรัม"
  final double gramsActual; // น้ำหนักกรัมที่แท้จริง (ใช้คำนวณโภชนาการ)
  final String description; // คำอธิบายเฉพาะในสูตร เช่น "หมูสามชั้นหั่นชิ้น"

  IngredientQuantity({
    required this.ingredientId,
    required this.name,
    required this.imageUrl,
    required this.quantity,
    required this.unit,
    required this.gramsActual,
    required this.description,
  });

  factory IngredientQuantity.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v == null) return 0;
      return int.tryParse(v.toString()) ?? 0;
    }

    double parseDouble(dynamic v) {
      if (v == null) return 0.0;
      return double.tryParse(v.toString()) ?? 0.0;
    }

    String parseString(dynamic v) {
      if (v == null) return '';
      return v.toString();
    }

    return IngredientQuantity(
      ingredientId: parseInt(json['ingredient_id']),
      name: parseString(json['name']), // ใช้สำหรับ fallback หรืออ้างอิง
      imageUrl: parseString(json['image_url']),
      quantity: parseDouble(json['quantity']),
      unit: parseString(json['unit']),
      gramsActual: parseDouble(json['grams_actual']),
      description: parseString(json['descrip']), // ← เปลี่ยนตรงนี้ให้ชัดเจน
    );
  }
}
