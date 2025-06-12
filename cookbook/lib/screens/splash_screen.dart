// lib/screens/splash_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'welcome_screen.dart';

/// หน้า SplashScreen: แสดงโลโก้ แล้วเปลี่ยนไปหน้า Welcome หลัง 2 วินาที
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // ระยะเวลาแสดง splash (วินาที)
  static const int _durationSeconds = 2;

  @override
  void initState() {
    super.initState();

    // 1) ตั้ง status bar ให้โปร่งใส + ไอคอนสีเข้ม
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    // 2) รอสักพัก แล้ว transition ไป WelcomeScreen
    Timer(const Duration(seconds: _durationSeconds), () {
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => const WelcomeScreen(),
        transitionDuration: const Duration(milliseconds: 800),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // พื้นหลังหลักสี brand
      backgroundColor: const Color(0xFFFFC08D),
      body: SafeArea(
        child: Center(
          // ใช้ Hero tag 'appLogo' เพื่อเชื่อมอนิเมชันข้ามหน้าได้
          child: Hero(
            tag: 'appLogo',
            child: Image.asset(
              'lib/assets/images/logo.png',
              width: 160,
              height: 160,
            ),
          ),
        ),
      ),
    );
  }
}
