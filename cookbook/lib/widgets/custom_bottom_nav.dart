import 'package:flutter/material.dart';

class CustomBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final bool isLoggedIn;

  const CustomBottomNav({
    Key? key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.isLoggedIn,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const items = [
      Icons.home,
      Icons.explore,
      Icons.menu_book,
      Icons.person_outline,
    ];

    return Container(
      height: 80,
      padding: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE1E1E1), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final selected = i == selectedIndex;
          return GestureDetector(
            onTap: () {
              // ถ้าหน้า Recipe หรือ Profile แต่ยังไม่ได้ล็อกอิน
              if ((i == 2 || i == 3) && !isLoggedIn) {
                // ให้ไป login แล้วค่อยเรียก callback
                Navigator.pushNamed(context, '/login');
              } else {
                onItemSelected(i);
              }
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: selected
                  ? const BoxDecoration(
                      border: Border(
                        bottom:
                            BorderSide(color: Color(0xFFFF9B05), width: 2.2),
                      ),
                    )
                  : null,
              child: Icon(
                items[i],
                size: 26,
                color: selected
                    ? const Color(0xFFFF9B05)
                    : const Color(0xFFC1C1C1),
              ),
            ),
          );
        }),
      ),
    );
  }
}
