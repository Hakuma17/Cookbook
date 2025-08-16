import 'package:equatable/equatable.dart';
import 'json_parser.dart';

/// วัตถุดิบ 1 รายการที่ถูก “รวม” เข้ามาอยู่ในตะกร้า
///
/// ใช้กับผลลัพธ์จาก `get_cart_items.php`
/// - หลังบ้านจะคูณสัดส่วนเสิร์ฟให้เรียบร้อยแล้ว
/// - ถ้ามีหลายเมนูใช้วัตถุดิบเดียวกันแต่คนละหน่วย จะถูกแยกคนละรายการ
class CartIngredient extends Equatable {
  /* ───── fields ───── */

  /// ไอดีวัตถุดิบตามตาราง `ingredients`
  final int ingredientId;

  /// ชื่อวัตถุดิบมาตรฐาน (เช่น กุ้ง, กระเทียม)
  final String name;

  /// ปริมาณตามหน่วยที่กำหนด
  final double quantity;

  /// หน่วย (เช่น “กรัม”, “ช้อนโต๊ะ”)
  final String unit;

  /// URL ของภาพวัตถุดิบ
  final String imageUrl;

  /// ธงว่ามีเมนูอื่นในตะกร้าใช้ “หน่วยคนละชนิด” กับรายการนี้หรือไม่
  final bool unitConflict;

  /// [NEW] ธงว่า “ผู้ใช้แพ้วัตถุดิบในกลุ่มนี้” หรือไม่
  ///
  /// มาจากการคำนวณฝั่งเซิร์ฟเวอร์โดยเทียบกลุ่ม `newcatagory`
  /// ของวัตถุดิบบนเมนูกับกลุ่มของรายการแพ้ (`allergyinfo`)
  final bool hasAllergy;

  const CartIngredient({
    required this.ingredientId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.imageUrl,
    this.unitConflict = false,
    this.hasAllergy = false, // [NEW]
  });

  /* ───── factories ───── */

  factory CartIngredient.fromJson(Map<String, dynamic> json) {
    return CartIngredient(
      ingredientId: JsonParser.parseInt(json['ingredient_id']),
      name: JsonParser.parseString(json['name']),
      quantity: JsonParser.parseDouble(json['quantity']),
      unit: JsonParser.parseString(json['unit']),
      imageUrl: JsonParser.parseString(json['image_url']),
      unitConflict: JsonParser.parseBool(json['unit_conflict']) ?? false,
      hasAllergy: JsonParser.parseBool(json['has_allergy']) ?? false, // [NEW]
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
        'has_allergy': hasAllergy, // [NEW]
      };

  /* ───── util: copyWith ───── */

  CartIngredient copyWith({
    int? ingredientId,
    String? name,
    double? quantity,
    String? unit,
    String? imageUrl,
    bool? unitConflict,
    bool? hasAllergy, // [NEW]
  }) {
    return CartIngredient(
      ingredientId: ingredientId ?? this.ingredientId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      imageUrl: imageUrl ?? this.imageUrl,
      unitConflict: unitConflict ?? this.unitConflict,
      hasAllergy: hasAllergy ?? this.hasAllergy,
    );
  }

  /* ───── static helper: aggregate ─────
   * รวมวัตถุดิบจากเมนูหลายจาน → หาผลรวมปริมาณ และตั้งธง unitConflict
   *
   * หมายเหตุ:
   * - ถ้ารายการที่รวมกันมี hasAllergy อย่างน้อย 1 รายการ ให้ผลลัพธ์เป็น true
   * - แยกคีย์รวมด้วย ingredientId+unit เพื่อไม่รวมหน่วยต่างชนิดเข้าด้วยกัน
   */
  static List<CartIngredient> aggregate(List<CartIngredient> list) {
    final Map<String, CartIngredient> merged = {};
    final Map<int, Set<String>> unitTracker = {};

    for (final ing in list) {
      final key = '${ing.ingredientId}_${ing.unit}';

      merged.update(
        key,
        (existing) => existing.copyWith(
          quantity: existing.quantity + ing.quantity,
          // [NEW] OR ธงแพ้ ถ้ามีรายการใดรายการหนึ่งเป็น true
          hasAllergy: existing.hasAllergy || ing.hasAllergy,
        ),
        ifAbsent: () => ing,
      );

      unitTracker.putIfAbsent(ing.ingredientId, () => {}).add(ing.unit);
    }

    // ตั้งธงหน่วยไม่ตรงกันระดับ ingredientId
    return merged.values.map((e) {
      final hasConflict = (unitTracker[e.ingredientId]?.length ?? 0) > 1;
      return hasConflict ? e.copyWith(unitConflict: true) : e;
    }).toList();
  }

  /* ───── equatable ───── */

  @override
  List<Object?> get props =>
      [ingredientId, name, quantity, unit, imageUrl, unitConflict, hasAllergy];
}
