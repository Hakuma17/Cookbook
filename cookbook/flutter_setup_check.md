# Flutter Cookbook Project Setup Guide

## สาเหตุที่โปรเจคไม่รันได้บนโน๊ตบุ๊คบางเครื่อง

### 1. Environment Requirements
- **Flutter SDK**: 3.6.0 หรือใหม่กว่า
- **Dart SDK**: 3.7.0 หรือใหม่กว่า
- **Android Studio**: ติดตั้งพร้อม Android SDK
- **Java**: JDK 11 หรือใหม่กว่า

### 2. ตรวจสอบการติดตั้ง
```powershell
# ตรวจสอบ Flutter
flutter doctor -v

# ตรวจสอบ devices ที่เชื่อมต่อ
flutter devices

# ตรวจสอบ connected devices
adb devices
```

### 3. การแก้ปัญหาทั่วไป

#### ปัญหา: Flutter command not found
```powershell
# เพิ่ม Flutter ใน PATH
# Windows: เพิ่ม C:\flutter\bin ใน System Environment Variables
```

#### ปัญหา: Android licenses not accepted
```powershell
flutter doctor --android-licenses
# กด 'y' เพื่อยอมรับ licenses ทั้งหมด
```

#### ปัญหา: Dependencies conflicts
```powershell
flutter clean
flutter pub cache repair
flutter pub get
```

### 4. ข้อกำหนดพิเศษสำหรับโปรเจคนี้

#### ML Dependencies (TensorFlow Lite)
- ต้องการ NDK version 27.0.12077973
- ต้องการ minSdkVersion อย่างน้อย 21

#### Google Services
- ต้องการไฟล์ google-services.json
- ต้องการ SHA-1 fingerprint สำหรับ Google Sign-In

#### Camera และ Permissions
- ต้องการ camera permissions
- ต้องการ storage permissions

### 5. คำสั่งรัน/ทดสอบ
```powershell
# รันบน debug mode
flutter run

# รันบน specific device
flutter run -d <device_id>

# สร้าง APK
flutter build apk --release

# ทดสอบบน emulator
flutter emulators --launch <emulator_name>
```

### 6. Troubleshooting Common Issues

#### Issue: Gradle build failed
```powershell
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

#### Issue: TensorFlow Lite model not loading
- ตรวจสอบไฟล์ model_unquant.tflite อยู่ใน assets/
- ตรวจสอบ labels.txt อยู่ใน assets/

#### Issue: Google Sign-In not working
- ตรวจสอบ google-services.json
- ตรวจสอบ SHA-1 fingerprint ใน Firebase Console
- ตรวจสอบ applicationId ตรงกัน

### 7. System Requirements สำหรับโน๊ตบุ๊ค
- **RAM**: อย่างน้อย 8GB (แนะนำ 16GB)
- **Storage**: อย่างน้อย 10GB ว่าง
- **OS**: Windows 10/11, macOS 10.14+, หรือ Linux
- **Network**: สำหรับดาวน์โหลด dependencies

### 8. การ Debug
```powershell
# เปิด verbose logging
flutter run --verbose

# ดู logs แบบ real-time
flutter logs

# Analyze โค้ด
flutter analyze
```