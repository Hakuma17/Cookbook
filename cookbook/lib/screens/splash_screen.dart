import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ✅ 1. ลบ SharedPreferences ออก เพราะจะเรียกผ่าน AuthService
// import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
// ✅ 2. เปลี่ยนไปใช้ Named Routes เพื่อความสอดคล้อง
// import 'welcome_screen.dart';
// import 'home_screen.dart';
// import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _duration = Duration(seconds: 2); // เวลาแสดง
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // ปรับ status-bar ให้อ่านง่ายบนพื้นสีสว่าง
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    // ใช้ Future.delayed แทน Timer เพื่อให้โค้ดสั้นลง
    Future.delayed(_duration, _goNext);
  }

  @override
  void dispose() {
    _timer?.cancel(); // แม้จะไม่ได้ใช้ Timer แล้ว แต่เก็บไว้เผื่อกรณีฉุกเฉิน
    super.dispose();
  }

  /* ───────────────── NAV  ───────────────── */
  ///  3. ปรับปรุง Logic การนำทางให้เรียกใช้ AuthService และ Named Routes
  Future<void> _goNext() async {
    if (!mounted) return;

    // ตรวจสอบจาก Service ว่าเคยเห็น Onboarding แล้วหรือยัง
    final hasSeenOnboarding = await AuthService.hasSeenOnboarding();

    String destinationRoute;

    if (!hasSeenOnboarding) {
      // 1. ถ้ายังไม่เคยเห็น -> ไปหน้า Onboarding
      destinationRoute = '/onboarding';
    } else {
      // 2. ถ้าเคยเห็นแล้ว -> ตรวจสอบการล็อกอิน
      final isLoggedIn = await AuthService.isLoggedIn();
      destinationRoute = isLoggedIn ? '/home' : '/welcome';
    }

    // นำทางไปยังหน้าที่กำหนดโดยใช้ Named Route
    Navigator.of(context).pushReplacementNamed(destinationRoute);
  }

  /* ────────────────────────── UI ────────────────────────── */
  @override
  Widget build(BuildContext context) {
    //  4. ลบ Manual Responsive Calculation และใช้ Theme
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    // คำนวณขนาดโลโก้ให้ยืดหยุ่น แต่ไม่ใหญ่หรือเล็กเกินไป
    final logoSize = (size.width * 0.4).clamp(120.0, 180.0);

    return Scaffold(
      backgroundColor: theme.colorScheme.primaryContainer,
      body: Center(
        child: Hero(
          tag: 'appLogo', // Tag สำหรับ Hero animation ไปยังหน้า Login/Register
          child: Image.asset(
            'assets/images/logo.png',
            width: logoSize,
            height: logoSize,
          ),
        ),
      ),
    );
  }
}
