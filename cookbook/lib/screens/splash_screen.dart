import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart'; // ← เพิ่ม
import 'welcome_screen.dart';
import 'home_screen.dart'; // ← เพิ่ม

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

    // สไตล์ status-bar
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    // สร้าง timer แต่เก็บไว้ยกเลิกได้
    _timer = Timer(_duration, _goNext);
  }

  // ยกเลิก timer ถ้า user ออกจากหน้าเร็ว
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /* ────────────────────────── NAV ────────────────────────── */
  Future<void> _goNext() async {
    // ป้องกัน setState / Navigator ตอน widget ถูก dispose ไปแล้ว
    if (!mounted) return;

    // ตัวอย่าง: ถ้า login แล้ว → ไป Home, ไม่งั้น Welcome
    final loggedIn = await AuthService.isLoggedIn();
    final dest = loggedIn ? const HomeScreen() : const WelcomeScreen();

    // ใช้ Fade transition
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => dest,
      transitionDuration: const Duration(milliseconds: 600),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ));
  }

  /* ────────────────────────── UI ────────────────────────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFC08D), // สีแบรนด์
      body: SafeArea(
        child: Center(
          child: Hero(
            tag: 'appLogo', // ใช้อนิเมชันข้ามหน้า
            child: Image.asset(
              'assets/images/logo.png',
              width: 160,
              height: 160,
            ),
          ),
        ),
      ),
    );
  }
}
