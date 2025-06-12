// lib/screens/new_password_screen.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart'; // นำเข้า LoginScreen เพื่อไปหน้าล็อกอิน

/// หน้าตั้งรหัสผ่านใหม่: รับ email + otp จากหน้าก่อนหน้า
class NewPasswordScreen extends StatefulWidget {
  final String email;
  final String otp;
  const NewPasswordScreen({
    Key? key,
    required this.email,
    required this.otp,
  }) : super(key: key);

  @override
  _NewPasswordScreenState createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  // Controllers สำหรับกรอกรหัสผ่านใหม่และยืนยันรหัสผ่าน
  final _pass1Ctrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  bool _obscure1 = true; // สลับการมองเห็นรหัสผ่านช่องแรก
  bool _obscure2 = true; // สลับการมองเห็นรหัสผ่านช่องสอง
  bool _isLoading = false; // แสดงสถานะกำลังส่งข้อมูล
  String? _errorMsg; // ข้อความแสดงข้อผิดพลาด

  /// ส่งคำขออัปเดตรหัสผ่านใหม่ไปยังเซิร์ฟเวอร์
  Future<void> _submitNewPassword() async {
    setState(() {
      _errorMsg = null;
      _isLoading = true;
    });

    // ตรวจสอบว่ารหัสผ่านใหม่และยืนยันรหัสผ่านตรงกัน
    if (_pass1Ctrl.text != _pass2Ctrl.text) {
      setState(() {
        _isLoading = false;
        _errorMsg = 'รหัสผ่านไม่ตรงกัน';
      });
      return;
    }
    // เรียก API ด้วย 3 ตัวเท่านั้น (email, otp, newPassword)

    final res = await ApiService.resetPassword(
      widget.email,
      widget.otp,
      _pass1Ctrl.text,
    );

    setState(() {
      _isLoading = false;
    });

    if (res['success'] == true) {
      await _showSuccessDialog();
    } else {
      setState(() {
        _errorMsg = res['message'];
      });
    }
  }

  /// แสดง dialog แจ้ง “สำเร็จ” และกดดำเนินการต่อไปหน้า Login
  Future<void> _showSuccessDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ไอคอนติ๊กถูกในวงกลม
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                  color: Color(0xFF34C759), shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            // หัวข้อ “สำเร็จ”
            const Text(
              'สำเร็จ',
              style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                  fontSize: 20),
            ),
            const SizedBox(height: 8),
            // คำอธิบาย
            const Text(
              'รหัสผ่านของคุณได้ถูกเปลี่ยนเรียบร้อยแล้ว\nคลิกดำเนินการต่อเพื่อเข้าสู่ระบบ',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                  height: 1.4,
                  color: Color(0xFF666666)),
            ),
            const SizedBox(height: 24),
            // ปุ่ม “ดำเนินการต่อ”
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // ไปหน้า LoginScreen แทนการ popUntil
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC79C),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text(
                  'ดำเนินการต่อ',
                  style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      color: Colors.black),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // AppBar แบบกำหนดเอง
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: SafeArea(
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0A2533)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const Text(
              'ตั้งรหัสผ่านใหม่',
              style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w500,
                  fontSize: 24,
                  color: Colors.black),
            ),
          ]),
        ),
      ),
      // เนื้อหา: คำอธิบาย + ฟิลด์รหัสผ่าน + ปุ่มอัปเดต
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            const Text(
              'สร้างรหัสผ่านใหม่และตรวจสอบให้แน่ใจว่า\nรหัสผ่านใหม่นี้แตกต่างจากรหัสผ่านเดิมเพื่อความปลอดภัย',
              style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                  height: 1.5,
                  color: Color(0xFF666666)),
            ),
            const SizedBox(height: 24),
            // แสดง error ถ้ามี
            if (_errorMsg != null) ...[
              Text(_errorMsg!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],
            // ช่องรหัสผ่านใหม่
            const Text(
              'รหัสผ่าน',
              style: TextStyle(
                  fontFamily: 'Open Sans',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  height: 1.19,
                  letterSpacing: -0.48,
                  color: Color(0xFF2A2A2A)),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 50,
              child: TextField(
                controller: _pass1Ctrl,
                obscureText: _obscure1,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.black, width: 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure1 ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // ช่องยืนยันรหัสผ่าน
            const Text(
              'ยืนยันรหัสผ่าน',
              style: TextStyle(
                  fontFamily: 'Open Sans',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  height: 1.19,
                  letterSpacing: -0.48,
                  color: Color(0xFF2A2A2A)),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 50,
              child: TextField(
                controller: _pass2Ctrl,
                obscureText: _obscure2,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.black, width: 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure2 ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 36),
            // ปุ่ม “อัปเดตรหัสผ่าน”
            Center(
              child: SizedBox(
                width: 340,
                height: 49,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitNewPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC79C),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'อัปเดตรหัสผ่าน',
                          style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w500,
                              fontSize: 20,
                              color: Colors.black),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
      // bottom navigation bar (ตามดีไซน์หลัก)
      bottomNavigationBar: BottomAppBar(
        elevation: 1,
        color: Colors.white,
        child: Container(
          height: 74,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFD2D2D2))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavIcon(Icons.home_outlined, false, onTap: () {}),
              _NavIcon(Icons.explore_outlined, false, onTap: () {}),
              _NavIcon(Icons.list_alt_outlined, false, onTap: () {}),
              _NavIcon(Icons.person, true, onTap: () {}),
            ],
          ),
        ),
      ),
    );
  }

  /// วาดไอคอนใน bottom navigation bar
  Widget _NavIcon(IconData icon, bool selected,
          {required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Icon(
          icon,
          size: 24,
          color: selected ? const Color(0xFFFF9B05) : const Color(0xFFC1C1C1),
        ),
      );
}
