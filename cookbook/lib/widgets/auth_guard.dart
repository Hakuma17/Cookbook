import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthGuard extends StatefulWidget {
  final Widget child;
  const AuthGuard({super.key, required this.child});

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  // ★ Added: สถานะตรวจสอบและผลลัพธ์การล็อกอิน
  bool _checked = false;
  bool _ok = false;
  bool _redirected = false;

  @override
  void initState() {
    super.initState();
    // ★ Changed: ย้ายลอจิกตรวจ auth มาอยู่ใน post-frame เพื่อกันการเด้งซ้อน/หน้าวาบ
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ok = await AuthService.isLoggedIn();
      if (!mounted) return;
      setState(() {
        _checked = true;
        _ok = ok;
      });

      if (!ok && !_redirected) {
        _redirected = true;
        // ใช้ addPostFrameCallback เพื่อให้แน่ใจว่า build เสร็จแล้วก่อน navigate
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ★ Changed: เลิกใช้ FutureBuilder ที่ทำให้เกิดการ build ซ้ำ/แฟลช UI
    // ระหว่างรอยืนยันผล -> แสดงเปล่า ๆ กันหน้าวาบ
    if (!_checked) {
      return const SizedBox.shrink();
    }

    // ล็อกอินแล้ว -> แสดงเนื้อหา
    if (_ok) {
      return widget.child;
    }

    // ยังไม่ล็อกอินและกำลัง redirect -> ไม่ต้องเรนเดอร์อะไร (กันวาบ)
    return const SizedBox.shrink();
  }
}
