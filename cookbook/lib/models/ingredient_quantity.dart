// lib/models/ingredient_quantity.dart
//
// ปริมาณวัตถุดิบที่ใช้ในสูตร (Ingredient + Quantity)
// - รองรับจำนวนกรัมจริง (gramsActual) ถ้า BE ส่งมา
// - มี helper สำหรับแสดงผลตามโหมดหน่วย (หน่วยเดิม / กรัม)

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'json_parser.dart';
import 'unit_display_mode.dart'; // แสดงผลตามโหมด
import '../utils/unit_convert.dart'; // แปลงหน่วยแบบประมาณค่า (≈)

@immutable
class IngredientQuantity extends Equatable {
  final int ingredientId;
  final String name;
  final String imageUrl;
  final double quantity;
  final String unit;

  /// กรัมจริงของปริมาณนี้ (ถ้า BE คำนวณมาให้)
  final double gramsActual;
  final String description;

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
    // รองรับ alias หลายแบบจาก BE ที่อาจต่างกัน
    return IngredientQuantity(
      ingredientId: JsonParser.parseInt(
        json['ingredient_id'] ?? json['id'] ?? json['ingredientId'],
      ),
      name: JsonParser.parseString(
        json['name'] ?? json['ingredient_name'] ?? json['title'],
      ),
      imageUrl: JsonParser.parseString(
        json['image_url'] ?? json['image'] ?? json['image_path'],
      ),
      quantity: JsonParser.parseDouble(
        json['quantity'] ?? json['qty'],
      ),
      unit: JsonParser.parseString(
        json['unit'] ?? json['uom'] ?? '',
      ),
      gramsActual: JsonParser.parseDouble(
        json['grams_actual'] ?? json['grams'] ?? json['g'],
      ),
      description: JsonParser.parseString(
        json['descrip'] ?? json['description'] ?? json['desc'],
      ),
    );
  }

  /* ─────────────────── toJson / copyWith ─────────────────── */

  Map<String, dynamic> toJson() => {
        'ingredient_id': ingredientId,
        'name': name,
        'image_url': imageUrl,
        'quantity': quantity,
        'unit': unit,
        'grams_actual': gramsActual,
        'descrip': description,
      };

  IngredientQuantity copyWith({
    int? ingredientId,
    String? name,
    String? imageUrl,
    double? quantity,
    String? unit,
    double? gramsActual,
    String? description,
  }) {
    return IngredientQuantity(
      ingredientId: ingredientId ?? this.ingredientId,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      gramsActual: gramsActual ?? this.gramsActual,
      description: description ?? this.description,
    );
  }

  /* ─────────────────────── helpers ─────────────────────── */

  /// มีกรัมจริงจากหลังบ้านหรือไม่
  bool get hasGrams => gramsActual > 0;

  /// กรัมที่ใช้ “แสดงผล”
  /// - ถ้ามี gramsActual → ใช้ตรง ๆ
  /// - ถ้าไม่มี → ประมาณค่า (≈) จากหน่วยที่รู้จัก (ถ้วย/ชต./ชช./ฯลฯ)
  double? get gramsForDisplay =>
      hasGrams ? gramsActual : UnitConvert.approximateGrams(quantity, unit);

  /// จัดข้อความปริมาณตามโหมดแสดงผล
  String formatAmount(UnitDisplayMode mode) {
    switch (mode) {
      case UnitDisplayMode.original:
        return '${UnitConvert.fmtNum(quantity)} $unit';
      case UnitDisplayMode.grams:
        final g = gramsForDisplay;
        if (g == null) {
          // แปลงไม่ได้ → fallback เป็นหน่วยเดิม
          return '${UnitConvert.fmtNum(quantity)} $unit';
        }
        final approx = hasGrams ? '' : '≈ ';
        return '$approx${UnitConvert.fmtGrams(g)}';
    }
  }

  /// สร้างออบเจ็กต์ใหม่โดยคูณปริมาณด้วย factor (ใช้เวลาปรับจำนวนเสิร์ฟ)
  IngredientQuantity scaled(double factor) => copyWith(
        quantity: quantity * factor,
        gramsActual: hasGrams ? gramsActual * factor : gramsActual,
      );

  @override
  List<Object?> get props => [
        ingredientId,
        name,
        imageUrl,
        quantity,
        unit,
        gramsActual,
        description,
      ];

  @override
  String toString() =>
      'IngredientQuantity(id=$ingredientId, name=$name, qty=$quantity $unit, grams=$gramsActual)';
}
