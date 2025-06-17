import 'package:flutter/material.dart';

/// แถบเมนูล่างหลักของแอป
/// - selectedIndex: ดัชนีแท็บที่ถูกเลือก (0=Home,1=Explore,2=My Recipes,3=Profile)
/// - onItemSelected: callback เมื่อต้องการสลับแท็บ (Home, Explore)
/// - isLoggedIn: สถานะล็อกอิน (ใช้ตรวจก่อนเปิด My Recipes / Profile)
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
    // ไอคอนเมนู 4 ตัว
    const items = [
      Icons.home,
      Icons.explore,
      Icons.list_alt, // คลังของฉัน
      Icons.person, // โปรไฟล์
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
              switch (i) {
                case 0:
                case 1:
                  // สลับแท็บ Home / Explore
                  onItemSelected(i);
                  break;
                case 2:
                  // คลังของฉัน (My Recipes)
                  if (!isLoggedIn) {
                    Navigator.pushNamed(context, '/login');
                  } else {
                    Navigator.pushNamed(
                      context,
                      '/myrecipes',
                      arguments: 0, // เปิดที่ Favorites
                    );
                  }
                  break;
                case 3:
                  // โปรไฟล์
                  if (!isLoggedIn) {
                    Navigator.pushNamed(context, '/login');
                  } else {
                    Navigator.pushNamed(context, '/profile');
                  }
                  break;
              }
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: selected
                  ? const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Color(0xFFFF9B05),
                          width: 2.2,
                        ),
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
