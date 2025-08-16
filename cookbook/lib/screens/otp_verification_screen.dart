// lib/screens/otp_verification_screen.dart
//
// 2025-08-12 – Align with API "Option B" reset_token + UI polish
// - ใช้ ApiService.resendOtp() แทน sendOtp()
// - หลัง verify สำเร็จ ดึง reset_token แล้วส่งต่อไป /new_password
//   ใน args: { email, otp: reset_token } (คง key 'otp' ให้เข้ากับ NewPasswordScreen)
// - ปรับ Pinput/typography/padding ให้เข้ากับธีมตัวใหญ่
// - เพิ่ม haptic feedback และกัน snack ซ้อน
//
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ตัวกรองตัวเลข + haptics
import 'package:pinput/pinput.dart';

import '../services/api_service.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();

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

  /* ───────── countdown ───────── */
  void _startCountdown() {
    _timer?.cancel();
    setState(() => _remainingSeconds = 60);

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        t.cancel();
        setState(() => _remainingSeconds = 0);
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  /* ───────── helpers ───────── */
  void _showSnack(String msg, {bool isError = true}) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // กัน snack ซ้อน
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError ? cs.error : Colors.green[600],
        ),
      );
  }

  String? _extractResetToken(Map<String, dynamic> res) {
    // รองรับทั้ง {reset_token} / {data:{reset_token}} / {token} / {data:{token}}
    final data = res['data'];
    if (data is Map && data['reset_token'] != null) {
      return data['reset_token'].toString();
    }
    if (res['reset_token'] != null) return res['reset_token'].toString();
    if (data is Map && data['token'] != null) return data['token'].toString();
    if (res['token'] != null) return res['token'].toString();
    return null;
  }

  /* ───────── actions ───────── */
  Future<void> _resendOtp() async {
    if (_isResending || _remainingSeconds > 0) return;

    setState(() {
      _isResending = true;
      _errorMsg = null;
    });

    try {
      // ใช้ resendOtp ตามสเต็ป
      final result = await ApiService.resendOtp(widget.email);
      if (!mounted) return;

      final msg = (result['message'] ?? 'ส่ง OTP สำเร็จ').toString();
      final code = (result['errorCode'] ?? '').toString().toUpperCase();
      final looksLikeCooldown = code == 'RATE_LIMIT' ||
          msg.contains('กรุณารอ') ||
          msg.contains('วินาที');

      _showSnack(msg, isError: false);
      if (result['success'] == true || looksLikeCooldown) {
        _startCountdown();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnack('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isLoading) return;

    // ซ่อนคีย์บอร์ดก่อนยิง API
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final result =
          await ApiService.verifyOtp(widget.email, _otpController.text);
      if (!mounted) return;

      if (result['success'] == true) {
        final token = _extractResetToken(
            (result is Map<String, dynamic>) ? result : <String, dynamic>{});
        if (token == null || token.isEmpty) {
          // กันกรณี backend ยังไม่ส่ง token
          setState(() => _errorMsg = 'ไม่พบโทเค็นสำหรับตั้งรหัสผ่านใหม่');
          return;
        }

        _timer?.cancel();
        HapticFeedback.lightImpact();

        // ส่ง token ต่อไปใน key 'otp' (เพื่อเข้ากับ NewPasswordScreen)
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/new_password',
          (_) => false,
          arguments: {'email': widget.email, 'otp': token},
        );
      } else {
        final code = (result['errorCode'] ?? '').toString().toUpperCase();
        if (code == 'ACCOUNT_LOCKED') {
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
    } catch (_) {
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

  /* ───────── build ───────── */
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final defaultPinTheme = PinTheme(
      width: 60, // ↑ ใหญ่ขึ้นเล็กน้อย
      height: 68,
      textStyle: textTheme.titleLarge, // ↑ เข้ากับธีมตัวใหญ่
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
      ),
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('ยืนยันรหัส OTP')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_moon_outlined,
                      size: 80, color: theme.colorScheme.primary),
                  const SizedBox(height: 24),
                  Text('เราได้ส่งรหัส OTP ไปที่',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(widget.email,
                      textAlign: TextAlign.center,
                      style: textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 32),

                  // จำกัดเป็นตัวเลข + เคลียร์ error เมื่อพิมพ์ใหม่
                  Pinput(
                    length: 5, // ให้ตรงกับฝั่ง PHP: OTP_LEN = 5
                    controller: _otpController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                      if (s == null || s.length != 5) {
                        return 'กรุณากรอกรหัสให้ครบ 5 หลัก';
                      }
                      return null;
                    },
                    onChanged: (_) {
                      if (_errorMsg != null) {
                        setState(() => _errorMsg = null);
                      }
                    },
                    onCompleted: (_) => _verifyOtp(),
                  ),

                  if (_errorMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        _errorMsg!,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge
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

                  // รีเซ็นด์
                  _buildResend(theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResend(ThemeData theme) {
    if (_remainingSeconds > 0) {
      return Text(
        'ขอรหัสใหม่อีกครั้งได้ใน $_remainingSeconds วินาที',
        style: theme.textTheme.bodyLarge,
      );
    }
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: theme.textTheme.bodyLarge
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        children: [
          const TextSpan(text: 'ยังไม่ได้รับรหัส OTP ใช่ไหม? '),
          TextSpan(
            text: _isResending ? 'กำลังส่ง…' : 'ส่งรหัสใหม่อีกครั้ง',
            style: TextStyle(
              color: _isResending
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.primary,
              decoration:
                  _isResending ? TextDecoration.none : TextDecoration.underline,
              fontWeight: FontWeight.bold,
            ),
            recognizer: _isResending
                ? null
                : (TapGestureRecognizer()..onTap = _resendOtp),
          ),
        ],
      ),
    );
  }
}
