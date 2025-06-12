// cart_item.dart
// โมเดลข้อมูลวัตถุดิบในตะกร้า

class CartItem {
  final int ingredientId; // รหัสวัตถุดิบ
  final String name; // ชื่อวัตถุดิบ
  final double quantity; // ปริมาณรวมทั้งหมดจากทุกสูตร
  final String unit; // หน่วย เช่น ฟอง, กรัม, ถ้วย
  final String imageUrl; // URL รูปภาพวัตถุดิบ

  CartItem({
    required this.ingredientId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.imageUrl,
  });

  /// ฟังก์ชันแปลง JSON -> CartItem
  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      ingredientId: json['ingredient_id'] as int,
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      imageUrl: json['image_url'] as String,
    );
  }
}
