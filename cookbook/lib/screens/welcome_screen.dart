import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  // 1. เปลี่ยนไปใช้ Named Routes เพื่อความสอดคล้อง
  void _goToRegister(BuildContext context) {
    Navigator.of(context).pushNamed('/register');
  }

  void _goToLogin(BuildContext context) {
    Navigator.of(context).pushNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    // 2. ใช้ Theme จาก context แทนการ Hardcode ค่าสีและสไตล์
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      body: Stack(
        children: [
          // --- 1. ภาพพื้นหลัง ---
          Positioned.fill(
            child: Image.asset(
              'assets/images/chef_background.jpg',
              fit: BoxFit.cover,
              // เพิ่มสีเพื่อลดความสว่างของภาพพื้นหลังเล็กน้อย
              color: Colors.black.withOpacity(0.15),
              colorBlendMode: BlendMode.darken,
            ),
          ),
          // --- 2. Overlay สีเข้มโปร่งแสง ---
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.45),
            ),
          ),
          // --- 3. เนื้อหาหลัก ---
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 2),
                  // --- ข้อความหลัก ---
                  Text(
                    'ค้นหา,\nแบ่งปัน,\nสร้างสรรค์.',
                    style: textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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
                  const Spacer(flex: 3),
                  // --- 4. แผงควบคุมด้านล่าง ---
                  _buildBottomPanel(context, theme, textTheme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. แยก UI ส่วนล่างออกมาเป็น Widget Builder เพื่อความสะอาด
  Widget _buildBottomPanel(
      BuildContext context, ThemeData theme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface, // ใช้สีพื้นหลังจาก Theme
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ปุ่ม "เริ่มต้นใช้งาน"
          ElevatedButton(
            // ปุ่มจะดึงสไตล์มาจาก ElevatedButtonTheme ใน main.dart
            onPressed: () => _goToRegister(context),
            child: const Text('เริ่มต้นใช้งาน'),
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
          // ลิงก์ "เข้าสู่ระบบ"
          Center(
            child: RichText(
              text: TextSpan(
                style: textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                children: [
                  const TextSpan(text: 'มีบัญชีอยู่แล้ว? '),
                  TextSpan(
                    text: 'เข้าสู่ระบบ',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => _goToLogin(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
