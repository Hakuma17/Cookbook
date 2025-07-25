// lib/widgets/custom_bottom_nav.dart

import 'package:flutter/material.dart';

/// แถบเมนูล่างหลักของแอป
/// 0 = Home, 1 = Search, 2 = My Recipes, 3 = Profile
class CustomBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const CustomBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    /* ★ 1. ครอบ SafeArea ให้ตัวเอง (top:false, bottom:true) */
    return SafeArea(
      top: false,
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // แสดง label เสมอ
        currentIndex: selectedIndex,
        onTap: onItemSelected,

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'หน้าหลัก',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'ค้นหา',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'คลังของฉัน',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'โปรไฟล์',
          ),
        ],
      ),
    );
  }
}
