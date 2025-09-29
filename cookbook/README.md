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
- Dart SDK 3.7.0+
- Android Studio (พร้อม Android SDK)
- Java JDK 11+
- NDK version 27.0.12077973 (สำหรับ TensorFlow Lite)

### การติดตั้งและตั้งค่า

#### วิธีที่ 1: ใช้ Setup Script (แนะนำ)
**Windows:**
```cmd
setup.bat
```

**macOS/Linux:**
```bash
chmod +x setup.sh
./setup.sh
```

#### วิธีที่ 2: ติดตั้งแบบ Manual

1. **ตรวจสอบ Flutter Environment:**
```bash
flutter doctor -v
```

2. **ติดตั้ง Dependencies:**
```bash
flutter clean
flutter pub get
```

3. **ยอมรับ Android Licenses:**
```bash
flutter doctor --android-licenses
```

4. **รันโปรเจค:**
```bash
flutter run
```

### หากเกิดปัญหา

#### ❌ Flutter command not found
- ตรวจสอบการติดตั้ง Flutter และเพิ่มใน PATH
- Windows: เพิ่ม `C:\flutter\bin` ใน Environment Variables
- macOS/Linux: เพิ่ม export PATH="$PATH:[PATH_TO_FLUTTER_GIT_DIRECTORY]/bin" ใน `.bashrc` หรือ `.zshrc`

#### ❌ Gradle build failed
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

#### ❌ TensorFlow Lite issues
- ตรวจสอบไฟล์ `model_unquant.tflite` และ `labels.txt` ใน `assets/converted_tflite_quantized/`
- ตรวจสอบ NDK version 27.0.12077973 ติดตั้งแล้ว

#### ❌ Google Sign-In ไม่ทำงาน
- ตรวจสอบไฟล์ `google-services.json` ใน `android/app/`
- ตรวจสอบ SHA-1 fingerprint ใน Firebase Console

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
