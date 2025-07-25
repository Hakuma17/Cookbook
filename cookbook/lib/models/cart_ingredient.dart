import 'package:equatable/equatable.dart';
import 'json_parser.dart';

/// **วัตถุดิบ 1 รายการ** ที่ถูก *merge* เข้ามาอยู่ในตะกร้า
/// (เกิดจากการรวมวัตถุดิบของเมนูหลาย ๆ จาน)
class CartIngredient extends Equatable {
  /* ───── fields ───── */

  final int ingredientId; // id วัตถุดิบตาม table `ingredients`
  final String name; // ชื่อวัตถุดิบมาตรฐาน
  final double quantity; // ปริมาณ (ตามหน่วย)
  final String unit; // หน่วย (เช่น “กรัม”, “ช้อนโต๊ะ”)
  final String imageUrl; // URL ภาพวัตถุดิบ
  final bool unitConflict; // true ถ้าเมนูอื่นใช้ “หน่วยคนละชนิด”

  const CartIngredient({
    required this.ingredientId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.imageUrl,
    this.unitConflict = false,
  });

  /* ───── factories ───── */

  factory CartIngredient.fromJson(Map<String, dynamic> json) {
    return CartIngredient(
      ingredientId: JsonParser.parseInt(json['ingredient_id']),
      name: JsonParser.parseString(json['name']),
      quantity: JsonParser.parseDouble(json['quantity']),
      unit: JsonParser.parseString(json['unit']),
      imageUrl: JsonParser.parseString(json['image_url']),
      unitConflict: JsonParser.parseBool(json['unit_conflict']),
    );
  }

  /* ───── serialization ───── */

  Map<String, dynamic> toJson() => {
        'ingredient_id': ingredientId,
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'image_url': imageUrl,
        'unit_conflict': unitConflict,
      };

  /* ───── util: copyWith ───── */

  CartIngredient copyWith({
    int? ingredientId,
    String? name,
    double? quantity,
    String? unit,
    String? imageUrl,
    bool? unitConflict,
  }) {
    return CartIngredient(
      ingredientId: ingredientId ?? this.ingredientId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      imageUrl: imageUrl ?? this.imageUrl,
      unitConflict: unitConflict ?? this.unitConflict,
    );
  }

  /* ───── static helper: aggregate ─────
   * รวมวัตถุดิบจากเมนูหลายจาน → หาผลรวม & flag หน่วยไม่ตรง
   */
  static List<CartIngredient> aggregate(List<CartIngredient> list) {
    final Map<String, CartIngredient> merged = {};
    final Map<int, Set<String>> unitTracker = {};

    for (final ing in list) {
      final key = '${ing.ingredientId}_${ing.unit}';

      // รวมปริมาณถ้า ingredientId-unit ซ้ำ
      merged.update(
        key,
        (existing) =>
            existing.copyWith(quantity: existing.quantity + ing.quantity),
        ifAbsent: () => ing,
      );

      // เก็บว่า ingredientId นี้มีหน่วยอะไรบ้าง
      unitTracker.putIfAbsent(ing.ingredientId, () => {}).add(ing.unit);
    }

    // ตรวจ flag หน่วยไม่เหมือนกัน
    return merged.values.map((e) {
      final hasConflict = (unitTracker[e.ingredientId]?.length ?? 0) > 1;
      // คืนค่า object เดิมถ้าไม่มี conflict, หรือสร้างใหม่ถ้ามี
      return hasConflict ? e.copyWith(unitConflict: true) : e;
    }).toList();
  }

  /* ───── equatable ───── */

  @override
  List<Object?> get props =>
      [ingredientId, name, quantity, unit, imageUrl, unitConflict];
}
