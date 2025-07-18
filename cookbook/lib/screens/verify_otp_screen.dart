import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cookbook/services/auth_service.dart';
import 'package:pinput/pinput.dart';
import 'edit_profile_screen.dart';

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
  String? _error;

  // Cooldown logic (เหมือนเดิม)
  static const int _cooldown = 60;
  Timer? _timer;
  int _secLeft = 0;

  @override
  void initState() {
    super.initState();
    // เริ่ม cooldown ทันทีที่หน้าจอถูกสร้าง (เป็นทางเลือก)
    // _startCooldown();
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verify() async {
    // ใช้ Form key ในการ validate
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final res = await AuthService.verifyOtp(widget.email, _otpCtrl.text);
    if (!mounted) return;

    setState(() => _submitting = false);

    if (res['success'] == true) {
      // ✅ พาไปหน้าแก้โปรไฟล์และล้างหน้าก่อนหน้าทั้งหมดทิ้ง
      // เพื่อไม่ให้ผู้ใช้กด back กลับมาหน้า auth flow ได้อีก
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const EditProfileScreen()),
        (_) => false,
      );
    } else {
      setState(() => _error = res['message'] ?? 'OTP ไม่ถูกต้อง');
    }
  }

  // Resend logic (เหมือนเดิม)
  Future<void> _resend() async {
    if (_secLeft > 0) return;

    setState(() {
      _resending = true;
      _error = null;
    });
    final res = await AuthService.resendOtp(widget.email);
    setState(() => _resending = false);

    if (res['success'] == true) {
      _startCooldown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('ส่ง OTP ใหม่แล้ว'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } else {
      setState(() => _error = res['message'] ?? 'ส่ง OTP ไม่สำเร็จ');
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
      if (_secLeft == 0) {
        timer.cancel();
        setState(() {});
      } else {
        setState(() => _secLeft--);
      }
    });
  }

  void _skip() {
    Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Theme สำหรับ pinput
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: theme.textTheme.headlineSmall,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.transparent),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('ยืนยันตัวตน')),
      body: Center(
        //  จัดให้อยู่กลางจอ
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            //  หุ้มด้วย Form
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield_moon_outlined,
                    size: 80, color: Colors.grey),
                const SizedBox(height: 24),
                Text(
                  'ป้อนรหัสที่ส่งไปยัง',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.email,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                //
                Pinput(
                  length: 6,
                  controller: _otpCtrl,
                  autofocus: true,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: defaultPinTheme.copyWith(
                    decoration: defaultPinTheme.decoration!.copyWith(
                      border: Border.all(color: theme.colorScheme.primary),
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

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(_error!,
                        style: TextStyle(color: theme.colorScheme.error)),
                  ),
                const SizedBox(height: 24),

                // ปุ่มยืนยัน
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
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

                // ปุ่มข้าม
                TextButton(
                  onPressed: _skip,
                  child: const Text('ข้ามไปก่อน'),
                ),
                const SizedBox(height: 24),

                // ปุ่มขอรหัสใหม่
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
