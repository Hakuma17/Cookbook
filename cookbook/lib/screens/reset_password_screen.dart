// lib/screens/reset_password_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'otp_verification_screen.dart';

/// หน้ารีเซ็ตรหัสผ่าน: กรอกอีเมลเพื่อรับ OTP
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({Key? key}) : super(key: key);
  @override
  _ResetPasswordScreenState createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();

    // 1) Validate email
    final emailReg = RegExp(r"^[\w\.\-]+@[\w\-]+\.[a-zA-Z]+$");
    if (!emailReg.hasMatch(email)) {
      setState(() => _errorMsg = 'กรุณากรอกอีเมลให้ถูกต้อง');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final result = await ApiService.sendOtp(email);

      if (result['success'] == true) {
        // กรณีส่งสำเร็จตามปกติ
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ส่งรหัส OTP ไปยังอีเมลแล้ว')));
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(email: email)),
        );
      } else {
        final msg = result['message'] ?? '';
        // ถ้าเจอข้อความ "กรุณารออีก" แปลว่ามี OTP เดิมยังไม่หมดอายุ
        if (msg.startsWith('กรุณารออีก')) {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => OtpVerificationScreen(email: email)),
          );
        } else {
          setState(() => _errorMsg = msg);
        }
      }
    } on SocketException {
      setState(() => _errorMsg = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    } catch (e) {
      setState(() => _errorMsg = 'เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black87),
        title: const Text(
          'รีเซ็ตรหัสผ่าน',
          style: TextStyle(
              color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'กรุณากรอกอีเมลที่คุณใช้สมัคร เพื่อรับรหัส OTP สำหรับรีเซ็ตรหัสผ่าน',
              style:
                  TextStyle(color: Colors.black54, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 24),
            if (_errorMsg != null) ...[
              Text(_errorMsg!,
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
              const SizedBox(height: 12),
            ],
            const Text(
              'อีเมลของคุณ',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'อีเมล@example.com',
                filled: true,
                fillColor: const Color(0xFFF5F3F3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8A65),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'ส่งรหัส OTP',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
