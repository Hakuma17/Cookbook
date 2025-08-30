// lib/models/cart_ingredient.dart
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'json_parser.dart';

/// วัตถุดิบ 1 รายการที่ถูก “รวม” เข้ามาอยู่ในตะกร้า
///
/// ใช้กับผลลัพธ์จาก `get_cart_items.php` / `get_cart_ingredients.php`
/// - หลังบ้านจะคูณสัดส่วนเสิร์ฟให้เรียบร้อยแล้ว
/// - ถ้ามีหลายเมนูใช้วัตถุดิบเดียวกันแต่คนละหน่วย จะถูกแยกคนละรายการ (unit-based)
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

  /// ธงว่า “ผู้ใช้แพ้วัตถุดิบในกลุ่มนี้” หรือไม่ (มาจาก BE)
  final bool hasAllergy;

  /// [NEW] กรัมจริงของรายการนี้ (ถ้า BE ส่งมา) — ใช้โชว์โหมด “กรัม”
  /// - ถ้า BE ไม่ส่งมา ให้เป็น null เพื่อให้ FE ประมาณ (≈) ตาม unit แทน
  final double? gramsActual;

  /// [GROUP] กลุ่มวัตถุดิบแบบรหัส 2 หลัก (เช่น '04' = ผัก)
  final String? groupCode;

  /// [GROUP] ชื่อกลุ่มแบบสั้น ๆ (เช่น 'ผัก')
  final String? groupName;

  /// [GROUP] รหัสโภชนาการดิบที่มาจากตาราง nutrition (เช่น '04250')
  final String? nutritionId;

  const CartIngredient({
    required this.ingredientId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.imageUrl,
    this.unitConflict = false,
    this.hasAllergy = false,
    this.gramsActual,
    this.groupCode,
    this.groupName,
    this.nutritionId,
  });

  /* ───── factories ───── */

  factory CartIngredient.fromJson(Map<String, dynamic> json) {
    return CartIngredient(
      // รองรับทั้ง ingredient_id และ id จาก BE
      ingredientId: JsonParser.parseInt(json['ingredient_id'] ?? json['id']),
      name: JsonParser.parseString(json['name']),
      quantity: JsonParser.parseDouble(json['quantity']),
      unit: JsonParser.parseString(json['unit']),
      imageUrl: JsonParser.parseString(json['image_url']),
      unitConflict: JsonParser.parseBool(json['unit_conflict']) ?? false,
      hasAllergy: JsonParser.parseBool(json['has_allergy']) ?? false,

      // ถ้าไม่มี key ให้คงเป็น null เพื่อให้ FE ใช้ค่าประมาณ (≈)
      gramsActual: json['grams_actual'] == null
          ? null
          : JsonParser.parseDouble(json['grams_actual']),

      groupCode: json['group_code'] == null
          ? null
          : JsonParser.parseString(json['group_code']),
      groupName: json['group_name'] == null
          ? null
          : JsonParser.parseString(json['group_name']),
      nutritionId: json['nutrition_id'] == null
          ? null
          : JsonParser.parseString(json['nutrition_id']),
    );
  }

  /* ───── serialization ───── */

  Map<String, dynamic> toJson() => {
        'ingredient_id': ingredientId,
        'id': ingredientId, // เผื่อระบบที่อ่านเป็น id
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'image_url': imageUrl,
        'unit_conflict': unitConflict,
        'has_allergy': hasAllergy,
        'grams_actual': gramsActual,
        'group_code': groupCode,
        'group_name': groupName,
        'nutrition_id': nutritionId,
      };

  /* ───── util: copyWith ───── */

  CartIngredient copyWith({
    int? ingredientId,
    String? name,
    double? quantity,
    String? unit,
    String? imageUrl,
    bool? unitConflict,
    bool? hasAllergy,
    // ★ แก้ไข: ใช้ ValueGetter เพื่อให้สามารถตั้งค่ากลับไปเป็น null ได้
    ValueGetter<double?>? gramsActual,
    ValueGetter<String?>? groupCode,
    ValueGetter<String?>? groupName,
    ValueGetter<String?>? nutritionId,
  }) {
    return CartIngredient(
      ingredientId: ingredientId ?? this.ingredientId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      imageUrl: imageUrl ?? this.imageUrl,
      unitConflict: unitConflict ?? this.unitConflict,
      hasAllergy: hasAllergy ?? this.hasAllergy,
      // ★ แก้ไข: ตรวจสอบว่ามีการส่งค่าใหม่มาหรือไม่ ถ้ามีให้ใช้ค่าใหม่ (ซึ่งอาจเป็น null)
      gramsActual: gramsActual != null ? gramsActual() : this.gramsActual,
      groupCode: groupCode != null ? groupCode() : this.groupCode,
      groupName: groupName != null ? groupName() : this.groupName,
      nutritionId: nutritionId != null ? nutritionId() : this.nutritionId,
    );
  }

  // ★ ลบ: เมธอด aggregate ถูกลบออกไป เพราะ Logic การรวมถูกย้ายไปที่ Backend แล้ว

  /* ───── equatable ───── */

  @override
  List<Object?> get props => [
        ingredientId,
        name,
        quantity,
        unit,
        imageUrl,
        unitConflict,
        hasAllergy,
        gramsActual,
        groupCode,
        groupName,
        nutritionId,
      ];
}
