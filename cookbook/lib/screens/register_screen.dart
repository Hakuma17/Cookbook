// lib/screens/register_screen.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'verify_otp_screen.dart'; // ← NEW
// import 'login_screen.dart';           // ไม่ใช้แล้ว

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

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

        // ✅ ไปหน้า Verify OTP พร้อมอีเมลที่เพิ่งสมัคร
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyOtpScreen(email: _emailCtrl.text.trim()),
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('สมัครสำเร็จ – กรุณายืนยันอีเมลด้วย OTP'),
          ),
        );
      } else {
        final errs = res['errors'];
        setState(() => _errorMsg = errs is List
            ? errs.join('\n')
            : (res['message'] ?? 'เกิดข้อผิดพลาด'));
      }
    } catch (_) {
      setState(() => _errorMsg = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /* ─────────── Helper (clamp) ─────────── */
  double _cp(double v, double min, double max) => v.clamp(min, max).toDouble();

  /* ─────────── Build UI ─────────── */
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    final inset = mq.viewInsets.bottom;

    // responsive metrics (clamped)
    final padH = _cp(w * .07, 16, 32);
    final padV = _cp(h * .03, 16, 40);
    final spaceXS = _cp(h * .02, 10, 24);
    final spaceS = _cp(h * .03, 16, 32);
    final spaceM = _cp(h * .04, 22, 40);
    final fieldSpace = _cp(h * .025, 14, 28);
    final btnHeight = _cp(h * .07, 46, 64);
    final logoWidth = _cp(w * .33, 120, 220);
    final titleFont = _cp(w * .075, 24, 32);
    final btnFont = _cp(w * .053, 16, 22);
    final linkFont = _cp(w * .046, 14, 18);
    final borderRad = _cp(12, 10, 16);
    final cardRadius = _cp(w * .25, 80, 160); // โค้งล่างของ card

    return Scaffold(
      backgroundColor: const Color(0xFFFCC09C),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          /*──── พื้นหลังส้มอ่อน ────*/
          Positioned.fill(child: Container(color: const Color(0xFFFCC09C))),

          /*──── Card ขาว ────*/
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(cardRadius)),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (_, constraints) {
                      return SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                            padH, padV, padH, padV + inset + spaceS),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              minHeight: constraints.maxHeight - spaceS),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    width: logoWidth,
                                  ),
                                ),
                                SizedBox(height: spaceXS),
                                Center(
                                  child: Text(
                                    'สมัครสมาชิก',
                                    style: TextStyle(
                                      fontSize: titleFont,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                SizedBox(height: spaceM),

                                /*── ชื่อผู้ใช้ ─*/
                                _buildTextField(
                                  icon: Icons.person_outline,
                                  hint: 'ชื่อผู้ใช้',
                                  controller: _userCtrl,
                                  validator: (v) => v!.trim().isEmpty
                                      ? 'กรุณากรอกชื่อผู้ใช้'
                                      : null,
                                  radius: borderRad,
                                ),
                                SizedBox(height: fieldSpace),

                                /*── อีเมล ─*/
                                _buildTextField(
                                  icon: Icons.email_outlined,
                                  hint: 'อีเมล',
                                  controller: _emailCtrl,
                                  inputType: TextInputType.emailAddress,
                                  validator: (v) =>
                                      !_emailReg.hasMatch(v!.trim())
                                          ? 'อีเมลไม่ถูกต้อง'
                                          : null,
                                  radius: borderRad,
                                ),
                                SizedBox(height: fieldSpace),

                                /*── รหัสผ่าน ─*/
                                _buildTextField(
                                  icon: Icons.lock_outline,
                                  hint: 'รหัสผ่าน (อย่างน้อย 8 ตัว)',
                                  controller: _passCtrl,
                                  obscure: _hidePass,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _hidePass
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: Colors.black54,
                                    ),
                                    onPressed: () =>
                                        setState(() => _hidePass = !_hidePass),
                                  ),
                                  validator: (v) => v!.length < 8
                                      ? 'ใช้รหัสผ่านอย่างน้อย 8 ตัว'
                                      : null,
                                  radius: borderRad,
                                ),
                                SizedBox(height: fieldSpace),

                                /*── ยืนยันรหัสผ่าน ─*/
                                _buildTextField(
                                  icon: Icons.lock_outline,
                                  hint: 'ยืนยันรหัสผ่าน',
                                  controller: _confirmCtrl,
                                  obscure: _hideConfirm,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _hideConfirm
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: Colors.black54,
                                    ),
                                    onPressed: () => setState(
                                        () => _hideConfirm = !_hideConfirm),
                                  ),
                                  validator: (v) => v != _passCtrl.text
                                      ? 'รหัสผ่านไม่ตรงกัน'
                                      : null,
                                  radius: borderRad,
                                ),
                                SizedBox(height: spaceS),
                                if (_errorMsg != null) ...[
                                  Text(
                                    _errorMsg!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      height: 1.4,
                                    ),
                                  ),
                                  SizedBox(height: spaceXS),
                                ],

                                /*── ปุ่มสมัคร ─*/
                                SizedBox(
                                  height: btnHeight,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _register,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFCC09C),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(200),
                                      ),
                                      elevation: 4,
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.3,
                                            ),
                                          )
                                        : Text(
                                            'สมัคร',
                                            style: TextStyle(
                                              fontSize: btnFont,
                                              color: Colors.black87,
                                            ),
                                          ),
                                  ),
                                ),
                                SizedBox(height: spaceXS),

                                /*── ลิงก์ย้อนกลับ ─*/
                                Center(
                                  child: Text.rich(
                                    TextSpan(
                                      text: '< ย้อนกลับ',
                                      style: TextStyle(
                                        color: Colors.black.withOpacity(.65),
                                        fontSize: linkFont,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () => Navigator.pop(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /* ─────────── Input Field Generator ─────────── */
  Widget _buildTextField({
    required IconData icon,
    required String hint,
    required TextEditingController controller,
    bool obscure = false,
    TextInputType inputType = TextInputType.text,
    Widget? suffixIcon,
    double radius = 12,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: inputType,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey.shade50,
        prefixIcon: Icon(icon, color: Colors.black54),
        suffixIcon: suffixIcon,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: Colors.grey.shade500, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        errorStyle: const TextStyle(height: 1.2),
      ),
    );
  }
}
