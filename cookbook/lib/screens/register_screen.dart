import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';

/// หน้า “สมัครสมาชิก” responsive
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // 1) Controllers สำหรับฟอร์ม
  final _userCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  // 2) GoogleSignIn (Web OAuth client ID)
  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', 'openid'],
    serverClientId: 'YOUR_GOOGLE_OAUTH_CLIENT_ID',
  );

  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _userCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  /// 3) สมัครด้วย Email/Password
  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final res = await ApiService.register(
        _emailCtrl.text.trim(),
        _passCtrl.text,
        _confirmCtrl.text,
      );
      if (res['success'] == true) {
        // ถ้าสมัครสำเร็จ → ไปหน้า Login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        setState(() => _errorMsg = res['message']);
      }
    } catch (e) {
      setState(() => _errorMsg = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 4) สมัคร/ล็อกอินด้วย Google
  Future<void> _registerWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        setState(() => _errorMsg = 'ยกเลิกการเข้าสู่ระบบด้วย Google');
        return;
      }
      final token = (await account.authentication).idToken;
      if (token == null) {
        setState(() => _errorMsg = 'ไม่สามารถดึง Google ID Token ได้');
        return;
      }
      final res = await ApiService.googleSignIn(token);
      if (res['success'] == true) {
        // เก็บสถานะและไปหน้า Home
        await SharedPreferences.getInstance()
            .then((p) => p.setBool('isLoggedIn', true));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        setState(() => _errorMsg = res['message']);
      }
    } catch (e) {
      setState(() => _errorMsg = 'ผิดพลาด: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      // พื้นหลังส้มเต็มจอ
      backgroundColor: const Color(0xFFFF6F2D),
      body: Column(
        children: [
          // ส่วนบน: กล่องขาวโค้ง responsive (สูง 85% ของหน้าจอ)
          Expanded(
            flex: 85,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(100),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width * 0.07, // 7% horizontal padding
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: size.height * 0.02), // 2% top spacing
                      // ไอคอนหัวข้อ (ขนาด responsive)
                      Center(
                        child: Image.asset(
                          'lib/assets/images/logo.png',
                          width: size.width * 0.33,
                          height: size.width * 0.29,
                        ),
                      ),
                      SizedBox(height: size.height * 0.02),
                      // หัวเรื่อง “สมัครสมาชิก”
                      const Center(
                        child: Text(
                          'สมัครสมาชิก',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 30,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF1D1D1F),
                            letterSpacing: 0.04,
                          ),
                        ),
                      ),
                      SizedBox(height: size.height * 0.04),

                      // Username
                      _buildField(
                        icon: Icons.person_outline,
                        hint: 'ชื่อผู้ใช้',
                        controller: _userCtrl,
                      ),
                      SizedBox(height: size.height * 0.03),

                      // Email
                      _buildField(
                        icon: Icons.email_outlined,
                        hint: 'อีเมล',
                        controller: _emailCtrl,
                      ),
                      SizedBox(height: size.height * 0.03),

                      // Password
                      _buildField(
                        icon: Icons.lock_outline,
                        hint: 'รหัสผ่าน',
                        obscure: true,
                        controller: _passCtrl,
                      ),
                      SizedBox(height: size.height * 0.03),

                      // Confirm Password
                      _buildField(
                        icon: Icons.lock_outline,
                        hint: 'ยืนยันรหัสผ่าน',
                        obscure: true,
                        controller: _confirmCtrl,
                      ),
                      SizedBox(height: size.height * 0.05),

                      // ข้อความ error ถ้ามี
                      if (_errorMsg != null) ...[
                        Text(
                          _errorMsg!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        SizedBox(height: size.height * 0.02),
                      ],

                      // ปุ่ม “สมัคร”
                      SizedBox(
                        height: size.height * 0.065, // 6.5% ของสูง
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromRGBO(255, 111, 45, 0.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(200)),
                            elevation: 4,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator()
                              : const Text(
                                  'สมัคร',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF000000),
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(height: size.height * 0.02),

                      // ลิงก์ “ย้อนกลับ”
                      Center(
                        child: Text.rich(
                          TextSpan(
                            text: '< ย้อนกลับ',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 17,
                              fontWeight: FontWeight.w400,
                              color: Colors.black.withOpacity(0.65),
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => Navigator.pop(context),
                          ),
                        ),
                      ),
                      SizedBox(height: size.height * 0.02),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ส่วนล่าง: เหลือที่ให้ background สีส้มโชว์ (15%)
          Expanded(flex: 15, child: const SizedBox()),
        ],
      ),
    );
  }

  /// สร้าง TextField แบบมี icon นำหน้า และเส้นใต้
  Widget _buildField({
    required IconData icon,
    required String hint,
    bool obscure = false,
    required TextEditingController controller,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.black.withOpacity(0.75)),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.black.withOpacity(0.7)),
        border: InputBorder.none,
        enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.black)),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.black, width: 2)),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}
