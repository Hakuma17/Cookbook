# Common Issues and Solutions

## Issue 1: "flutter: command not found"
**Solution:**
1. Install Flutter SDK from https://flutter.dev/docs/get-started/install
2. Add Flutter to PATH:
   - Windows: Add `C:\flutter\bin` to System Environment Variables
   - macOS/Linux: Add `export PATH="$PATH:[PATH_TO_FLUTTER]/bin"` to `.bashrc`/`.zshrc`

## Issue 2: "Android licenses not accepted"
**Solution:**
```bash
flutter doctor --android-licenses
# Accept all licenses by typing 'y'
```

## Issue 3: "Gradle build failed"
**Solution:**
```bash
flutter clean
flutter pub get
cd android
./gradlew clean
cd ..
flutter run
```

## Issue 4: "TensorFlow Lite model not found"
**Solution:**
- Ensure `model_unquant.tflite` exists in `assets/converted_tflite_quantized/`
- Ensure `labels.txt` exists in `assets/converted_tflite_quantized/`
- Check NDK version 27.0.12077973 is installed

## Issue 5: "Google Sign-In not working"
**Solution:**
- Ensure `google-services.json` is in `android/app/`
- Check SHA-1 fingerprint in Firebase Console
- Verify applicationId matches in all config files

## Issue 6: "Camera permissions denied"
**Solution:**
- Add camera permissions to `android/app/src/main/AndroidManifest.xml`
- Request permissions at runtime using permission_handler package

## Issue 7: "Build tools version not supported"
**Solution:**
- Update Android SDK Build Tools to latest version
- Update compileSdkVersion in `android/app/build.gradle.kts`

## Issue 8: "Insufficient storage space"
**Solution:**
- Ensure at least 10GB free space
- Clear Flutter cache: `flutter clean`
- Clear pub cache: `flutter pub cache repair`

## System Requirements
- **Minimum RAM:** 8GB (Recommended: 16GB)
- **Free Storage:** 10GB minimum
- **Operating System:** 
  - Windows 10/11
  - macOS 10.14 or later
  - Linux (64-bit)
- **Network:** Required for downloading dependencies