# 🍳 Cookbook - คู่มือการทำอาหาร

แอปพลิเคชันคู่มือการทำอาหารที่ครอบคลุม พัฒนาด้วย Flutter

## ✨ คุณสมบัติ

- 🔍 **ค้นหาสูตรอาหาร** - ค้นหาด้วยชื่อ ส่วนผสม หรือหมวดหมู่
- 🥗 **กรองตามส่วนผสม** - เลือกส่วนผสมที่ต้องการหรือไม่ต้องการ
- ❤️ **รายการโปรด** - บันทึกสูตรอาหารที่ชื่นชอบ
- 🤖 **AI ส่วนผสม** - จำแนกส่วนผสมจากภาถ่าย
- 🔐 **ระบบสมาชิก** - เข้าสู่ระบบด้วยอีเมลหรือ Google
- 🎨 **ธีมสว่าง/มืด** - ปรับแต่งรูปแบบตามความชอบ
- 🔊 **อ่านเสียง** - ฟังขั้นตอนการทำอาหาร
- 📱 **รองรับหลายแพลตฟอร์ม** - Android, iOS, Web

## 🚀 เริ่มต้นใช้งาน

### ความต้องการ
- Flutter SDK 3.6.0+
- Dart SDK 3.0+

### การติดตั้ง

1. Clone หรือ download โปรเจกต์
2. เปิด terminal ในโฟลเดอร์โปรเจกต์
3. รันคำสั่ง:

```bash
flutter pub get
flutter run
```

### การสร้าง APK/IPA

```bash
# Android
flutter build apk --release

# iOS (macOS เท่านั้น)
flutter build ios --release
```

## 📱 การใช้งาน

### การเข้าสู่ระบบ
1. เปิดแอป
2. เลือก "เข้าสู่ระบบ" หรือ "สมัครสมาชิก"
3. กรอกข้อมูลหรือเข้าสู่ระบบด้วย Google

### การค้นหาสูตรอาหาร
1. ไปที่แท็บ "ค้นหา"
2. พิมพ์ชื่ออาหารหรือส่วนผสม
3. ใช้ตัวกรองเพื่อจำกัดผลลัพธ์

### การใช้ AI จำแนกส่วนผสม
1. แตะไิคอนกล้องในหน้าค้นหา
2. ถ่ายภาพส่วนผสม
3. รอให้ AI วิเคราะห์
4. เลือกส่วนผสมที่ต้องการ

## 🛠️ โครงสร้างโปรเจกต์

```
lib/
├── main.dart              # จุดเริ่มต้น
├── models/               # Data models
├── screens/              # หน้าจอต่างๆ
├── services/             # API services
├── stores/               # State management
├── theme/                # ธีมและสี
├── utils/                # Helper functions
└── widgets/              # Custom widgets
```

## 🔧 เทคโนโลยี

- **Frontend:** Flutter/Dart
- **State Management:** Provider
- **HTTP Client:** http package
- **Authentication:** Google Sign-In
- **AI/ML:** TensorFlow Lite
- **Local Storage:** Shared Preferences
- **Images:** Cached Network Image, Image Picker

## 📄 ใบอนุญาต

โปรเจกต์นี้เป็นแอปพลิเคชันส่วนตัว

## 🤝 ติดต่อ

หากพบปัญหาหรือมีข้อเสนอแนะ กรุณาแจ้งผ่าน GitHub Issues
