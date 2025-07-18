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

// ── helper สำหรับไปหน้า Home ─────────────────────────────────
void _goToHome(BuildContext context) {
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => const HomeScreen()),
  );
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
  void _navHome() => _goToHome(context);

  /* ── guest access ─────────────────────────────────────────────── */
  void _enterAsGuest() {
    ApiService.clearSession();
    _goToHome(context);
  }

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
      await _googleSignIn.signOut(); // fallback เคลียร์สถานะเดิม
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /* ── build ────────────────────────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    // คำนวณสัดส่วนหน้าจอเพื่อ responsive
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    final padH = w * 0.064; // ~24px
    final padV = h * 0.04; // ~32px
    final spaceXS = h * 0.01; // ~8px
    final spaceMid = h * 0.015; // ~12px
    final spaceS = h * 0.02; // ~16px
    final spaceM = h * 0.03; // ~24px
    final spaceL = h * 0.04; // ~32px
    final spaceXL = h * 0.05; // ~40px
    final btnHeight = h * 0.065; // ~52px
    final logoSize = w * 0.3; // 30% of width
    final iconSize = btnHeight * 0.45;
    final titleFont = w * 0.075; // ~28px
    final btnFont = w * 0.048; // ~18px
    final bodyFont = w * 0.04; // ~16px
    final smallFont = w * 0.037; // ~14px

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: spaceXL),
                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: logoSize,
                    height: logoSize,
                  ),
                ),
                SizedBox(height: spaceS),
                Center(
                  child: Text(
                    'Cooking Guide',
                    style: TextStyle(
                      fontSize: titleFont,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: spaceXL),

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
                SizedBox(height: spaceS),

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
                                  builder: (_) => const ResetPasswordScreen()),
                            ),
                    child: Text(
                      'ลืมรหัสผ่าน',
                      style: TextStyle(fontSize: bodyFont),
                    ),
                  ),
                ),

                SizedBox(height: spaceXS),

                // ── ปุ่มลงชื่อเข้าใช้ ─────────────────────────
                SizedBox(
                  height: btnHeight,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _loginWithEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8C66),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: iconSize,
                            height: iconSize,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'ลงชื่อเข้าใช้',
                            style: TextStyle(
                              fontSize: btnFont,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                if (_errorMsg != null) ...[
                  SizedBox(height: spaceMid),
                  Text(
                    _errorMsg!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],

                SizedBox(height: spaceM),

                // ── สมัครสมาชิก ─────────────────────────────
                Center(
                  child: RichText(
                    text: TextSpan(
                      text: 'ยังไม่มีบัญชีใช่ไหม? ',
                      style:
                          TextStyle(fontSize: smallFont, color: Colors.black54),
                      children: [
                        TextSpan(
                          text: 'สมัครสมาชิกเลย!',
                          style: TextStyle(
                            fontSize: smallFont,
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

                SizedBox(height: spaceL),

                // ── Google Sign-in ───────────────────────────
                SizedBox(
                  height: btnHeight,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _loginWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF2F2F2),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: iconSize,
                            height: iconSize,
                            child: const CircularProgressIndicator(),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset(
                                'assets/icons/google.svg',
                                width: iconSize,
                                height: iconSize,
                              ),
                              SizedBox(width: w * 0.03),
                              Text(
                                'ดำเนินการต่อด้วย Google',
                                style: TextStyle(
                                  fontSize: bodyFont,
                                  color: const Color(0xFF1D1D1F),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                SizedBox(height: spaceS),

                // ── Guest access ─────────────────────────────
                SizedBox(
                  height: btnHeight,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _enterAsGuest,
                    icon: Icon(Icons.login, size: iconSize),
                    label: Text(
                      'เข้าใช้งานโดยไม่ต้องล็อกอิน',
                      style: TextStyle(fontSize: bodyFont),
                    ),
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
