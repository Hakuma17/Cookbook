import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import '../services/api_service.dart';
import 'new_password_screen.dart';
import 'reset_password_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMsg;

  Timer? _timer;
  int _remainingSeconds = 60; // กำหนดค่าเริ่มต้น

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _remainingSeconds = 60);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  Future<void> _resendOtp() async {
    if (_isResending || _remainingSeconds > 0) return;

    setState(() {
      _isResending = true;
      _errorMsg = null;
    });

    try {
      final result = await ApiService.sendOtp(widget.email);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'ส่ง OTP สำเร็จ')),
      );
      if (result['success'] == true) {
        _startCountdown();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เกิดข้อผิดพลาด กรุณาลองใหม่')),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verifyOtp() async {
    // ใช้ Form validation ของ Pinput
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final result =
          await ApiService.verifyOtp(widget.email, _otpController.text);
      if (!mounted) return;

      //  ตรวจสอบผลลัพธ์จาก API อย่างเป็นโครงสร้าง
      if (result['success'] == true) {
        _timer?.cancel();
        // ใช้ pushAndRemoveUntil เพื่อเคลียร์หน้า auth flow ทิ้ง
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => NewPasswordScreen(
              email: widget.email,
              otp: _otpController.text,
            ),
          ),
          (_) => false,
        );
      } else {
        // เช็ค error code แทนการเช็คข้อความ String
        if (result['errorCode'] == 'ACCOUNT_LOCKED') {
          await _showLockedDialog(result['message']);
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
              (_) => false,
            );
          }
        } else {
          setState(() =>
              _errorMsg = result['message'] ?? 'รหัสไม่ถูกต้องหรือหมดอายุ');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showLockedDialog(String? message) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('บัญชีถูกล็อก'),
        content: Text(message ?? 'กรุณาติดต่อเจ้าหน้าที่เพื่อปลดล็อก'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  // ปรับปรุง UI ให้สวยงามและใช้งานง่าย
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // Theme สำหรับ pinput
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: textTheme.headlineSmall?.copyWith(
        fontFamily: 'Mitr',
        color: Colors.black87,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text(
          'ยืนยันรหัส OTP',
          // ใช้ Theme ที่กำหนดไว้ส่วนกลางจะดีที่สุด
          style: textTheme.titleLarge
              ?.copyWith(fontFamily: 'Mitr', color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'เราได้ส่งรหัส OTP ไปที่\n${widget.email}',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge
                        ?.copyWith(fontFamily: 'Mitr', height: 1.5),
                  ),
                  const SizedBox(height: 32),

                  // ใช้ Pinput แทนการสร้าง TextField เอง
                  Pinput(
                    length: 5,
                    controller: _otpController,
                    autofocus: true,
                    defaultPinTheme: defaultPinTheme,
                    focusedPinTheme: defaultPinTheme.copyWith(
                      decoration: defaultPinTheme.decoration!.copyWith(
                        border: Border.all(
                            color: theme.colorScheme.primary, width: 2),
                      ),
                    ),
                    submittedPinTheme: defaultPinTheme.copyWith(
                      decoration: defaultPinTheme.decoration!.copyWith(
                        color: const Color(0xFFE3F2FD), // สีฟ้าอ่อนๆ
                      ),
                    ),
                    validator: (s) {
                      if (s == null || s.length < 5)
                        return 'กรุณากรอกรหัสให้ครบ';
                      return null;
                    },
                    onCompleted: (pin) => _verifyOtp(),
                  ),

                  if (_errorMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        _errorMsg!,
                        style: textTheme.bodyMedium?.copyWith(
                          fontFamily: 'Mitr',
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed:
                          (_isLoading || _isResending) ? null : _verifyOtp,
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 3),
                            )
                          : Text(
                              'ยืนยันรหัส',
                              style: textTheme.labelLarge
                                  ?.copyWith(fontFamily: 'Mitr'),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildResendText(theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResendText(ThemeData theme) {
    if (_remainingSeconds > 0) {
      return Text(
        'ขอรหัสใหม่อีกครั้งได้ใน $_remainingSeconds วินาที',
        style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'Mitr'),
      );
    }
    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodyMedium
            ?.copyWith(fontFamily: 'Mitr', color: Colors.black87),
        children: [
          const TextSpan(text: 'ยังไม่ได้รับรหัส OTP ใช่ไหม? '),
          TextSpan(
            text: 'ส่งรหัสใหม่อีกครั้ง',
            style: TextStyle(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()..onTap = _resendOtp,
          ),
        ],
      ),
    );
  }
}
