import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'new_password_screen.dart';
import 'reset_password_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  const OtpVerificationScreen({Key? key, required this.email})
      : super(key: key);

  @override
  _OtpVerificationScreenState createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const int otpLength = 5;
  static const int resendDelay = 60;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMsg;

  Timer? _timer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(otpLength, (_) => FocusNode());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
      _startCountdown();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
  }

  bool get _isOtpComplete => _controllers.every((c) => c.text.isNotEmpty);
  String get _otpCode => _controllers.map((c) => c.text).join();

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _remainingSeconds = resendDelay);

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      // ถ้า widget ถูก dispose ไปแล้ว ให้ cancel timer เลย
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

  Future<void> _resendOtp() async {
    if (_isResending) return;
    if (!mounted) return;

    setState(() {
      _isResending = true;
      _errorMsg = null;
    });

    try {
      final result = await ApiService.sendOtp(widget.email);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'ส่ง OTP ไม่สำเร็จ')));
      if (result['success'] == true && mounted) {
        _startCountdown();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('เกิดข้อผิดพลาด กรุณาลองใหม่')));
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (!_isOtpComplete || _isLoading) return;
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final result = await ApiService.verifyOtp(widget.email, _otpCode);

      if (result['success'] == true) {
        // — OTP ถูกต้อง! —
        _timer?.cancel();
        if (!mounted) return;

        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => NewPasswordScreen(
              email: widget.email,
              otp: _otpCode,
            ),
          ),
        );
        return;
      }

      final msg = result['message'] ?? 'รหัสไม่ถูกต้องหรือหมดอายุ';
      if (msg.contains('ล็อก')) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('บัญชีถูกล็อก'),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ตกลง'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
          (_) => false,
        );
        return;
      }

      if (mounted) setState(() => _errorMsg = msg);
    } catch (_) {
      if (mounted)
        setState(() => _errorMsg = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 54,
      height: 54,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFFA726), width: 2),
          ),
        ),
        onChanged: (val) {
          if (val.isNotEmpty && index < otpLength - 1) {
            _focusNodes[index + 1].requestFocus();
          } else if (val.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          if (mounted) setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text(
          'ยืนยันรหัส OTP ของคุณ',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w500,
            fontSize: 24,
            color: Colors.black,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'เราได้ส่งรหัส OTP ไปที่\n${widget.email}',
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                  height: 1.3,
                  color: Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 35),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(otpLength, _buildOtpBox),
              ),
              const SizedBox(height: 30),
              if (_errorMsg != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 30),
                  child: Text(
                    _errorMsg!,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                      color: Colors.red,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 49,
                child: ElevatedButton(
                  onPressed:
                      (!_isOtpComplete || _isLoading) ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC79C),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.black, strokeWidth: 2),
                        )
                      : const Text(
                          'ยืนยันรหัส',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w500,
                            fontSize: 20,
                            color: Colors.black,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 30),
              Center(
                child: _remainingSeconds > 0
                    ? Text(
                        'ขอรหัสใหม่อีกครั้งได้ใน $_remainingSeconds วินาที',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                          color: Color(0xFF666666),
                        ),
                      )
                    : RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w400,
                            fontSize: 16,
                            color: Color(0xFF666666),
                          ),
                          children: [
                            const TextSpan(
                                text: 'ยังไม่ได้รับรหัส OTP ใช่ไหม? '),
                            TextSpan(
                              text: 'ส่งรหัสใหม่อีกครั้ง',
                              style: const TextStyle(
                                color: Color(0xFF2196F3),
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  if (!_isLoading && !_isResending) {
                                    _resendOtp();
                                  }
                                },
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
