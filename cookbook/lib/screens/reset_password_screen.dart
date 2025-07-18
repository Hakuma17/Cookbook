// lib/screens/reset_password_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'otp_verification_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _emailReg = RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-zA-Z]+$');

  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  /* ─────────────────────────  helpers  ───────────────────────── */

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();

    // 1) validate
    if (!_emailReg.hasMatch(email)) {
      if (mounted) setState(() => _errorMsg = 'กรุณากรอกอีเมลให้ถูกต้อง');
      return;
    }

    FocusScope.of(context).unfocus();
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMsg = null;
      });
    }

    try {
      final result =
          await ApiService.sendOtp(email).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      final ok = result['success'] == true;
      final msg = result['message'] ?? '';

      if (ok || msg.startsWith('กรุณารออีก')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ส่งรหัส OTP ไปยังอีเมลแล้ว')),
        );
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(email: email)),
        );
      } else {
        setState(() => _errorMsg = msg.isEmpty ? 'เกิดข้อผิดพลาด' : msg);
      }
    } on TimeoutException {
      if (mounted)
        setState(() => _errorMsg = 'เซิร์ฟเวอร์ตอบช้า ลองใหม่ภายหลัง');
    } on SocketException {
      if (mounted)
        setState(() => _errorMsg = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /* ─────────────────────────  UI  ───────────────────────── */

  @override
  Widget build(BuildContext context) {
    // คำนวณสัดส่วนจากหน้าจอจริง
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    // dynamic sizing
    final padH = w * 0.064; // ~24px
    final padV = h * 0.04; // ~32px
    final titleFont = w * 0.053; // ~20px
    final textFont = w * 0.037; // ~14px
    final labelFont = w * 0.042; // ~16px
    final errFont = w * 0.035; // ~13px
    final spacingL = h * 0.03; // ~24px
    final spacingS = h * 0.02; // ~16px
    final spacingXs = h * 0.01; // ~8px
    final fieldPadH = w * 0.043; // ~16px
    final fieldPadV = h * 0.02; // ~16px
    final btnHeight = h * 0.07; // ~56px
    final btnRadius = BorderRadius.circular(w * 0.075); // ~28px

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        foregroundColor: Colors.black87,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'รีเซ็ตรหัสผ่าน',
          style: TextStyle(
            fontSize: titleFont,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'กรอกอีเมลที่ใช้สมัครเพื่อรับรหัส OTP \nสำหรับรีเซ็ตรหัสผ่านของคุณ',
              style: TextStyle(
                fontSize: textFont,
                height: 1.6,
                color: Colors.black54,
              ),
            ),
            SizedBox(height: spacingL),
            if (_errorMsg != null) ...[
              Text(
                _errorMsg!,
                style: TextStyle(color: Colors.red, fontSize: errFont),
              ),
              SizedBox(height: spacingXs),
            ],
            Text(
              'อีเมลของคุณ',
              style: TextStyle(
                fontSize: labelFont,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: spacingXs),
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
                contentPadding: EdgeInsets.symmetric(
                  horizontal: fieldPadH,
                  vertical: fieldPadV,
                ),
              ),
              onSubmitted: (_) => _sendOtp(),
            ),
            SizedBox(height: spacingL),
            SizedBox(
              width: double.infinity,
              height: btnHeight,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8A65),
                  shape: RoundedRectangleBorder(borderRadius: btnRadius),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'ส่งรหัส OTP',
                        style: TextStyle(
                          fontSize: labelFont,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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
