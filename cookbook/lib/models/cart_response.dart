import 'package:equatable/equatable.dart';

import 'cart_item.dart';
import 'json_parser.dart';

/// ผลลัพธ์จาก API **get_cart_items.php**
///
/// * `totalItems` – จำนวนเมนูในตะกร้าทั้งหมด
/// * `items`      – รายละเอียดแต่ละเมนู (scaled-ingredient พร้อม flag ต่าง ๆ)
class CartResponse extends Equatable {
  final int totalItems;
  final List<CartItem> items;

  const CartResponse({
    required this.totalItems,
    required this.items,
  });

  /* ───────────────────────── factory ───────────────────────── */

  /// รับโครงสร้าง JSON จาก PHP
  ///
  /// ```json
  /// {
  ///   "success": true,
  ///   "totalItems": 3,
  ///   "data": [ {..CartItem..}, ... ]
  /// }
  /// ```
  factory CartResponse.fromJson(Map<String, dynamic> json) {
    final rawList = json['data'] as List<dynamic>? ?? const [];
    final itemList = rawList.map((e) => CartItem.fromJson(e)).toList();

    final total = json['totalItems'] != null
        ? JsonParser.parseInt(json['totalItems'])
        : itemList.length;

    return CartResponse(
      totalItems: total,
      items: itemList,
    );
  }

  /* ───────────────────────── toJson ───────────────────────── */

  Map<String, dynamic> toJson() => {
        'totalItems': totalItems,
        'data': items.map((e) => e.toJson()).toList(),
      };

  /* ───────────────────────── equatable ───────────────────────── */

  @override
  List<Object?> get props => [totalItems, items];
}
