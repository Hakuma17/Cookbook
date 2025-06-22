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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        foregroundColor: Colors.black87,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'รีเซ็ตรหัสผ่าน',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'กรอกอีเมลที่ใช้สมัครเพื่อรับรหัส OTP สำหรับรีเซ็ตรหัสผ่าน',
              style:
                  TextStyle(fontSize: 14, height: 1.6, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            if (_errorMsg != null) ...[
              Text(_errorMsg!,
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
              const SizedBox(height: 12),
            ],
            const Text('อีเมลของคุณ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
              onSubmitted: (_) => _sendOtp(),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8A65),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'ส่งรหัส OTP',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
