import 'package:flutter/material.dart';

/// CartButton
/// ปุ่มใส่ตะกร้า และปุ่มเลือกจำนวนเสิร์ฟ
class CartButton extends StatelessWidget {
  final int recipeId;
  final int currentServings;
  final ValueChanged<int>? onServingsChanged;
  final VoidCallback? onAddToCart;

  const CartButton({
    Key? key,
    required this.recipeId,
    this.currentServings = 1,
    this.onServingsChanged,
    this.onAddToCart,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFFCC09C);
    const accentColor = Color(0xFFFF9B05);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ปุ่มใส่ตะกร้า
        InkWell(
          onTap: onAddToCart,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: borderColor, width: 1.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.shopping_cart_outlined,
              size: 24,
              color: borderColor,
            ),
          ),
        ),
        const SizedBox(width: 12),

        // ปุ่มเลือกจำนวนเสิร์ฟ
        InkWell(
          onTap: () async {
            final selected = await showModalBottomSheet<int>(
              context: context,
              isScrollControlled: true,
              builder: (_) => _ServingsPicker(
                initialServings: currentServings,
              ),
            );

            //  เพิ่ม delay เพื่อให้ pop() เสร็จก่อนเรียก callback
            if (selected != null) {
              await Future.delayed(Duration.zero);
              onServingsChanged?.call(selected);
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: borderColor, width: 1.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_outline, size: 20, color: Colors.black),
                const SizedBox(width: 4),
                Text(
                  '$currentServings',
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF000000),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down,
                    size: 20, color: accentColor),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// หน้าต่างให้เลือกจำนวนเสิร์ฟ (1–10 คน)
class _ServingsPicker extends StatelessWidget {
  final int initialServings;

  const _ServingsPicker({Key? key, required this.initialServings})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.5;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: 10,
            itemBuilder: (ctx, index) {
              final serving = index + 1;
              return ListTile(
                title: Text(
                  '$serving คน',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: serving == initialServings
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
                onTap: () => Navigator.of(context).pop(serving),
              );
            },
          ),
        ),
      ),
    );
  }
}
