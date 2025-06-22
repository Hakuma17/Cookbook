import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  /* ─────────── form & controller ─────────── */
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _hidePass = true;
  bool _hideConfirm = true;

  /* ─────────── state ─────────── */
  bool _isLoading = false;
  String? _errorMsg;

  /* ─────────── google sign-in ─────────── */
  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', 'openid'],
    // ใส่ client-id ของ Production เองนะ
    serverClientId: 'YOUR_GOOGLE_OAUTH_CLIENT_ID',
  );

  /* ─────────── dispose ─────────── */
  @override
  void dispose() {
    _userCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  /* ─────────── helper: email reg-exp ─────────── */
  final _emailReg = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$');

  /* ─────────── register (email / pass) ─────────── */
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('สมัครสมาชิกสำเร็จ! เข้าสู่ระบบเลย')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        setState(() => _errorMsg = res['message'] ?? 'เกิดข้อผิดพลาด');
      }
    } catch (_) {
      setState(() => _errorMsg = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /* ─────────── register / login ด้วย Google ─────────── */
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
        setState(() => _errorMsg = 'ไม่พบ Google ID Token');
        return;
      }

      final res = await ApiService.googleSignIn(token);
      if (res['success'] == true) {
        await AuthService.saveLoginData(res['data']);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        setState(() => _errorMsg = res['message'] ?? 'เกิดข้อผิดพลาด');
      }
    } catch (e) {
      setState(() => _errorMsg = 'ผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /* ─────────── build ─────────── */
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFFF6F2D),
      body: Column(
        children: [
          Expanded(
            flex: 85,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(100)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 4))
                ],
              ),
              width: double.infinity,
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                      horizontal: size.width * .07, vertical: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: size.height * .02),
                        Center(
                          child: Image.asset('assets/images/logo.png',
                              width: size.width * .33,
                              height: size.width * .29),
                        ),
                        SizedBox(height: size.height * .02),
                        const Center(
                          child: Text('สมัครสมาชิก',
                              style: TextStyle(
                                  fontSize: 30, color: Color(0xFF1D1D1F))),
                        ),
                        SizedBox(height: size.height * .04),

                        /* ─────── fields ─────── */
                        _buildTextField(
                          icon: Icons.person_outline,
                          hint: 'ชื่อผู้ใช้',
                          controller: _userCtrl,
                          validator: (v) =>
                              v!.trim().isEmpty ? 'กรุณากรอกชื่อผู้ใช้' : null,
                        ),
                        SizedBox(height: size.height * .03),
                        _buildTextField(
                          icon: Icons.email_outlined,
                          hint: 'อีเมล',
                          controller: _emailCtrl,
                          inputType: TextInputType.emailAddress,
                          validator: (v) => !_emailReg.hasMatch(v!.trim())
                              ? 'อีเมลไม่ถูกต้อง'
                              : null,
                        ),
                        SizedBox(height: size.height * .03),
                        _buildTextField(
                          icon: Icons.lock_outline,
                          hint: 'รหัสผ่าน (อย่างน้อย 6 ตัว)',
                          controller: _passCtrl,
                          obscure: _hidePass,
                          suffixIcon: IconButton(
                            icon: Icon(_hidePass
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () =>
                                setState(() => _hidePass = !_hidePass),
                          ),
                          validator: (v) => v!.length < 6
                              ? 'ใช้รหัสผ่านอย่างน้อย 6 ตัว'
                              : null,
                        ),
                        SizedBox(height: size.height * .03),
                        _buildTextField(
                          icon: Icons.lock_outline,
                          hint: 'ยืนยันรหัสผ่าน',
                          controller: _confirmCtrl,
                          obscure: _hideConfirm,
                          suffixIcon: IconButton(
                            icon: Icon(_hideConfirm
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () =>
                                setState(() => _hideConfirm = !_hideConfirm),
                          ),
                          validator: (v) =>
                              v != _passCtrl.text ? 'รหัสผ่านไม่ตรงกัน' : null,
                        ),
                        SizedBox(height: size.height * .05),

                        /* ─────── error ─────── */
                        if (_errorMsg != null) ...[
                          Text(_errorMsg!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red)),
                          SizedBox(height: size.height * .02),
                        ],

                        /* ─────── register btn ─────── */
                        SizedBox(
                          height: size.height * .065,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFA77E),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(200)),
                              elevation: 4,
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator()
                                : const Text('สมัคร',
                                    style: TextStyle(
                                        fontSize: 20, color: Colors.black)),
                          ),
                        ),
                        SizedBox(height: size.height * .02),

                        /* ─────── google btn ─────── */
                        SizedBox(
                          height: size.height * .058,
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _registerWithGoogle,
                            icon: Image.asset('assets/icons/google.png',
                                width: 24),
                            label: const Text('สมัครด้วย Google',
                                style: TextStyle(fontSize: 16)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black87,
                              side: const BorderSide(color: Colors.black26),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(200)),
                            ),
                          ),
                        ),
                        SizedBox(height: size.height * .04),

                        /* ─────── back link ─────── */
                        Center(
                          child: Text.rich(
                            TextSpan(
                              text: '< ย้อนกลับ',
                              style: TextStyle(
                                  color: Colors.black.withOpacity(.65),
                                  fontSize: 17),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => Navigator.pop(context),
                            ),
                          ),
                        ),
                        SizedBox(height: size.height * .02),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(flex: 15, child: const SizedBox()),
        ],
      ),
    );
  }

  /* ─────────── reusable field ─────────── */
  Widget _buildTextField({
    required IconData icon,
    required String hint,
    required TextEditingController controller,
    bool obscure = false,
    TextInputType inputType = TextInputType.text,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: inputType,
      validator: validator,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.black.withOpacity(.75)),
        suffixIcon: suffixIcon,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.black.withOpacity(.7)),
        border: InputBorder.none,
        enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.black)),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.black, width: 2)),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}
