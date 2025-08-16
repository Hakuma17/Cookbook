// lib/screens/verify_otp_screen.dart
//
// 2025-08-10 – Verify OTP (email verification) polish
// - ใช้ Theme/Named Routes ให้สอดคล้องทั้งแอป
// - กันกดซ้ำ, บังคับกรอกตัวเลข 6 หลัก, แสดง cooldown ส่งซ้ำ
// - หลัง verify: login อัตโนมัติถ้า backend ส่ง user data กลับมา
//   -> ถ้าล็อกอินแล้วไป /home, ถ้าไม่ ไป /login
// - เคลียร์ error เมื่อพิมพ์/เปลี่ยนค่า, ปรับ snackbar ให้พร้อมใช้งาน
//
// 2025-08-12 – UI polish for larger typography (ให้เข้ากับ main.dart)
// - ขยายขนาดตัวอักษร/spacing และ PIN box
// - ปรับปุ่ม/Progress ให้ใหญ่ขึ้น อ่านง่ายขึ้น
// - เคลียร์โค้ดเล็กๆ: ป้องกัน double-submit และยกเลิก Timer เสมอ
//
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';

import 'package:cookbook/services/auth_service.dart';
import 'package:cookbook/services/api_service.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String email;
  const VerifyOtpScreen({super.key, required this.email});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final _otpCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _submitting = false;
  bool _resending = false;
  String? _errorMsg;

  // Cooldown logic
  static const int _cooldown = 60;
  Timer? _timer;
  int _secLeft = 0;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  /* ───────── actions ───────── */

  Future<void> _verify() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _errorMsg = null;
    });

    try {
      final code = _otpCtrl.text.trim();
      final res = await AuthService.verifyOtp(widget.email, code);

      if (!mounted) return;

      if (res['success'] == true) {
        // ถ้า backend ส่งข้อมูลผู้ใช้กลับมา → บันทึกให้ล็อกอินทันที
        final data = res['data'];
        if (data is Map<String, dynamic>) {
          await AuthService.saveLoginData(data);
        }

        // เช็คสถานะล็อกอินจริง แล้วนำทางให้เหมาะสม
        final loggedIn = await AuthService.isLoggedIn();
        Navigator.of(context).pushNamedAndRemoveUntil(
          loggedIn ? '/home' : '/login',
          (_) => false,
        );
      } else {
        setState(() => _errorMsg = res['message'] ?? 'OTP ไม่ถูกต้อง');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMsg = e.message);
    } catch (_) {
      if (mounted) setState(() => _errorMsg = 'เกิดข้อผิดพลาดในการเชื่อมต่อ');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resend() async {
    if (_secLeft > 0 || _resending) return;

    setState(() {
      _resending = true;
      _errorMsg = null;
    });

    try {
      final res = await AuthService.resendOtp(widget.email);
      if (!mounted) return;

      if (res['success'] == true) {
        _startCooldown();
        _showSnack('ส่ง OTP ใหม่แล้ว', isError: false);
      } else {
        setState(() => _errorMsg = res['message'] ?? 'ส่ง OTP ใหม่ไม่สำเร็จ');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMsg = e.message);
    } catch (_) {
      if (mounted) setState(() => _errorMsg = 'เกิดข้อผิดพลาดในการเชื่อมต่อ');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _startCooldown() {
    _secLeft = _cooldown;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secLeft <= 1) {
        t.cancel();
        setState(() => _secLeft = 0);
      } else {
        setState(() => _secLeft--);
      }
    });
  }

  void _skip() {
    // ไปหน้า Home ในฐานะ Guest
    Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
  }

  void _showSnack(String msg, {bool isError = true}) {
    if (!mounted) return;
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? theme.colorScheme.error : Colors.green[600],
      behavior: SnackBarBehavior.floating,
    ));
  }

  /* ───────── build ───────── */

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txt = theme.textTheme;

    // PIN theme — ให้ใหญ่ขึ้นเพื่อ match กับตัวหนังสือของแอป
    final baseBox = BoxDecoration(
      color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
    );

    final defaultPinTheme = PinTheme(
      width: 58,
      height: 66,
      textStyle: txt.titleLarge, // ใหญ่ขึ้น
      decoration: baseBox,
    );

    final focusedTheme = defaultPinTheme.copyWith(
      decoration: baseBox.copyWith(
        border: Border.all(color: theme.colorScheme.primary, width: 2),
      ),
    );

    final submittedTheme = defaultPinTheme.copyWith(
      decoration: baseBox.copyWith(
        color: theme.colorScheme.primaryContainer,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('ยืนยันอีเมล')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_moon_outlined,
                    size: 88, color: theme.colorScheme.primary),
                const SizedBox(height: 26),
                Text('ป้อนรหัสที่ส่งไปยัง', style: txt.titleMedium),
                const SizedBox(height: 10),
                Text(
                  widget.email,
                  style: txt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 34),

                // PIN input (6 digits, ตัวเลขเท่านั้น)
                Pinput(
                  length: 6,
                  controller: _otpCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedTheme,
                  submittedPinTheme: submittedTheme,
                  validator: (s) {
                    if (s == null || s.trim().length != 6) {
                      return 'กรุณากรอกรหัส 6 หลัก';
                    }
                    return null;
                  },
                  onChanged: (_) {
                    if (_errorMsg != null) {
                      setState(() => _errorMsg = null);
                    }
                  },
                  onCompleted: (_) => _verify(),
                ),

                if (_errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _errorMsg!,
                      style: txt.bodyLarge
                          ?.copyWith(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: 26),
                ElevatedButton(
                  onPressed: _submitting ? null : _verify,
                  child: _submitting
                      ? const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : const Text('ยืนยัน'),
                ),

                const SizedBox(height: 14),
                TextButton(
                  onPressed: _skip,
                  child: const Text('ข้ามไปก่อน'),
                ),

                const SizedBox(height: 26),
                TextButton(
                  onPressed: _resending || _secLeft > 0 ? null : _resend,
                  child: _resending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _secLeft > 0
                              ? 'ส่งอีกครั้งใน ($_secLeft)'
                              : 'ส่งรหัสอีกครั้ง',
                          style: txt.titleMedium,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
