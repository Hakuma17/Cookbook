// lib/screens/welcome_screen.dart (New Design)

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cookbook/screens/login_screen.dart';
import 'package:cookbook/screens/register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  // ฟังก์ชันสำหรับนำทางไปยังหน้าลงทะเบียน
  void _goToRegister(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  // ฟังก์ชันสำหรับนำทางไปยังหน้าล็อกอิน
  void _goToLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final textTheme = Theme.of(context).textTheme;
    const primaryColor = Color(0xFFFF9B05); // สีส้มหลักของแอป

    return Scaffold(
      body: Stack(
        children: [
          // 1. ภาพพื้นหลัง
          Positioned.fill(
            child: Image.asset(
              'assets/images/chef_background.jpg',
              fit: BoxFit.cover,
              // เพิ่มสีเพื่อลดความสว่างของภาพพื้นหลังเล็กน้อย
              color: Colors.black.withOpacity(0.1),
              colorBlendMode: BlendMode.darken,
            ),
          ),
          // 2. Overlay สีเข้มโปร่งแสง
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.45),
            ),
          ),
          // 3. เนื้อหาหลัก
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ส่วนบน (เว้นว่าง)
                const Spacer(flex: 2),

                // ข้อความหลัก
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    'ค้นหา,\nแบ่งปัน,\nสร้างสรรค์.',
                    style: textTheme.displayMedium?.copyWith(
                      fontFamily:
                          'Mitr', // แนะนำให้ใช้ฟอนต์ที่รองรับภาษาไทยสวยๆ
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      shadows: [
                        const Shadow(
                          blurRadius: 10.0,
                          color: Colors.black54,
                          offset: Offset(2.0, 2.0),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 3),

                // 4. แผงควบคุมด้านล่างสีขาว
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ปุ่ม "เริ่มต้นใช้งาน"
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          // เมื่อกดปุ่มนี้ จะไปหน้าลงทะเบียน
                          onPressed: () => _goToRegister(context),
                          child: const Text(
                            'เริ่มต้นใช้งาน',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text('Or',
                                style: TextStyle(color: Colors.grey)),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ลิงก์ "เข้าสู่ระบบ"
                      RichText(
                        text: TextSpan(
                          style: textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[700]),
                          children: [
                            const TextSpan(text: 'มีบัญชีอยู่แล้ว? '),
                            TextSpan(
                              text: 'เข้าสู่ระบบ',
                              style: const TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                              // เมื่อกด จะไปหน้าล็อกอิน
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => _goToLogin(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
