// lib/screens/login_screen.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'reset_password_screen.dart';

/// หน้า Login: ล็อกอินด้วย Email/Password หรือ Google
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers เก็บค่า Email + Password
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  // GoogleSignIn พร้อม Web OAuth Client ID
  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', 'openid'],
    serverClientId:
        '84901598956-dui13r3k1qmvo0t0kpj6h5mhjrjbvoln.apps.googleusercontent.com',
  );

  bool _isLoading = false; // สถานะกำลังโหลด
  String? _errorMsg; // ข้อความแสดงข้อผิดพลาด

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  /// ฟังก์ชันล็อกอินด้วย Email/Password
  Future<void> _loginWithEmail() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _errorMsg = 'กรุณากรอกอีเมลและรหัสผ่านให้ครบ');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final result = await ApiService.login(email, pass);
      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>? ?? {};

        // บันทึกสถานะและข้อมูลโปรไฟล์
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('profileName', data['profile_name'] ?? '');
        await prefs.setString('profileImage', data['path_imgProfile'] ?? '');
        await prefs.reload();

        // นำทางไป HomeScreen
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

  /// ฟังก์ชันล็อกอินด้วย Google
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        setState(() => _errorMsg = 'ยกเลิกการล็อกอินด้วย Google');
      } else {
        final token = (await account.authentication).idToken;
        if (token == null) {
          setState(() => _errorMsg = 'ไม่สามารถดึง Google ID Token ได้');
        } else {
          final result = await ApiService.googleSignIn(token);
          if (result['success'] == true) {
            final data = result['data'] as Map<String, dynamic>? ?? {};

            // บันทึกสถานะและข้อมูลโปรไฟล์
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('isLoggedIn', true);
            await prefs.setString('profileName', data['profile_name'] ?? '');
            await prefs.setString(
                'profileImage', data['path_imgProfile'] ?? '');

            // นำทางไป HomeScreen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          } else {
            setState(() => _errorMsg = result['message']);
          }
        }
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
              const SizedBox(height: 40),

              // โลโก้แอปกึ่งกลาง ขนาด 30% ของความกว้าง
              Center(
                child: Image.asset(
                  'lib/assets/images/logo.png',
                  width: w * 0.3,
                  height: w * 0.3,
                ),
              ),
              const SizedBox(height: 16),

              // หัวเรื่อง “Cooking Guide”
              const Center(
                child: Text(
                  'Cooking Guide',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // ช่องกรอกอีเมล
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Color(0xFFF2F2F2),
                  hintText: 'อีเมล',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ช่องกรอกรหัสผ่าน
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Color(0xFFF2F2F2),
                  hintText: 'รหัสผ่าน',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              // ลิงก์ “ลืมรหัสผ่าน”
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ResetPasswordScreen()),
                    );
                  },
                  child: const Text(
                    'ลืมรหัสผ่าน',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ปุ่ม “ลงชื่อเข้าใช้” (Email)
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
              const SizedBox(height: 16),

              // ข้อความแสดงข้อผิดพลาด
              if (_errorMsg != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _errorMsg!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              const SizedBox(height: 16),

              // ลิงก์ “สมัครสมาชิก” สำหรับผู้ไม่มีบัญชี
              Center(
                child: RichText(
                  text: TextSpan(
                    text: 'ยังไม่มีบัญชีใช่ไหม? ',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                    children: [
                      TextSpan(
                        text: 'สมัครสมาชิกเลย!',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.bold,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const RegisterScreen()),
                            );
                          },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ปุ่ม “ดำเนินการต่อด้วย Google”
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
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
                              'ดำเนินการต่อด้วย Google',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF1D1D1F),
                              ),
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
