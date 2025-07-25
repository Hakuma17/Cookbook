import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  /* ─────────── Form & Controllers ─────────── */
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _hidePass = true;
  bool _hideConfirm = true;

  /* ─────────── State ─────────── */
  bool _isLoading = false;
  String? _errorMsg;
  final _emailReg = RegExp(r'^[\w\.-]+@([\w\-]+\.)+[a-zA-Z]{2,}$');

  @override
  void dispose() {
    _userCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  /* ─────────── Register Method ─────────── */
  /// ✅ 1. ปรับปรุง Error Handling และ Navigation
  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final res = await ApiService.register(
        _emailCtrl.text.trim(),
        _passCtrl.text,
        _confirmCtrl.text,
        _userCtrl.text.trim(),
      );

      if (res['success'] == true) {
        if (!mounted) return;

        // ไปหน้า Verify OTP พร้อมอีเมลที่เพิ่งสมัคร โดยใช้ Named Route
        Navigator.pushReplacementNamed(
          context,
          '/verify_otp',
          arguments: _emailCtrl.text.trim(),
        );
      } else {
        final errs = res['errors'];
        setState(() => _errorMsg = errs is List
            ? errs.join('\n')
            : (res['message'] ?? 'เกิดข้อผิดพลาด'));
      }
    } on ApiException catch (e) {
      setState(() => _errorMsg = e.message);
    } catch (_) {
      setState(() => _errorMsg = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /* ─────────── Build UI ─────────── */
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      // --- ⭐️ จุดที่แก้ไข ⭐️ ---
      // เปลี่ยน AppBar background ให้โปร่งใส และ Scaffold background เป็นสี surface (สีขาว)
      // เพื่อให้เข้ากับดีไซน์เดิมที่คุณต้องการ
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: theme.colorScheme.surface, // 👈 เปลี่ยนเป็นสีขาว
      // -------------------------
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Logo and Title ---
              Image.asset('assets/images/logo.png', height: 100),
              const SizedBox(height: 16),
              Text(
                'สร้างบัญชีใหม่',
                textAlign: TextAlign.center,
                style: textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),

              // --- Form ---
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _userCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อผู้ใช้',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v?.trim().isEmpty ?? true)
                          ? 'กรุณากรอกชื่อผู้ใช้'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'อีเมล',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) =>
                          (v != null && _emailReg.hasMatch(v.trim()))
                              ? null
                              : 'รูปแบบอีเมลไม่ถูกต้อง',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _hidePass,
                      decoration: InputDecoration(
                        labelText: 'รหัสผ่าน (อย่างน้อย 8 ตัวอักษร)',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_hidePass
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _hidePass = !_hidePass),
                        ),
                      ),
                      validator: (v) => (v != null && v.length >= 8)
                          ? null
                          : 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: _hideConfirm,
                      decoration: InputDecoration(
                        labelText: 'ยืนยันรหัสผ่าน',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_hideConfirm
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _hideConfirm = !_hideConfirm),
                        ),
                      ),
                      validator: (v) =>
                          (v == _passCtrl.text) ? null : 'รหัสผ่านไม่ตรงกัน',
                    ),
                    const SizedBox(height: 16),

                    // --- Error Message ---
                    if (_errorMsg != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          _errorMsg!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),

                    // --- Register Button ---
                    ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 3, color: Colors.white),
                            )
                          : const Text('สมัครสมาชิก'),
                    ),
                    const SizedBox(height: 24),

                    // --- Login Link ---
                    Center(
                      child: Text.rich(
                        TextSpan(
                          text: 'มีบัญชีอยู่แล้ว? ',
                          style: textTheme.bodyMedium,
                          children: [
                            TextSpan(
                              text: 'กลับไปลงชื่อเข้าใช้',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
