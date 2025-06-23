import 'dart:async';
import 'package:cookbook/services/auth_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/api_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  // ─────────────────── Google Sign-In client ────────────────────
  final _google = GoogleSignIn(
    scopes: ['email', 'profile', 'openid'],
    serverClientId:
        '84901598956-dui13r3k1qmvo0t0kpj6h5mhjrjbvoln.apps.googleusercontent.com',
  );

  bool _signing = false; // true ระหว่าง sign-in
  String? _error; // ข้อผิดพลาดล่าสุด
  StreamSubscription? _sub; // listen onCurrentUserChanged

  @override
  void initState() {
    super.initState();
    // ถ้าผู้ใช้ sign-in เสร็จ แต่ app ถูก kill mid-way → callback นี้รับต่อ
    _sub = _google.onCurrentUserChanged.listen((acc) {
      if (acc != null && _signing) _finishGoogleFlow(acc);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /*──────────────────── Google Sign-In Flow ────────────────────*/
  Future<void> _startGoogleFlow() async {
    if (_signing) return; // กันกดรัว
    setState(() => _signing = true);

    try {
      // เคลียร์ session เดิมก่อนทุกครั้ง เพื่อให้ signIn() ครั้งถัดไปไม่ติด session เก่า
      await _google.signOut();

      // signIn() อาจ throw หรือคืน null หากยกเลิก
      final account = await _google.signIn();
      if (account == null) {
        throw Exception('ยกเลิกการลงทะเบียนด้วย Google');
      }
      await _finishGoogleFlow(account);
    } on Exception catch (e) {
      _showErr(e.toString());
    } finally {
      if (mounted) setState(() => _signing = false);
    }
  }

  Future<void> _finishGoogleFlow(GoogleSignInAccount account) async {
    try {
      final auth =
          await account.authentication.timeout(const Duration(seconds: 10));
      final idToken = auth.idToken;
      if (idToken == null) {
        throw Exception('ไม่สามารถดึง Google ID Token ได้');
      }

      final res = await ApiService.googleSignIn(idToken)
          .timeout(const Duration(seconds: 10));
      await AuthService.saveLoginData(res['data'] as Map<String, dynamic>);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on TimeoutException {
      _showErr('การเชื่อมต่อช้า กรุณาลองใหม่');
    } on Exception catch (e) {
      _showErr(e.toString().replaceFirst('Exception: ', ''));
      await _google.signOut(); // เคลียร์ session เผื่อซ้ำ
    }
  }

  void _showErr(String msg) {
    if (!mounted) return;
    setState(() => _error = msg);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  /*──────────────────── UI ────────────────────*/
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image.asset('assets/images/logo.png',
                    width: w * 0.4, height: w * 0.4),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text('เข้าร่วม',
                    style:
                        TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              ),
              const Center(
                  child: Text('CookingBook',
                      style: TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold))),
              const SizedBox(height: 16),
              const Text('“ ลดขยะอาหาร สร้างคุณค่าจากวัตถุดิบที่มี ”',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
              const Text('สมัครเพื่อบันทึกและแชร์สูตรอาหารในสไตล์คุณ',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
              const SizedBox(height: 32),

              /*────────── Google Sign-Up ──────────*/
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _signing ? null : _startGoogleFlow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF2F2F2),
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _signing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 3))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          SvgPicture.asset('assets/icons/google.svg',
                              width: 24, height: 24),
                          const SizedBox(width: 12),
                          const Text('ลงทะเบียนผ่าน Google',
                              style: TextStyle(fontSize: 16)),
                        ]),
                ),
              ),
              const SizedBox(height: 16),

              /*────────── Email Sign-Up ──────────*/
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _signing
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RegisterScreen())),
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('ลงทะเบียนด้วย email',
                      style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF2F2F2),
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(height: 32),

              /*────────── Login link ──────────*/
              Center(
                child: RichText(
                  text: TextSpan(
                    text: 'มีบัญชีแล้ว? ',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                    children: [
                      TextSpan(
                        text: 'เข้าสู่ระบบเลย',
                        style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen())),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              /*────────── Guest Access ──────────*/
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
              const SizedBox(height: 32),
              if (_error != null) ...[
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
              ],
              const Divider(color: Color(0xFFCCCCCC), thickness: 1),
            ],
          ),
        ),
      ),
    );
  }
}
