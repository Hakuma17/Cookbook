import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cookbook/services/auth_service.dart';
import 'package:cookbook/services/api_service.dart';
import 'package:pinput/pinput.dart';
// import 'edit_profile_screen.dart'; // 🗑️ ลบออก เพราะจะใช้ Named Routes

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
    _startCooldown(); // เริ่มนับถอยหลังทันทีที่เข้ามาหน้านี้
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  /// 2. ปรับปรุง Error Handling และ Navigation
  Future<void> _verify() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _errorMsg = null;
    });

    try {
      final res = await AuthService.verifyOtp(widget.email, _otpCtrl.text);
      if (!mounted) return;

      if (res['success'] == true) {
        // เมื่อ OTP ถูกต้อง, ให้บันทึกข้อมูล login (ถ้า API ส่งกลับมา)
        // และเคลียร์ Stack ทั้งหมดแล้วไปหน้า Home
        // หมายเหตุ: Backend ควรส่งข้อมูล user กลับมาด้วยหลัง verify OTP สำเร็จ
        if (res['data'] != null && res['data'] is Map<String, dynamic>) {
          await AuthService.saveLoginData(res['data']);
        }
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
      } else {
        setState(() => _errorMsg = res['message'] ?? 'OTP ไม่ถูกต้อง');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMsg = e.message);
    } catch (e) {
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
      if (res['success'] == true) {
        _startCooldown();
        if (mounted) {
          _showSnack('ส่ง OTP ใหม่แล้ว', isError: false);
        }
      } else {
        setState(() => _errorMsg = res['message'] ?? 'ส่ง OTP ใหม่ไม่สำเร็จ');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMsg = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'เกิดข้อผิดพลาดในการเชื่อมต่อ');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _startCooldown() {
    _secLeft = _cooldown;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secLeft <= 1) {
        timer.cancel();
        setState(() => _secLeft = 0);
      } else {
        setState(() => _secLeft--);
      }
    });
  }

  void _skip() {
    // การข้ามควรจะพาไปหน้า Home ในฐานะ Guest
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

  @override
  Widget build(BuildContext context) {
    //  3. ใช้ Theme จาก Context
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
      appBar: AppBar(title: const Text('ยืนยันอีเมล')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_moon_outlined,
                    size: 80, color: theme.colorScheme.primary),
                const SizedBox(height: 24),
                Text('ป้อนรหัสที่ส่งไปยัง', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  widget.email,
                  style: textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Pinput(
                  length: 6,
                  controller: _otpCtrl,
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
                    if (s == null || s.length < 6) return 'กรุณากรอกรหัสให้ครบ';
                    return null;
                  },
                  onCompleted: (pin) => _verify(),
                ),
                if (_errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(_errorMsg!,
                        style: TextStyle(color: theme.colorScheme.error)),
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitting ? null : _verify,
                  child: _submitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 3, color: Colors.white),
                        )
                      : const Text('ยืนยัน'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _skip,
                  child: const Text('ข้ามไปก่อน'),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: _resending || _secLeft > 0 ? null : _resend,
                  child: _resending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _secLeft > 0
                              ? 'ส่งอีกครั้งใน ($_secLeft)'
                              : 'ส่งรหัสอีกครั้ง',
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
