// lib/models/cart_ingredient.dart
import 'package:equatable/equatable.dart';
import 'json_parser.dart';

/// Model ของวัตถุดิบในตะกร้า
class CartIngredient extends Equatable {
  final int ingredientId;
  final String name;
  final double quantity;
  final String unit;
  final String imageUrl;
  final bool unitConflict;

  const CartIngredient({
    required this.ingredientId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.imageUrl,
    this.unitConflict = false,
  });

  /// สร้างจาก JSON map
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

  /// แปลงเป็น JSON map
  Map<String, dynamic> toJson() => {
        'ingredient_id': ingredientId,
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'image_url': imageUrl,
        'unit_conflict': unitConflict,
      };

  /// copyWith สำหรับปรับ field บางตัว
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

  /// รวมวัตถุดิบจากหลายเมนู (aggregate) โดยเรียกเมธอดนี้
  static List<CartIngredient> aggregate(List<CartIngredient> list) {
    final Map<String, CartIngredient> map = {};
    final Map<int, Set<String>> tracker = {};

    for (var ing in list) {
      final key = '\${ing.ingredientId}_\${ing.unit}';
      if (map.containsKey(key)) {
        final old = map[key]!;
        map[key] = old.copyWith(quantity: old.quantity + ing.quantity);
      } else {
        map[key] = ing;
      }
      tracker.putIfAbsent(ing.ingredientId, () => {}).add(ing.unit);
    }

    return map.values.map((e) {
      final conflict = (tracker[e.ingredientId]?.length ?? 0) > 1;
      return e.copyWith(unitConflict: conflict);
    }).toList();
  }

  @override
  List<Object?> get props => [
        ingredientId,
        name,
        quantity,
        unit,
        imageUrl,
        unitConflict,
      ];
}
