import 'package:flutter/material.dart';

/// แถบเมนูล่างหลักของแอป
/// 0 = Home, 1 = Explore, 2 = My Recipes, 3 = Profile
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
    /* ── responsive metrics ── */
    final w = MediaQuery.of(context).size.width;
    double clamp(double v, double min, double max) =>
        v < min ? min : (v > max ? max : v);

    final barH = clamp(w * 0.18, 56, 88); // total height
    final iconSz = clamp(w * 0.065, 22, 30); // icon size
    final boxW = clamp(w * 0.12, 44, 64); // width/height hit box
    final padBot = clamp(w * 0.03, 8, 16); // bottom padding

    const items = [
      Icons.home,
      Icons.explore,
      Icons.list_alt,
      Icons.person,
    ];

    return Container(
      height: barH,
      padding: EdgeInsets.only(bottom: padBot),
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
              /* แจ้ง parent เสมอ (เช่น refresh) */
              onItemSelected(i);

              if (i == selectedIndex) return; // กดซ้ำไม่เปลี่ยน route

              switch (i) {
                case 0:
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/home', (_) => false);
                  break;
                case 1:
                  Navigator.pushNamed(context, '/search');
                  break;
                case 2:
                  Navigator.pushReplacementNamed(context, '/my_recipes',
                      arguments: 0);
                  break;
                case 3:
                  Navigator.pushReplacementNamed(context, '/profile');
                  break;
              }
            },
            child: Container(
              width: boxW,
              height: boxW,
              decoration: selected
                  ? const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFFF9B05), width: 2),
                      ),
                    )
                  : null,
              alignment: Alignment.center,
              child: Icon(
                items[i],
                size: iconSz,
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
