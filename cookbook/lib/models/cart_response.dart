import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'cart_item.dart';
import 'json_parser.dart';

/// ผลลัพธ์จาก API **get_cart_items.php**
@immutable
class CartResponse extends Equatable {
  final int totalItems;
  final List<CartItem> items;

  const CartResponse({
    required this.totalItems,
    required this.items,
  });

  /* ───────────────────────── factory ───────────────────────── */

  factory CartResponse.fromJson(Map<String, dynamic> json) {
    final rawList = json['data'] as List<dynamic>? ?? const [];
    final itemList = rawList.map((e) => CartItem.fromJson(e)).toList();

    // ถ้า API ไม่ได้ส่ง totalItems มา, ให้ใช้จำนวน item ใน list แทน
    final total = json['totalItems'] != null
        ? JsonParser.parseInt(json['totalItems'])
        : itemList.length;

    return CartResponse(
      totalItems: total,
      items: itemList,
    );
  }

  /* ───────────────── toJson / copyWith ───────────────── */

  Map<String, dynamic> toJson() => {
        'totalItems': totalItems,
        'data': items.map((e) => e.toJson()).toList(),
      };

  CartResponse copyWith({
    int? totalItems,
    List<CartItem>? items,
  }) {
    return CartResponse(
      totalItems: totalItems ?? this.totalItems,
      items: items ?? this.items,
    );
  }

  /* ───────────────────── equatable ───────────────────── */

  @override
  List<Object?> get props => [totalItems, items];
}
