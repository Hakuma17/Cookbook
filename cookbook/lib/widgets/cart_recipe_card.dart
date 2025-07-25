import 'package:flutter/material.dart';
import '../models/cart_item.dart';

/// การ์ดสูตรในตะกร้า
class CartRecipeCard extends StatelessWidget {
  final CartItem cartItem;
  final VoidCallback onTapEditServings;
  final VoidCallback onDelete;

  const CartRecipeCard({
    super.key,
    required this.cartItem,
    required this.onTapEditServings,
    required this.onDelete,
  });

  //  1. เปลี่ยนไปใช้ Named Route เพื่อความสอดคล้อง
  void _openDetail(BuildContext context) {
    Navigator.pushNamed(
      context,
      '/recipe_detail',
      arguments: cartItem.recipeId, // ส่ง ID ไปแทน Object
    );
  }

  @override
  Widget build(BuildContext context) {
    //  2. ลบ Manual Responsive Calculation และใช้ Theme
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: 180, // กำหนดความกว้างคงที่ เหมาะสำหรับ Horizontal ListView
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // --- Card หลัก ---
          Card(
            // Card จะใช้สไตล์จาก CardTheme ใน main.dart
            margin: const EdgeInsets.only(top: 8, right: 8),
            child: InkWell(
              onTap: () => _openDetail(context),
              borderRadius:
                  BorderRadius.circular(12), // ทำให้ splash effect โค้งตาม Card
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- รูปภาพ และ Badge จำนวนเสิร์ฟ ---
                  SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                          child: Image.network(
                            cartItem.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: colorScheme.surfaceVariant,
                              child: Icon(Icons.image_not_supported_outlined,
                                  color: colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: InkWell(
                            onTap: onTapEditServings,
                            child: Chip(
                              avatar: Icon(Icons.person,
                                  size: 16,
                                  color: colorScheme.onSecondaryContainer),
                              label: Text('${cartItem.nServings} คน'),
                              labelStyle: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSecondaryContainer),
                              backgroundColor: colorScheme.secondaryContainer,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // --- ชื่อเมนู ---
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      cartItem.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- ปุ่มลบ ---
          // 3. เปลี่ยนมาใช้ IconButton ที่จัดสไตล์ได้ง่ายกว่า
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.close),
              iconSize: 18,
              tooltip: 'ลบออกจากตะกร้า',
              onPressed: onDelete,
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
                padding: const EdgeInsets.all(4),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ✅ 4. Refactor _ServingsPicker ให้เป็น Widget สาธารณะและใช้ Theme
// ⭐️ แนะนำ: ย้าย Widget นี้ไปไว้ในไฟล์ของตัวเอง (เช่น lib/widgets/servings_picker.dart)
//    เพื่อให้หน้าจออื่น (เช่น MyRecipesScreen) สามารถเรียกใช้ได้โดยไม่ต้องมีโค้ดซ้ำซ้อน
class ServingsPicker extends StatelessWidget {
  final int initialServings;
  const ServingsPicker({super.key, required this.initialServings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final maxHeight = MediaQuery.of(context).size.height * 0.55;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child:
                  Text('เลือกจำนวนที่รับประทาน', style: textTheme.titleLarge),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: 10,
                itemBuilder: (_, i) {
                  final servings = i + 1;
                  final isSelected = servings == initialServings;

                  return ListTile(
                    title: Text(
                      '$servings คน',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? theme.colorScheme.primary : null,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check, color: theme.colorScheme.primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(servings),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
