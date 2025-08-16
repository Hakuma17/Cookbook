// lib/screens/welcome_screen.dart
//
// 2025-08-10 – polish & consistency
// - Theme-first, Named Routes เหมือนจออื่น ๆ
// - AnnotatedRegion เพื่อปรับสถานะ status bar (ไอคอนสีอ่อน)
// - รองรับจอใหญ่ด้วย ConstrainedBox + Center
// - ปรับพื้นหลัง/overlay และ errorBuilder ให้ไม่ crash ถ้ารูปไม่มี
// - ปุ่มหลักสูง 56, spacing เนี้ยบให้เท่ากับแนวทางทั้งแอป

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _goToRegister(BuildContext context) {
    Navigator.of(context).pushNamed('/register');
  }

  void _goToLogin(BuildContext context) {
    Navigator.of(context).pushNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        // พื้นหลังส่วนบนค่อนข้างมืด → ใช้ไอคอนสถานะสีอ่อน
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // --- 1) พื้นหลัง ---
            // ใช้ errorBuilder กันภาพหาย + ใส่ overlay ลดความสว่าง
            Positioned.fill(
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(.35),
                  BlendMode.darken,
                ),
                child: Image.asset(
                  'assets/images/chef_background.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: theme.colorScheme.surfaceVariant,
                  ),
                ),
              ),
            ),

            // --- 2) เนื้อหา ---
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Spacer(flex: 2),

                        // Headline
                        Text(
                          'ค้นหา,\nแบ่งปัน,\nสร้างสรรค์.',
                          style: textTheme.displayMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                            shadows: const [
                              Shadow(
                                blurRadius: 10,
                                color: Colors.black54,
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(flex: 3),

                        // --- 3) แผงควบคุมด้านล่าง ---
                        _BottomPanel(
                          onGetStarted: () => _goToRegister(context),
                          onLogin: () => _goToLogin(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/*──────────────────────── Bottom Panel ───────────────────────*/

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.onGetStarted,
    required this.onLogin,
  });

  final VoidCallback onGetStarted;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // จำกัดความกว้างให้ดูดีบนแท็บเล็ต/เดสก์ทอป
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(40),
              topRight: Radius.circular(40),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.12),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ปุ่มหลัก
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: onGetStarted,
                  child: const Text('เริ่มต้นใช้งาน'),
                ),
              ),
              const SizedBox(height: 20),

              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('หรือ'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),

              // ลิงก์เข้าสู่ระบบ
              Center(
                child: RichText(
                  text: TextSpan(
                    style: textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    children: [
                      const TextSpan(text: 'มีบัญชีอยู่แล้ว? '),
                      TextSpan(
                        text: 'เข้าสู่ระบบ',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()..onTap = onLogin,
                      ),
                    ],
                  ),
                ),
              ),

              // เผื่อขอบล่างและ gesture bar
              Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewPadding.bottom,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
