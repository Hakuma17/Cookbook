import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import '../services/api_service.dart';
// import 'new_password_screen.dart'; // 🗑️ ลบออก เพราะจะใช้ Named Routes
// import 'reset_password_screen.dart';

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
  int _remainingSeconds = 60;

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

  /// ✅ 1. ปรับปรุง Error Handling
  Future<void> _resendOtp() async {
    if (_isResending || _remainingSeconds > 0) return;

    setState(() {
      _isResending = true;
      _errorMsg = null;
    });

    try {
      final result = await ApiService.sendOtp(widget.email);
      if (!mounted) return;

      _showSnack(result['message'] ?? 'ส่ง OTP สำเร็จ', isError: false);
      if (result['success'] == true) {
        _startCountdown();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    } catch (e) {
      if (!mounted) return;
      _showSnack('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final result =
          await ApiService.verifyOtp(widget.email, _otpController.text);
      if (!mounted) return;

      if (result['success'] == true) {
        _timer?.cancel();
        // ✅ 2. ปรับปรุง Navigation ให้ใช้ Named Routes
        // ส่ง email และ otp ไปยังหน้าถัดไปผ่าน arguments
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/new_password',
          (_) => false,
          arguments: {
            'email': widget.email,
            'otp': _otpController.text,
          },
        );
      } else {
        // การเช็ค errorCode ดีอยู่แล้ว
        if (result['errorCode'] == 'ACCOUNT_LOCKED') {
          await _showLockedDialog(result['message']);
          if (mounted) {
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/login', (_) => false);
          }
        } else {
          setState(() =>
              _errorMsg = result['message'] ?? 'รหัสไม่ถูกต้องหรือหมดอายุ');
        }
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMsg = e.message);
    } catch (e) {
      if (mounted)
        setState(() => _errorMsg = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
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

  void _showSnack(String msg, {bool isError = true}) {
    if (!mounted) return;
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? theme.colorScheme.error : Colors.green[600],
    ));
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 3. ใช้ Theme จาก Context
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // Theme สำหรับ pinput ที่ดึงค่าจาก Theme หลัก
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: textTheme.headlineSmall,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
      ),
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('ยืนยันรหัส OTP'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_moon_outlined,
                      size: 80, color: theme.colorScheme.primary),
                  const SizedBox(height: 24),
                  Text(
                    'เราได้ส่งรหัส OTP ไปที่',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.email,
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
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
                        color: theme.colorScheme.primaryContainer,
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
                        style: textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.error),
                      ),
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: (_isLoading || _isResending) ? null : _verifyOtp,
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 3),
                          )
                        : const Text('ยืนยันรหัส'),
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
        style: theme.textTheme.bodyMedium,
      );
    }
    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        children: [
          const TextSpan(text: 'ยังไม่ได้รับรหัส OTP ใช่ไหม? '),
          TextSpan(
            text: 'ส่งรหัสใหม่อีกครั้ง',
            style: TextStyle(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.bold,
            ),
            recognizer: TapGestureRecognizer()..onTap = _resendOtp,
          ),
        ],
      ),
    );
  }
}
