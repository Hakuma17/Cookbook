// lib/screens/splash_screen.dart (Final Version for Onboarding)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ★★★ เพิ่ม import

import '../services/auth_service.dart';
import 'welcome_screen.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart'; // ★★★ เพิ่ม import

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

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

    _timer = Timer(_duration, _goNext);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /* ───────────────── NAV (เวอร์ชันปรับปรุง) ───────────────── */
  // ★★★ แก้ไขฟังก์ชันนี้ทั้งหมด ★★★
  Future<void> _goNext() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    // ตรวจสอบว่าเคยเห็นหน้า Onboarding แล้วหรือยัง (ค่าเริ่มต้นคือ false)
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    Widget destination;

    if (!hasSeenOnboarding) {
      // 1. ถ้ายังไม่เคยเห็น -> ไปหน้า Onboarding
      destination = const OnboardingScreen();
    } else {
      // 2. ถ้าเคยเห็นแล้ว -> ใช้ logic เดิม คือตรวจสอบการล็อกอิน
      final loggedIn = await AuthService.isLoggedIn();
      destination = loggedIn ? const HomeScreen() : const WelcomeScreen();
    }

    // นำทางไปยังหน้าที่กำหนด
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => destination,
      transitionDuration: const Duration(milliseconds: 600),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ));
  }
  // ★★★ จบส่วนแก้ไข ★★★

  /* ────────────────────────── UI ────────────────────────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFC08D), // สีแบรนด์
      body: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth;
        // โลโก้ = 40 % ความกว้างหน้าจอ แต่ไม่เกิน 160 และไม่น้อยกว่า 100
        double logo = w * 0.4;
        logo = logo.clamp(100, 160);

        return SafeArea(
          child: Center(
            child: Hero(
              tag: 'appLogo',
              child: Image.asset(
                'assets/images/logo.png',
                width: logo,
                height: logo,
              ),
            ),
          ),
        );
      }),
    );
  }
}
