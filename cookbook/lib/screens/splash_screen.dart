// lib/screens/splash_screen.dart
//
// 2025-08-10 – cohesive splash
// - Uses AuthService.hasSeenOnboarding / isLoggedIn
// - PushNamedAndRemoveUntil: กันย้อนกลับมาที่ Splash
// - Mounted checks + fallback กรณี error → /welcome
// - Status bar readable on light bg
// - Hero(tag: 'appLogo') รองรับทรานสิชันไปหน้า auth

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _duration = Duration(seconds: 2); // เวลาแสดงขั้นต่ำ

  @override
  void initState() {
    super.initState();

    // ให้ไอคอนสถานะอ่านง่ายบนพื้นสว่าง
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    // คอยครบเวลาแล้วค่อยตัดสินใจนำทาง
    Future.delayed(_duration, _routeNext);
  }

  /* ───────────── NAV ───────────── */
  Future<void> _routeNext() async {
    String route = '/welcome'; // fallback ปลอดภัยที่สุด

    try {
      final hasSeenOnboarding = await AuthService.hasSeenOnboarding();
      if (!hasSeenOnboarding) {
        route = '/onboarding';
      } else {
        final isLoggedIn = await AuthService.isLoggedIn();
        if (isLoggedIn) {
          // ★ ตรวจสอบว่ามี pending email verification หรือไม่
          final pending = await AuthService.getPendingEmailVerify();
          if (pending != null && pending['email'] != null) {
            // มี email รอยืนยัน → ไปหน้ายืนยันอีเมลแทน
            route = '/verify_email';
          } else {
            // ไม่มี pending → ไปหน้า home ปกติ
            route = '/home';
          }
        } else {
          route = '/welcome';
        }
      }
    } catch (_) {
      // เงียบ ๆ แล้วใช้ค่า fallback ไป /welcome
    }

    if (!mounted) return;

    // ★ ถ้าเป็นหน้า verify_email ต้องส่ง arguments ด้วย
    if (route == '/verify_email') {
      try {
        final pending = await AuthService.getPendingEmailVerify();
        final email = pending?['email'] ?? '';
        final secondsLeft = pending?['secondsLeft'] ?? 0;

        Navigator.of(context).pushNamedAndRemoveUntil(
          route,
          (_) => false,
          arguments: {
            'email': email,
            'startCooldown': secondsLeft > 0,
          },
        );
        return;
      } catch (_) {
        // ถ้า error ให้กลับไปหน้า welcome
        route = '/welcome';
      }
    }

    // ล้างสแต็กกันกดย้อนกลับมาที่ Splash
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  }

  /* ───────────── UI ───────────── */
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    // ขนาดโลโก้ยืดหยุ่น แต่คุมเพดาน/พื้น
    final logoSize = (size.width * 0.4).clamp(120.0, 180.0);

    return Scaffold(
      backgroundColor: theme.colorScheme.primaryContainer,
      body: Center(
        child: Hero(
          tag: 'appLogo',
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
