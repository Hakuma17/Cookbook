import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'json_parser.dart';

/// ปริมาณวัตถุดิบที่ใช้ในสูตร (Ingredient + Quantity)
@immutable
class IngredientQuantity extends Equatable {
  final int ingredientId;
  final String name;
  final String imageUrl;
  final double quantity;
  final String unit;
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
    // ✅ 1. เปลี่ยนมาใช้ JsonParser จากส่วนกลาง
    return IngredientQuantity(
      ingredientId: JsonParser.parseInt(json['ingredient_id']),
      name: JsonParser.parseString(json['name']),
      imageUrl: JsonParser.parseString(json['image_url']),
      quantity: JsonParser.parseDouble(json['quantity']),
      unit: JsonParser.parseString(json['unit']),
      gramsActual: JsonParser.parseDouble(json['grams_actual']),
      description: JsonParser.parseString(json['descrip']),
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

  // ✅ 2. เพิ่มเมธอดมาตรฐานสำหรับ Immutable class
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

  /* ─────────────────────── equatable ─────────────────────── */

  @override
  List<Object?> get props {
    return [
      ingredientId,
      name,
      imageUrl,
      quantity,
      unit,
      gramsActual,
      description,
    ];
  }
}
