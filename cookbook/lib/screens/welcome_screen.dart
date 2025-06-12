// lib/screens/welcome_screen.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);
  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', 'openid'],
    serverClientId:
        '84901598956-dui13r3k1qmvo0t0kpj6h5mhjrjbvoln.apps.googleusercontent.com',
  );

  bool _isLoading = false;
  String? _errorMsg;

  Future<void> _registerWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        setState(() => _errorMsg = 'ยกเลิกการลงทะเบียนด้วย Google');
        return;
      }
      final token = (await account.authentication).idToken;
      if (token == null) {
        setState(() => _errorMsg = 'ไม่สามารถดึง Google ID Token ได้');
        return;
      }
      final result = await ApiService.googleSignIn(token);
      if (result['success'] == true) {
        // ─── แก้ไขตรงนี้ ───
        final data = result['data'] as Map<String, dynamic>? ?? {};

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        // เซฟชื่อผู้ใช้
        await prefs.setString('profileName', data['profile_name'] ?? '');
        // เซฟ URL รูปโปรไฟล์
        await prefs.setString('profileImage', data['path_imgProfile'] ?? '');
        // ────────────────────

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        setState(() => _errorMsg = result['message']);
      }
    } catch (e) {
      setState(() => _errorMsg = 'เกิดข้อผิดพลาด: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

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
              // LOGO
              Center(
                child: Image.asset(
                  'lib/assets/images/logo.png',
                  width: w * 0.4,
                  height: w * 0.4,
                ),
              ),
              const SizedBox(height: 24),

              // TITLE
              const Center(
                child: Text(
                  'เข้าร่วม',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const Center(
                child: Text(
                  'CookingBook',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // SUBTITLE
              const Text(
                '“ ลดขยะอาหาร สร้างคุณค่าจากวัตถุดิบที่มี ”',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'สมัครเพื่อบันทึกและแชร์สูตรอาหารในสไตล์คุณ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 32),

              // GOOGLE BUTTON
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _registerWithGoogle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF2F2F2),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset(
                              'lib/assets/icons/google.svg',
                              width: 24,
                              height: 24,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'ลงทะเบียนผ่าน Google',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // EMAIL BUTTON
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                  icon: const Icon(Icons.email_outlined, size: 24),
                  label: const Text(
                    'ลงทะเบียนด้วย email',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF2F2F2),
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ERROR MESSAGE
              if (_errorMsg != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMsg!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              // LOGIN LINK
              Center(
                child: RichText(
                  text: TextSpan(
                    text: 'มีบัญชีแล้วใช่ไหม? ',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                    children: [
                      TextSpan(
                        text: 'เข้าสู่ระบบเลย',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen()),
                            );
                          },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // DIVIDER
              const Divider(
                color: Color(0xFFCCCCCC),
                thickness: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
