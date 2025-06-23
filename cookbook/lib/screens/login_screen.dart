// lib/screens/login_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'reset_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /* ── controllers ────────────────────────────────────────────────── */
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _emailReg = RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-zA-Z]+$');

  /* ── google ────────────────────────────────────────────────────── */
  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', 'openid'],
    serverClientId:
        '84901598956-dui13r3k1qmvo0t0kpj6h5mhjrjbvoln.apps.googleusercontent.com',
  );

  /* ── ui state ──────────────────────────────────────────────────── */
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  /* ── navigation ───────────────────────────────────────────────── */
  void _navHome() => Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (_) => const HomeScreen()));

  /* ── helpers ──────────────────────────────────────────────────── */
  void _setErr(String? m) {
    if (!mounted) return;
    setState(() {
      _errorMsg = m;
    });
  }

  String _fmtErr(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException')) return 'ไม่มีการเชื่อมต่ออินเทอร์เน็ต';
    if (msg.contains('TimeoutException'))
      return 'เซิร์ฟเวอร์ตอบช้า ลองใหม่ภายหลัง';
    return 'รหัสผ่านหรืออีเมลไม่ถูกต้อง';
  }

  /* ── email/password login ─────────────────────────────────────── */
  Future<void> _loginWithEmail() async {
    // ตรวจฟอร์มก่อน submit
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final res = await ApiService.login(
        _emailCtrl.text.trim(),
        _passCtrl.text,
      ).timeout(const Duration(seconds: 10));

      // ตรวจผลลัพธ์จาก API
      if (res['success'] != true) {
        _setErr(res['message'] ?? 'รหัสผ่านหรืออีเมลไม่ถูกต้อง');
        return;
      }

      await AuthService.saveLoginData(res['data']);
      _navHome();
    } on TimeoutException {
      _setErr('เซิร์ฟเวอร์ไม่ตอบสนอง');
    } on SocketException {
      _setErr('ไม่มีการเชื่อมต่ออินเทอร์เน็ต');
    } catch (e) {
      _setErr(_fmtErr(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /* ── google sign-in ───────────────────────────────────────────── */
  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      final account = await _googleSignIn.signIn();
      if (account == null) throw Exception('ยกเลิกการล็อกอินด้วย Google');

      final token = (await account.authentication).idToken;
      if (token == null) throw Exception('ไม่สามารถดึง Google ID Token ได้');

      final res = await ApiService.googleSignIn(token)
          .timeout(const Duration(seconds: 10));

      if (res['success'] != true) {
        _setErr(res['message'] ?? 'ไม่สามารถล็อกอินด้วย Google ได้');
        return;
      }

      await AuthService.saveLoginData(res['data']);
      _navHome();
    } on TimeoutException {
      _setErr('เซิร์ฟเวอร์ไม่ตอบสนอง');
    } on SocketException {
      _setErr('ไม่มีการเชื่อมต่ออินเทอร์เน็ต');
    } catch (e) {
      _setErr(_fmtErr(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /* ── build ────────────────────────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            // ปิด real-time validation
            autovalidateMode: AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                // โลโก้ & หัวเรื่อง
                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: w * .3,
                    height: w * .3,
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Cooking Guide',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 40),

                // ── อีเมล ─────────────────────────────────
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _fieldDeco('อีเมล'),
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    if (text.isEmpty) return 'กรุณากรอกอีเมล';
                    if (!_emailReg.hasMatch(text))
                      return 'ฟอร์แมตอีเมลไม่ถูกต้อง';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── รหัสผ่าน ────────────────────────────────
                TextFormField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: _fieldDeco('รหัสผ่าน'),
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    if (text.isEmpty) return 'กรุณากรอกรหัสผ่าน';
                    if (text.length < 6) return 'รหัสผ่านอย่างน้อย 6 ตัวอักษร';
                    return null;
                  },
                ),

                // ── ลืมรหัสผ่าน ─────────────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ResetPasswordScreen(),
                              ),
                            ),
                    child: const Text('ลืมรหัสผ่าน'),
                  ),
                ),

                const SizedBox(height: 8),

                // ── ปุ่มลงชื่อเข้าใช้ ─────────────────────────
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _loginWithEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8C66),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'ลงชื่อเข้าใช้',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                  ),
                ),

                // ── ข้อความข้อผิดพลาด ─────────────────────────
                if (_errorMsg != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMsg!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],

                const SizedBox(height: 24),

                // ── สมัครสมาชิก ─────────────────────────────
                Center(
                  child: RichText(
                    text: TextSpan(
                      text: 'ยังไม่มีบัญชีใช่ไหม? ',
                      style:
                          const TextStyle(fontSize: 14, color: Colors.black54),
                      children: [
                        TextSpan(
                          text: 'สมัครสมาชิกเลย!',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            color: Colors.black87,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const RegisterScreen()),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Google Sign-in ───────────────────────────
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _loginWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF2F2F2),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset(
                                'assets/icons/google.svg',
                                width: 24,
                                height: 24,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'ดำเนินการต่อด้วย Google',
                                style: TextStyle(
                                    fontSize: 16, color: Color(0xFF1D1D1F)),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                    ),
                    icon: const Icon(Icons.login),
                    label: const Text('เข้าใช้งานโดยไม่ต้องล็อกอิน',
                        style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF2F2F2),
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /* ── ui helpers ───────────────────────────────────────────────── */
  InputDecoration _fieldDeco(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF2F2F2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );
}
