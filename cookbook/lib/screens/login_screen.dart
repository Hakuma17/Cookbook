// lib/screens/login_screen.dart
import 'dart:async';
// import 'dart:io'; // 🗑️ ไม่ได้ใช้

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /* ── controllers & keys ───────────────────────────────────────── */
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _emailReg =
      RegExp(r'^[\w\.\-]+@[\w\-]+\.[A-Za-z]{2,}$'); // ★ Fix: เข้มขึ้น

  // ★ Added: โฟกัส+ซ่อนไอคอนรหัสผ่าน
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  bool _obscurePass = true;

  /* ── google ────────────────────────────────────────────────────── */
  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', 'openid'],
    // TODO: ย้าย serverClientId ไป .env/secret ใน build config
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
    _emailFocus.dispose(); // ★ Added
    _passFocus.dispose(); // ★ Added
    super.dispose();
  }

  /* ── navigation ───────────────────────────────────────────────── */
  void _navToHome() {
    // ใช้ replacement เพื่อตัด stack หน้า login ออก
    Navigator.of(context).pushReplacementNamed('/home', result: true);
  }

  /* ── helpers ──────────────────────────────────────────────────── */
  void _setLoading(bool v) {
    if (!mounted) return;
    setState(() {
      _isLoading = v;
      if (v) _errorMsg = null;
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  /* ── actions ──────────────────────────────────────────────────── */
  Future<void> _enterAsGuest() async {
    await AuthService.logout();
    _navToHome();
  }

  Future<void> _loginWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    _setLoading(true);
    try {
      final res = await ApiService.login(
        _emailCtrl.text.trim(),
        _passCtrl.text,
      );

      if (res['success'] != true) {
        setState(
            () => _errorMsg = res['message'] ?? 'อีเมลหรือรหัสผ่านไม่ถูกต้อง');
        return;
      }

      await AuthService.saveLoginData(res['data']);
      _navToHome();
    } on ApiException catch (e) {
      setState(() => _errorMsg = e.message);
    } catch (_) {
      setState(() => _errorMsg = 'เกิดข้อผิดพลาดที่ไม่รู้จัก');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loginWithGoogle() async {
    _setLoading(true);
    try {
      // รีเฟรช session ทุกครั้ง
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }

      final account = await _googleSignIn.signIn();
      if (account == null) return; // ผู้ใช้กดยกเลิก

      final auth = await account.authentication;
      final token = auth.idToken;
      if (token == null) {
        throw ApiException('ไม่สามารถดึง Google ID Token ได้');
      }

      final res = await ApiService.googleSignIn(token);
      if (res['success'] != true) {
        setState(
            () => _errorMsg = res['message'] ?? 'ล็อกอินด้วย Google ล้มเหลว');
        return;
      }

      await AuthService.saveLoginData(res['data']);
      _navToHome();
    } on ApiException catch (e) {
      setState(() => _errorMsg = e.message);
      await _googleSignIn.signOut(); // เคลียร์ state
    } catch (_) {
      setState(() => _errorMsg = 'เกิดข้อผิดพลาดในการล็อกอินด้วย Google');
      await _googleSignIn.signOut();
    } finally {
      _setLoading(false);
    }
  }

  /* ── build ────────────────────────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 32.0),
                child: Form(
                  key: _formKey,
                  autovalidateMode:
                      AutovalidateMode.onUserInteraction, // ★ Added
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- Logo and Title ---
                      Image.asset('assets/images/logo.png', height: 100),
                      const SizedBox(height: 16),
                      Text(
                        'Cooking Guide',
                        textAlign: TextAlign.center,
                        style: textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 40),

                      // --- Email Field ---
                      TextFormField(
                        controller: _emailCtrl,
                        focusNode: _emailFocus,
                        textInputAction: TextInputAction.next, // ★ Added
                        onFieldSubmitted: (_) => _passFocus.requestFocus(),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email
                        ],
                        decoration: const InputDecoration(labelText: 'อีเมล'),
                        validator: (v) {
                          final t = v?.trim() ?? '';
                          if (t.isEmpty) return 'กรุณากรอกอีเมล';
                          if (!_emailReg.hasMatch(t))
                            return 'รูปแบบอีเมลไม่ถูกต้อง';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // --- Password Field ---
                      TextFormField(
                        controller: _passCtrl,
                        focusNode: _passFocus,
                        textInputAction: TextInputAction.done, // ★ Added
                        onFieldSubmitted: (_) =>
                            _isLoading ? null : _loginWithEmail(),
                        obscureText: _obscurePass, // ★ toggle
                        obscuringCharacter: '•',
                        enableSuggestions: false,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'รหัสผ่าน',
                          suffixIcon: IconButton(
                            tooltip:
                                _obscurePass ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                            icon: Icon(
                              _obscurePass
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 22,
                            ),
                            onPressed: () =>
                                setState(() => _obscurePass = !_obscurePass),
                          ),
                        ),
                        validator: (v) {
                          final t = v ?? '';
                          if (t.isEmpty) return 'กรุณากรอกรหัสผ่าน';
                          if (t.length < 6)
                            return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                          return null;
                        },
                      ),

                      // --- Forgot Password ---
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.pushNamed(
                                  context, '/reset_password'),
                          child: const Text('ลืมรหัสผ่าน?'),
                        ),
                      ),

                      // --- Error Message ---
                      if (_errorMsg != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            _errorMsg!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: cs.error),
                          ),
                        ),

                      // --- Login Button ---
                      ElevatedButton(
                        onPressed: _isLoading ? null : _loginWithEmail,
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Text('ลงชื่อเข้าใช้'),
                      ),
                      const SizedBox(height: 16),

                      // --- Register Link ---
                      Center(
                        child: RichText(
                          text: TextSpan(
                            text: 'ยังไม่มีบัญชีใช่ไหม? ',
                            style: textTheme.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant),
                            children: [
                              TextSpan(
                                text: 'สมัครสมาชิกเลย!',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                  color: cs.primary,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () =>
                                      Navigator.pushNamed(context, '/register'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // --- Divider ---
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text('หรือ'),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // --- Google Sign-in Button ---
                      Semantics(
                        button: true,
                        label: 'เข้าสู่ระบบด้วย Google',
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _loginWithGoogle,
                          icon: SvgPicture.asset('assets/icons/google.svg',
                              width: 22),
                          label: const Text('ดำเนินการต่อด้วย Google'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cs.onSurface,
                            side: BorderSide(color: Colors.black26),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- Guest Access Button ---
                      TextButton.icon(
                        onPressed: _isLoading ? null : _enterAsGuest,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('เข้าใช้งานโดยไม่ล็อกอิน'),
                        style: TextButton.styleFrom(
                          foregroundColor: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ★ Loading overlay กันกดซ้ำ/กดปุ่มอื่นตอนกำลังส่ง
            if (_isLoading)
              IgnorePointer(
                ignoring: true,
                child: Container(
                  color: Colors.black.withOpacity(.12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
