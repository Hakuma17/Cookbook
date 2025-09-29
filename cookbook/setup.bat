@echo off
echo ========================================
echo Flutter Cookbook Project Setup
echo ========================================

echo.
echo [1/6] Checking Flutter installation...
flutter --version
if %errorlevel% neq 0 (
    echo ERROR: Flutter is not installed or not in PATH
    echo Please install Flutter from https://flutter.dev/docs/get-started/install
    pause
    exit /b 1
)

echo.
echo [2/6] Running Flutter Doctor...
flutter doctor

echo.
echo [3/6] Cleaning project...
flutter clean

echo.
echo [4/6] Getting dependencies...
flutter pub get

echo.
echo [5/6] Checking Android licenses...
flutter doctor --android-licenses

echo.
echo [6/6] Checking available devices...
flutter devices

echo.
echo ========================================
echo Setup Complete!
echo ========================================
echo.
echo To run the app:
echo   flutter run
echo.
echo To run on specific device:
echo   flutter devices  (to see available devices)
echo   flutter run -d [device_id]
echo.
pause