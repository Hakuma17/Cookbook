# 🛠️ การตั้งค่าสำหรับนักพัฒนา

## เตรียมสภาพแวดล้อมการพัฒนา

### 1. ติดตั้ง Flutter

#### Windows
```bash
# ดาวน์โหลด Flutter SDK จาก https://docs.flutter.dev/get-started/install/windows
# แตกไฟล์และเพิ่ม flutter/bin ใน PATH
```

#### macOS
```bash
# ใช้ Homebrew
brew install flutter

# หรือดาวน์โหลดจาก https://docs.flutter.dev/get-started/install/macos
```

#### Linux
```bash
# ดาวน์โหลดและติดตั้งจาก https://docs.flutter.dev/get-started/install/linux
```

### 2. ตรวจสอบการติดตั้ง
```bash
flutter doctor
```

### 3. เตรียม IDE
- **Android Studio** (แนะนำ)
- **VS Code** พร้อม Flutter extension
- **IntelliJ IDEA**

### 4. ตั้งค่าโปรเจกต์

#### Clone และติดตั้ง dependencies
```bash
git clone https://github.com/Hakuma17/Cookbook.git
cd Cookbook/cookbook
flutter pub get
```

#### สร้าง launcher icons
```bash
flutter pub run flutter_launcher_icons:main
```

### 5. การตั้งค่า Firebase/Google Services

แอปนี้ใช้ Google Sign-In ดังนั้นจึงต้องมีการตั้งค่า:

1. ไปที่ [Firebase Console](https://console.firebase.google.com/)
2. เปิดโปรเจกต์ `cookbooklogin`
3. ดาวน์โหลด `google-services.json` ใหม่หากจำเป็น
4. วางไฟล์ใน `android/app/`

#### ตั้งค่า Android
- SHA1 fingerprint ของ debug key
- Package name: ตรวจสอบใน `android/app/build.gradle`

#### ตั้งค่า iOS (macOS เท่านั้น)
- ดาวน์โหลด `GoogleService-Info.plist`
- เพิ่มในโปรเจกต์ iOS

### 6. การรัน

#### Development
```bash
# Debug mode
flutter run

# Hot reload เปิดอยู่แล้วโดยอัตโนมัติ
# กด 'r' เพื่อ hot reload
# กด 'R' เพื่อ hot restart
```

#### Production Build
```bash
# Android APK
flutter build apk --release

# Android App Bundle (สำหรับ Play Store)
flutter build appbundle --release

# iOS (macOS เท่านั้น)
flutter build ios --release
```

### 7. การทดสอบ

```bash
# Unit tests
flutter test

# Widget tests
flutter test test/widget_test.dart
```

### 8. เครื่องมือช่วยในการพัฒนา

#### Linting
```bash
flutter analyze
```

#### Format Code
```bash
dart format .
```

#### Clean Build
```bash
flutter clean
flutter pub get
```

## 🔧 Tips สำหรับการพัฒนา

### Hot Reload
- ใช้ `r` สำหรับ hot reload
- ใช้ `R` สำหรับ hot restart (เมื่อเปลี่ยน main() หรือเพิ่ม dependencies)

### Debugging
- ใช้ `print()` หรือ `debugPrint()` 
- ใช้ Flutter Inspector ใน IDE
- ใช้ `flutter logs` เพื่อดู console output

### State Management
โปรเจกต์นี้ใช้ Provider pattern:
```dart
// ตัวอย่างการใช้ Provider
Consumer<FavoriteStore>(
  builder: (context, favoriteStore, child) {
    return Text('Favorites: ${favoriteStore.favoriteIds.length}');
  },
)
```

### Assets
เมื่อเพิ่มไฟล์ใน `assets/` อย่าลืมอัปเดต `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/images/new_image.png
```

## 🚨 ปัญหาที่พบบ่อย

### Gradle Build ล้มเหลว
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

### iOS Build ล้มเหลว
```bash
cd ios
rm -rf Pods
pod install
cd ..
flutter clean
flutter build ios
```

### Hot Reload ไม่ทำงาน
- Restart IDE
- `flutter hot restart`
- ตรวจสอบว่าไม่มี syntax error

### Dependencies ขัดแย้ง
```bash
flutter pub deps
flutter pub outdated
```

## 📚 เอกสารเพิ่มเติม

- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Provider Documentation](https://pub.dev/packages/provider)
- [Firebase Flutter Setup](https://firebase.google.com/docs/flutter/setup)