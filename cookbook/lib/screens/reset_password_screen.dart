import 'dart:async';
// import 'dart:io'; // 🗑️ ลบออก ไม่ได้ใช้แล้ว

import 'package:flutter/material.dart';
import '../services/api_service.dart';
// import 'otp_verification_screen.dart'; // 🗑️ ลบออก เพราะจะใช้ Named Routes

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  // ✅ 1. เพิ่ม GlobalKey<FormState> เพื่อจัดการ Validation
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _emailReg = RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-zA-Z]+$');

  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  /* ─────────────────────────  helpers  ───────────────────────── */

  /// ✅ 2. ปรับปรุง Error Handling และ Navigation
  Future<void> _sendOtp() async {
    // 1. Validate Form ก่อน
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMsg = null;
      });
    }

    try {
      final email = _emailCtrl.text.trim();
      final result = await ApiService.sendOtp(email);
      if (!mounted) return;

      final isSuccess = result['success'] == true;
      final message = result['message'] ?? '';

      // Backend อาจตอบกลับมาว่า success: false แต่มี message ว่าให้รอ cooldown
      // ซึ่งฝั่ง UI ถือว่าเป็น "การส่งสำเร็จ" ในแง่ของ UX
      if (isSuccess || message.startsWith('กรุณารออีก')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ส่งรหัส OTP ไปยังอีเมลแล้ว')),
        );
        if (!mounted) return;
        // 2. ใช้ Named Route ในการไปหน้าถัดไป
        Navigator.pushNamed(context, '/verify_otp', arguments: email);
      } else {
        setState(
            () => _errorMsg = message.isEmpty ? 'เกิดข้อผิดพลาด' : message);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMsg = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'เกิดข้อผิดพลาดในการเชื่อมต่อ');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /* ─────────────────────────  UI  ───────────────────────── */

  @override
  Widget build(BuildContext context) {
    // ✅ 3. ลบ Manual Responsive Calculation และใช้ Theme
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('ลืมรหัสผ่าน'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.lock_reset,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'กรอกอีเมลที่ใช้สมัครเพื่อรับรหัส OTP สำหรับตั้งรหัสผ่านใหม่ของคุณ',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'อีเมลของคุณ',
                style:
                    textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'email@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'กรุณากรอกอีเมล';
                  if (!_emailReg.hasMatch(v.trim()))
                    return 'รูปแบบอีเมลไม่ถูกต้อง';
                  return null;
                },
                onFieldSubmitted: (_) => _sendOtp(),
              ),
              const SizedBox(height: 16),
              if (_errorMsg != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    _errorMsg!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ElevatedButton(
                onPressed: _isLoading ? null : _sendOtp,
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 3),
                      )
                    : const Text('ส่งรหัส OTP'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
