// lib/screens/verify_otp_screen.dart
//
// หมายเหตุ (TH): หน้านี้ยึดหลักไม่ใช้ BuildContext ข้าม await โดยไม่จำเป็น
// - จับบริการที่ต้องพึ่ง context ล่วงหน้าก่อน await
// - ใช้ mounted guard ก่อน setState เพื่อความปลอดภัยใน lifecycle
// - ใช้ PopScope/Material 3 APIs ตามแนวทางใหม่ของแอป
//
// Verify OTP (Email Verification)
// - รับ {email, startCooldown} จากหน้า Register
// - กันกดซ้ำ/กันกดย้อนกลับ (ทั้งปุ่ม back และ gesture)
// - เริ่ม/รีเซ็ต cooldown ปุ่ม "ส่งรหัสอีกครั้ง"
// - ดึง error จาก BE, แสดง snack ตอน resend สำเร็จ
// - verify สำเร็จ: บันทึก login ถ้ามี data + เคลียร์ pending + นำทาง
//
// หมายเหตุ: MyApp จะพาเข้าหน้านี้อัตโนมัติถ้ามี pending verify ใน AuthService

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:google_fonts/google_fonts.dart'; // นำเข้า Google Fonts

import 'package:cookbook/services/auth_service.dart';
import 'package:cookbook/services/api_service.dart';

class VerifyOtpScreen extends StatefulWidget {
  /// อีเมลที่ใช้รับ OTP
  final String email;

  /// เริ่มนับ cooldown ตั้งแต่เข้าหน้าหรือไม่
  final bool startCooldown;

  const VerifyOtpScreen({
    super.key,
    required this.email,
    this.startCooldown = true, // ค่าเริ่มต้น
  });

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  /* ───────── controllers & form ───────── */
  final _otpCtrl = TextEditingController(); // ช่องกรอก OTP
  final _formKey = GlobalKey<FormState>(); // ตรวจความถูกต้อง

  /* ───────── UI state ───────── */
  bool _submitting = false; // ระหว่างกด "ยืนยัน"
  bool _resending = false; // ระหว่างกด "ส่งรหัสอีกครั้ง"
  String? _errorMsg; // ข้อความผิดพลาดใต้ PIN

  /* ───────── resend cooldown ───────── */
  static const int _cooldown = 60; // วินาที
  Timer? _timer;
  int _secLeft = 0; // เหลือกี่วินาที

  @override
  void initState() {
    super.initState();
    _persistPending(startCooldown: widget.startCooldown);
    if (widget.startCooldown) {
      _startCooldown();
    } else {
      _secLeft = 0;
    }
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  /* ───────── helpers ───────── */

  Future<void> _persistPending({required bool startCooldown}) async {
    await AuthService.markPendingEmailVerify(
      email: widget.email,
      startCooldown: startCooldown,
    );
  }

  Future<void> _clearPending() => AuthService.clearPendingEmailVerify();

  void _showSnack(String msg, {bool isError = true}) {
    if (!mounted) return;
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, style: GoogleFonts.itim(fontSize: 16)),
          backgroundColor:
              isError ? theme.colorScheme.error : Colors.green[600],
          behavior: SnackBarBehavior.floating,
        ),
      );
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

  String _mapOtpError(Map res) {
    final code = (res['errorCode'] ?? '').toString().toUpperCase();
    switch (code) {
      case 'OTP_EXPIRED':
        setState(() => _secLeft = 0);
        return 'OTP หมดอายุแล้ว';
      case 'OTP_INCORRECT':
        final left = res['attemptsLeft'];
        return 'OTP ไม่ถูกต้อง${left != null ? ' (เหลือ $left ครั้ง)' : ''}';
      case 'ACCOUNT_LOCKED':
        final wait = res['secondsLeft'];
        return 'บัญชีถูกล็อกชั่วคราว${wait != null ? ' ($wait วินาที)' : ''}';
      default:
        return (res['message'] ?? 'OTP ไม่ถูกต้อง').toString();
    }
  }

  /* ───────── actions ───────── */

  Future<void> _cancelVerification() async {
    final nav = Navigator.of(context); // จับ nav ก่อน await
    await _clearPending();
    if (!mounted) return;
    nav.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Future<void> _verify() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _errorMsg = null;
    });

    try {
      final nav = Navigator.of(context); // จับ nav ตั้งแต่ต้น
      final code = _otpCtrl.text.trim();
      final res = await AuthService.verifyOtp(widget.email, code);
      if (!mounted) return;

      if (res['success'] == true) {
        final data = res['data'];
        if (data is Map<String, dynamic>) {
          await AuthService.saveLoginData(data);
        }
        await _clearPending();
        // แสดงข้อความยืนยันสำเร็จ
        if (mounted) {
          _showSnack('ยืนยันอีเมลสำเร็จ! ยินดีต้อนรับ', isError: false);
        }
        // รอสักครู่แล้วไปหน้า Home
        await Future.delayed(const Duration(milliseconds: 1500));
        if (!mounted) return;
        nav.pushNamedAndRemoveUntil('/home', (_) => false);
      } else {
        setState(() => _errorMsg = _mapOtpError(res));
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
    if (_secLeft > 0 || _resending) {
      return;
    }

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
        await _persistPending(startCooldown: true);
      } else {
        final code = (res['errorCode'] ?? '').toString().toUpperCase();
        if (code == 'RATE_LIMIT' && (res['secondsLeft'] is int)) {
          setState(() => _secLeft = res['secondsLeft'] as int);
        }
        setState(() =>
            _errorMsg = (res['message'] ?? 'ส่ง OTP ใหม่ไม่สำเร็จ').toString());
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMsg = e.message);
    } catch (_) {
      if (mounted) setState(() => _errorMsg = 'เกิดข้อผิดพลาดในการเชื่อมต่อ');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  /* ───────── UI ───────── */

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txt = theme.textTheme;

    // ★ กำหนดสีเฉพาะของหน้าจอนี้
    const primaryBrown = Color(0xFF967259);
    const pinBoxBg = Color(0xFFF5E4DE);
    const pinBoxBorder = Color(0xFFDBC8C1);

    // ★ กำหนด PinTheme โดยใช้สีที่กำหนดเอง
    final defaultPinTheme = PinTheme(
      width: 58,
      height: 62,
      textStyle: GoogleFonts.itim(fontSize: 24, color: primaryBrown),
      decoration: BoxDecoration(
        color: pinBoxBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pinBoxBorder),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: primaryBrown, width: 2),
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: pinBoxBg,
      ),
    );

    return PopScope(
      canPop: false, // ป้องกันการย้อนกลับ
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('ยืนยันอีเมล'),
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          centerTitle: true,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 20, 32, 28),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.shield_moon_outlined,
                    size: 90,
                    color: primaryBrown,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'ยินดีต้อนรับสู่ Cookbook!',
                    style: txt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: primaryBrown,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'กรุณายืนยันอีเมลเพื่อเริ่มใช้งาน',
                    style: txt.bodyLarge?.copyWith(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ป้อนรหัสที่ส่งไปยัง',
                    style: txt.bodyLarge?.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.email,
                    style: GoogleFonts.itim(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Pinput(
                    length: 6,
                    controller: _otpCtrl,
                    autofocus: true, // โฟกัสอัตโนมัติที่ช่อง PIN
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    defaultPinTheme: defaultPinTheme,
                    focusedPinTheme: focusedPinTheme,
                    submittedPinTheme: submittedPinTheme,
                    validator: (s) {
                      if (s == null || s.trim().length != 6) {
                        return 'กรุณากรอกรหัส 6 หลัก';
                      }
                      return null;
                    },
                    onChanged: (_) {
                      if (_errorMsg != null) setState(() => _errorMsg = null);
                    },
                    onCompleted: (_) => _verify(),
                  ),
                  if (_errorMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Text(
                        _errorMsg!,
                        style: GoogleFonts.itim(
                          fontSize: 17,
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBrown,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: GoogleFonts.itim(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _submitting ? null : _verify,
                      child: _submitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.white,
                              ),
                            )
                          : const Text('ยืนยัน'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _resending || _secLeft > 0 ? null : _resend,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurface,
                    ),
                    child: _resending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Text(
                            _secLeft > 0
                                ? 'ส่งอีกครั้งใน ($_secLeft)'
                                : 'ส่งรหัสอีกครั้ง',
                            style: GoogleFonts.itim(fontSize: 18),
                          ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    // ปุ่มยกเลิกกระบวนการยืนยัน
                    onPressed: _cancelVerification,
                    child: Text(
                      'ใช้อีเมลอื่น',
                      style: GoogleFonts.itim(
                        fontSize: 18,
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
