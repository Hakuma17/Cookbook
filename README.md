# 🍳 Cookbook - แอปคู่มือการทำอาหาร

แอปพลิเคชันคู่มือการทำอาหารที่ครอบคลุม พัฒนาด้วย Flutter สำหรับผู้ที่รักการทำอาหารและต้องการค้นหาสูตรอาหารที่เหมาะสม

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-000000?style=for-the-badge&logo=ios&logoColor=white)

## 📋 คุณสมบัติหลัก

### 🔐 การจัดการผู้ใช้
- **ระบบสมัครสมาชิก/เข้าสู่ระบบ** - รองรับการเข้าสู่ระบบด้วย Google
- **ยืนยันอีเมล** - ระบบ OTP สำหรับความปลอดภัย
- **จัดการโปรไฟล์** - แก้ไขข้อมูลส่วนตัวและเปลี่ยนรหัสผ่าน
- **ตั้งค่าการแพ้อาหาร** - กรองสูตรอาหารตามอาการแพ้

### 🥘 การค้นหาและจัดการสูตรอาหาร
- **ค้นหาสูตรอาหาร** - ค้นหาด้วยชื่อ ส่วนผสม หรือหมวดหมู่
- **กรองตามส่วนผสม** - เลือกส่วนผสมที่ต้องการหรือไม่ต้องการ
- **รายการโปรด** - บันทึกสูตรอาหารที่ชื่นชอบ
- **รายละเอียดสูตรอาหาร** - ขั้นตอนการทำ ส่วนผสม และคำแนะนำ

### 🤖 AI และเทคโนโลยี
- **การรู้จำส่วนผสม** - ใช้ TensorFlow Lite สำหรับการจำแนกภาพส่วนผสม
- **ระบบแนะนำ** - แนะนำสูตรอาหารตามความชอบ

### 🎨 ประสบการณ์ผู้ใช้
- **โหมดธีม** - รองรับธีมสว่างและธีมมืด
- **อินเทอร์เฟซสวยงาม** - ออกแบบด้วย Material Design 3
- **รองรับภาษาไทย** - ฟอนต์และเนื้อหาเป็นภาษาไทย
- **การอ่านเสียง** - Text-to-Speech สำหรับขั้นตอนการทำอาหาร

## 🛠️ เทคโนโลยีที่ใช้

### Frontend
- **Flutter 3.6+** - เฟรมเวิร์กหลักสำหรับการพัฒนา
- **Dart** - ภาษาโปรแกรมมิ่ง
- **Material Design 3** - ระบบออกแบบ UI/UX

### Dependencies หลัก
```yaml
dependencies:
  flutter_svg: ^2.1.0           # การจัดการไฟล์ SVG
  http: ^1.4.0                  # HTTP requests
  google_sign_in: ^6.3.0        # เข้าสู่ระบบด้วย Google
  shared_preferences: ^2.5.3    # จัดเก็บข้อมูลภายใน
  flutter_tts: ^4.2.3           # Text-to-Speech
  image_picker: ^1.1.2          # เลือกรูปภาพ
  image_cropper: ^9.1.0         # ตัดแต่งรูปภาพ
  camera: ^0.11.1               # การใช้งานกล้อง
  tflite_flutter: ^0.11.0       # TensorFlow Lite
  provider: ^6.1.5              # State management
  google_fonts: ^6.2.1          # ฟอนต์ Google
  cached_network_image: ^3.4.1  # แคชรูปภาพ
```

### AI/ML
- **TensorFlow Lite** - สำหรับการจำแนกภาพส่วนผสม
- **Image Processing** - การประมวลผลรูปภาพ

## 📱 การติดตั้งและใช้งาน

### ความต้องการของระบบ
- Flutter SDK 3.6.0 หรือใหม่กว่า
- Dart SDK 3.0+
- Android Studio / VS Code
- Android SDK (สำหรับ Android)
- Xcode (สำหรับ iOS - เฉพาะ macOS)

### การติดตั้ง

1. **Clone repository**
   ```bash
   git clone https://github.com/Hakuma17/Cookbook.git
   cd Cookbook/cookbook
   ```

2. **ติดตั้ง dependencies**
   ```bash
   flutter pub get
   ```

3. **สร้าง launcher icons**
   ```bash
   flutter pub run flutter_launcher_icons:main
   ```

4. **รันแอปพลิเคชัน**
   ```bash
   # สำหรับ debug mode
   flutter run
   
   # สำหรับ release mode
   flutter run --release
   ```

### การสร้าง Build

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS (เฉพาะ macOS)
flutter build ios --release
```

## 📁 โครงสร้างโปรเจกต์

```
cookbook/
├── lib/
│   ├── main.dart                 # จุดเริ่มต้นของแอป
│   ├── models/                   # Data models
│   ├── screens/                  # หน้าจอต่างๆ (25+ screens)
│   ├── services/                 # API และ Authentication services
│   ├── stores/                   # State management (Provider)
│   ├── theme/                    # การตั้งค่าธีม
│   ├── utils/                    # Utility functions
│   └── widgets/                  # Custom widgets
├── assets/
│   ├── fonts/                    # ฟอนต์ Montserrat
│   ├── icons/                    # ไอคอนต่างๆ
│   ├── images/                   # รูปภาพ
│   ├── converted_tflite_quantized/ # โมเดล AI
│   └── onboarding/               # รูปภาพ onboarding
├── android/                      # Android-specific files
├── ios/                          # iOS-specific files
├── web/                          # Web-specific files
├── windows/                      # Windows-specific files
├── linux/                        # Linux-specific files
├── macos/                        # macOS-specific files
└── test/                         # Unit tests
```

## 🎯 หน้าจอหลัก

### หน้าจอการเข้าสู่ระบบ
- เข้าสู่ระบบด้วยอีเมลหรือ Google
- สมัครสมาชิกใหม่
- ลืมรหัสผ่าน

### หน้าแรก (Home)
- แสดงสูตรอาหารแนะนำ
- หมวดหมู่อาหาร
- ค้นหาด่วน

### หน้าค้นหา (Search)
- ค้นหาสูตรอาหาร
- กรองตามส่วนผสม
- เรียงลำดับผลลัพธ์

### หน้ารายละเอียดสูตรอาหาร
- ส่วนผสมและปริมาณ
- ขั้นตอนการทำ
- เวลาและความยาก
- การอ่านเสียงขั้นตอน

### หน้าโปรไฟล์
- ข้อมูลส่วนตัว
- สูตรอาหารโปรด
- การตั้งค่า

## 🔧 การพัฒนา

### การเพิ่มฟีเจอร์ใหม่
1. สร้าง branch ใหม่จาก main
2. พัฒนาฟีเจอร์
3. เขียน unit tests
4. สร้าง pull request

### การทดสอบ
```bash
# รัน unit tests
flutter test

# รัน integration tests
flutter drive --target=test_driver/app.dart
```

### Code Style
- ใช้ `flutter_lints` สำหรับ linting
- ตั้งชื่อไฟล์และตัวแปรเป็นภาษาอังกฤษ
- เขียน comment สำคัญเป็นภาษาไทย

## 🤝 การมีส่วนร่วม

เรายินดีรับการมีส่วนร่วมจากทุกคน! กรุณา:

1. Fork repository นี้
2. สร้าง feature branch
3. Commit การเปลี่ยนแปลง
4. Push ไปยัง branch
5. สร้าง Pull Request

### แนวทางการ Contribute
- รายงานข้อผิดพลาดผ่าน Issues
- เสนอฟีเจอร์ใหม่
- ปรับปรุงเอกสาร
- แปลเนื้อหา

## 📄 ใบอนุญาต

โปรเจกต์นี้เป็นส่วนตัวและไม่ได้เผยแพร่บน pub.dev

## 👥 ทีมพัฒนา

- **Hakuma17** - นักพัฒนาหลัก

## 📞 ติดต่อ

หากมีคำถามหรือข้อเสนอแนะ กรุณาติดต่อผ่าน GitHub Issues

---

📝 **หมายเหตุ:** แอปนี้อยู่ในขั้นตอนการพัฒนา บางฟีเจอร์อาจยังไม่สมบูรณ์

⭐ **ถ้าโปรเจกต์นี้มีประโยชน์ กรุณา Star ให้กำลังใจด้วยนะครับ!**