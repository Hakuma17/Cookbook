import 'package:flutter/material.dart';

/// แถบเมนูล่างหลักของแอป
/// - selectedIndex: ดัชนีแท็บที่ถูกเลือก (0=Home,1=Explore,2=My Recipes,3=Profile)
/// - onItemSelected: callback เมื่อต้องการสลับแท็บหรือรีเฟรช
/// - isLoggedIn: สถานะล็อกอิน (ใช้แสดง icon / สี ตามสถานะ)
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
      Icons.list_alt,
      Icons.person,
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
              onItemSelected(i); // แจ้ง parent เสมอ

              if (i == selectedIndex) return; // ถ้ากดซ้ำไม่ต้องทำ navigator ซ้ำ

              switch (i) {
                case 0:
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/home', (route) => false);
                  break;
                case 1:
                  Navigator.pushNamed(context, '/search');
                  break;
                case 2:
                  Navigator.pushReplacementNamed(
                    context,
                    '/my_recipes',
                    arguments:
                        0, // ← เพิ่มตรงนี้ให้ชัดเจนว่า default ต้องใช้แท็บ 0
                  );
                  break;
                case 3:
                  Navigator.pushReplacementNamed(context, '/profile');
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
