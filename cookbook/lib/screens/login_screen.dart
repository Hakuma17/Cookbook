// lib/screens/login_screen.dart
import 'dart:async';
// import 'dart.io'; // 🗑️ ลบออก ไม่ได้ใช้แล้ว

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
// import 'home_screen.dart'; // 🗑️ ลบออก เพราะจะใช้ Named Routes
// import 'register_screen.dart';
// import 'reset_password_screen.dart';

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
  final _emailReg = RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-zA-Z]+$');

  /* ── google ────────────────────────────────────────────────────── */
  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', 'openid'],
    // serverClientId ควรเก็บไว้ใน environment variables เพื่อความปลอดภัย
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
  /// ✅ 1. ปรับปรุงการนำทางให้ใช้ Named Routes และคืนค่าผลลัพธ์
  void _navToHome() {
    // ใช้ pushReplacementNamed เพื่อไม่ให้ผู้ใช้กด back กลับมาหน้า login ได้
    // และส่ง true กลับไปเผื่อกรณีที่ถูกเรียกจากหน้าอื่น
    Navigator.of(context).pushReplacementNamed('/home', result: true);
  }

  /* ── actions ──────────────────────────────────────────────────── */
  Future<void> _enterAsGuest() async {
    // เคลียร์ข้อมูลผู้ใช้เก่า (ถ้ามี) ก่อนเข้าสู่ระบบในฐานะ Guest
    await AuthService.logout();
    _navToHome();
  }

  /// ✅ 2. ปรับปรุง Error Handling ให้รองรับ Custom Exception
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
      );

      if (res['success'] != true) {
        setState(
            () => _errorMsg = res['message'] ?? 'รหัสผ่านหรืออีเมลไม่ถูกต้อง');
        return;
      }
      // ApiService._captureCookie ได้บันทึก Session Token ให้แล้ว
      // เราแค่ต้องบันทึกข้อมูลโปรไฟล์ของผู้ใช้
      await AuthService.saveLoginData(res['data']);
      _navToHome();
    } on ApiException catch (e) {
      setState(() => _errorMsg = e.message);
    } catch (e) {
      setState(() => _errorMsg = 'เกิดข้อผิดพลาดที่ไม่รู้จัก');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      // บังคับให้ re-authenticate ทุกครั้งเพื่อความปลอดภัย
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }

      final account = await _googleSignIn.signIn();
      if (account == null) {
        // ผู้ใช้กดยกเลิก
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final token = (await account.authentication).idToken;
      if (token == null) throw Exception('ไม่สามารถดึง Google ID Token ได้');

      final res = await ApiService.googleSignIn(token);

      if (res['success'] != true) {
        setState(() =>
            _errorMsg = res['message'] ?? 'ไม่สามารถล็อกอินด้วย Google ได้');
        return;
      }

      await AuthService.saveLoginData(res['data']);
      _navToHome();
    } on ApiException catch (e) {
      setState(() => _errorMsg = e.message);
      await _googleSignIn.signOut(); // เคลียร์สถานะเดิม
    } catch (e) {
      setState(() => _errorMsg = 'เกิดข้อผิดพลาดในการล็อกอินด้วย Google');
      await _googleSignIn.signOut();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /* ── build ────────────────────────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    // ✅ 3. ลบ Manual Responsive Calculation ทั้งหมด และใช้ Theme แทน
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Form(
              key: _formKey,
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
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'อีเมล'),
                    validator: (v) {
                      final text = v?.trim() ?? '';
                      if (text.isEmpty) return 'กรุณากรอกอีเมล';
                      if (!_emailReg.hasMatch(text))
                        return 'รูปแบบอีเมลไม่ถูกต้อง';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // --- Password Field ---
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'รหัสผ่าน'),
                    validator: (v) {
                      final text = v ?? '';
                      if (text.isEmpty) return 'กรุณากรอกรหัสผ่าน';
                      if (text.length < 6)
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
                          : () =>
                              Navigator.pushNamed(context, '/reset_password'),
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
                        style: TextStyle(color: colorScheme.error),
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
                                color: Colors.white, strokeWidth: 3),
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
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                        children: [
                          TextSpan(
                            text: 'สมัครสมาชิกเลย!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                              color: colorScheme.primary,
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
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _loginWithGoogle,
                    icon:
                        SvgPicture.asset('assets/icons/google.svg', width: 22),
                    label: const Text('ดำเนินการต่อด้วย Google'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.onSurface,
                      side: BorderSide(
                          color: isDark ? Colors.white54 : Colors.black26),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- Guest Access Button ---
                  TextButton.icon(
                    onPressed: _isLoading ? null : _enterAsGuest,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('เข้าใช้งานโดยไม่ล็อกอิน'),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onSurfaceVariant,
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
