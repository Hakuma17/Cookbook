// lib/models/cart_response.dart
import 'package:cookbook/models/json_parser.dart';
import 'package:equatable/equatable.dart';
import 'cart_item.dart';

/// Response จาก get_cart_items.php
class CartResponse extends Equatable {
  final int totalItems;
  final List<CartItem> items;

  const CartResponse({
    required this.totalItems,
    required this.items,
  });

  /// สร้างจาก JSON map (อ่าน totalItems & data)
  factory CartResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] as List<dynamic>? ?? [];
    final list = raw.map((e) => CartItem.fromJson(e)).toList();

    final total = json['totalItems'] != null
        ? JsonParser.parseInt(json['totalItems'])
        : list.length;

    return CartResponse(
      totalItems: total,
      items: list,
    );
  }

  /// แปลงเป็น JSON map
  Map<String, dynamic> toJson() => {
        'data': items.map((i) => i.toJson()).toList(),
        'totalItems': totalItems,
      };

  @override
  List<Object?> get props => [totalItems, items];
}
