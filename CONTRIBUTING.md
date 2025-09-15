# 🤝 การมีส่วนร่วมในการพัฒนา

ขอบคุณที่สนใจมีส่วนร่วมในการพัฒนาแอป Cookbook! 

## 🚀 เริ่มต้น

1. **Fork** repository นี้
2. **Clone** fork ของคุณ
3. อ่าน [SETUP.md](SETUP.md) เพื่อตั้งค่าสภาพแวดล้อมการพัฒนา
4. สร้าง **branch ใหม่** สำหรับฟีเจอร์ของคุณ

```bash
git checkout -b feature/ชื่อฟีเจอร์ของคุณ
```

## 📝 แนวทางการเขียนโค้ด

### ตั้งชื่อไฟล์และตัวแปร
- **ไฟล์**: ใช้ snake_case (เช่น `recipe_detail_screen.dart`)
- **Class**: ใช้ PascalCase (เช่น `RecipeDetailScreen`)
- **ตัวแปร**: ใช้ camelCase (เช่น `recipeId`)
- **ค่าคงที่**: ใช้ SCREAMING_SNAKE_CASE (เช่น `MAX_RECIPE_COUNT`)

### โครงสร้างไฟล์
```dart
// ลำดับการ import
import 'dart:...';           // Dart libraries
import 'package:flutter/...'; // Flutter libraries
import 'package:other/...';   // Third-party packages
import '../...';             // Relative imports

// ลำดับใน class
class MyWidget extends StatelessWidget {
  // 1. Static constants
  static const String routeName = '/my-widget';
  
  // 2. Instance variables
  final String title;
  
  // 3. Constructor
  const MyWidget({super.key, required this.title});
  
  // 4. Override methods
  @override
  Widget build(BuildContext context) {
    // ...
  }
  
  // 5. Private methods
  void _privateMethod() {
    // ...
  }
}
```

### Comments
- เขียน comment สำคัญเป็น**ภาษาไทย**
- ใช้ `///` สำหรับ documentation comments
- ใช้ `//` สำหรับ inline comments

```dart
/// สร้างการ์ดแสดงสูตรอาหาร
Widget buildRecipeCard(Recipe recipe) {
  // ตรวจสอบว่ามีรูปภาพหรือไม่
  if (recipe.imageUrl.isEmpty) {
    return _buildPlaceholderCard();
  }
  
  return Card(
    // การตั้งค่าการ์ด...
  );
}
```

## 🐛 การรายงานข้อผิดพลาด

เมื่อพบข้อผิดพลาด กรุณาสร้าง Issue ใหม่และระบุ:

- **อุปกรณ์**: Android/iOS/Web, เวอร์ชัน OS
- **ขั้นตอนที่ทำให้เกิดปัญหา**: อธิบายละเอียด
- **ผลลัพธ์ที่คาดหวัง**: สิ่งที่ควรจะเกิดขึ้น
- **ผลลัพธ์จริง**: สิ่งที่เกิดขึ้นจริง
- **Screenshots**: หากเป็นปัญหา UI
- **Error logs**: หากมี

## ✨ การเสนอฟีเจอร์ใหม่

1. สร้าง Issue อธิบายฟีเจอร์ที่ต้องการ
2. รอการอนุมัติก่อนเริ่มพัฒนา
3. ทำงานใน branch แยก
4. เขียน tests (หากเป็นไปได้)
5. สร้าง Pull Request

## 🧪 การทดสอบ

### ก่อน Submit PR
```bash
# รัน tests
flutter test

# ตรวจสอบ code style
flutter analyze

# จัดรูปแบบ code
dart format .

# ทดสอบบน device จริง
flutter run --release
```

### การเขียน Tests
```dart
// ตัวอย่าง widget test
testWidgets('Recipe card should display title', (WidgetTester tester) async {
  const recipe = Recipe(id: 1, title: 'ข้าวผัดกุ้ง');
  
  await tester.pumpWidget(
    MaterialApp(home: RecipeCard(recipe: recipe)),
  );
  
  expect(find.text('ข้าวผัดกุ้ง'), findsOneWidget);
});
```

## 📋 Checklist สำหรับ Pull Request

- [ ] เขียน commit message ที่อธิบายการเปลี่ยนแปลงชัดเจน
- [ ] ไม่มี merge conflicts
- [ ] รัน `flutter analyze` และแก้ไข warnings
- [ ] รัน `flutter test` และ tests ผ่านทั้งหมด
- [ ] ทดสอบบน device จริง (Android และ iOS หากเป็นไปได้)
- [ ] เขียน tests สำหรับฟีเจอร์ใหม่
- [ ] อัปเดตเอกสารหากจำเป็น

## 🎯 ประเภทการมีส่วนร่วม

### 🐛 Bug Fixes
- แก้ไขข้อผิดพลาดในโค้ด
- ปรับปรุงประสิทธิภาพ
- แก้ไข UI/UX issues

### ✨ Features
- เพิ่มฟีเจอร์ใหม่
- ปรับปรุงฟีเจอร์เดิม
- เพิ่ม API endpoints

### 📚 Documentation
- ปรับปรุงเอกสาร
- เพิ่ม code comments
- เขียน tutorials

### 🧪 Testing
- เพิ่ม unit tests
- เพิ่ม widget tests
- เพิ่ม integration tests

## 📞 ติดต่อ

หากมีคำถามเกี่ยวกับการพัฒนา:
- สร้าง Issue สำหรับคำถามทั่วไป
- ส่ง email สำหรับเรื่องเร่งด่วน

## 📄 Code of Conduct

- เคารพซึ่งกันและกัน
- ให้ feedback ที่สร้างสรรค์
- ช่วยเหลือสมาชิกใหม่
- ใช้ภาษาที่เหมาะสม

---

**ขอบคุณสำหรับการมีส่วนร่วม! 🙏**