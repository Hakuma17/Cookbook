import 'package:flutter/material.dart';

/// แถบเมนูล่างหลักของแอป
/// 0 = Home, 1 = Search, 2 = My Recipes, 3 = Profile/Settings
class CustomBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final bool isLoggedIn; // ★ 1. เพิ่ม parameter `isLoggedIn` เพื่อรับสถานะ

  const CustomBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.isLoggedIn, // ★ 2. เพิ่ม `isLoggedIn` ใน constructor
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: selectedIndex,
        onTap: onItemSelected,

        // ★ 3. ลบ const ออก เพราะ items ไม่ใช่ค่าคงที่แล้ว
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'หน้าหลัก',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'ค้นหา',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'คลังของฉัน',
          ),
          // ★ 4. ใช้ `isLoggedIn` เพื่อสลับไอคอนและข้อความของแท็บที่ 4
          BottomNavigationBarItem(
            icon: Icon(
                isLoggedIn ? Icons.person_outline : Icons.settings_outlined),
            activeIcon: Icon(isLoggedIn ? Icons.person : Icons.settings),
            label: isLoggedIn ? 'โปรไฟล์' : 'ตั้งค่า',
          ),
        ],
      ),
    );
  }
}
