import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('สมัครสมาชิกสำเร็จ! เข้าสู่ระบบเลย')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        final errs = res['errors'];
        if (errs is List) {
          setState(() => _errorMsg = errs.join('\n'));
        } else {
          setState(() => _errorMsg = res['message'] ?? 'เกิดข้อผิดพลาด');
        }
      }
    } catch (_) {
      setState(() => _errorMsg = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /* ─────────── Build UI ─────────── */
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFFCC09C),
      resizeToAvoidBottomInset: false,
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
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 4))
                ],
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    size.width * .07,
                    24,
                    size.width * .07,
                    24 + bottomInset,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // โลโก้
                        Center(
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: size.width * .33,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // หัวเรื่อง
                        const Center(
                          child: Text(
                            'สมัครสมาชิก',
                            style: TextStyle(
                                fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ─────── ชื่อผู้ใช้ ───────
                        _buildTextField(
                          icon: Icons.person_outline,
                          hint: 'ชื่อผู้ใช้',
                          controller: _userCtrl,
                          validator: (v) =>
                              v!.trim().isEmpty ? 'กรุณากรอกชื่อผู้ใช้' : null,
                        ),
                        const SizedBox(height: 20),

                        // ─────── อีเมล ───────
                        _buildTextField(
                          icon: Icons.email_outlined,
                          hint: 'อีเมล',
                          controller: _emailCtrl,
                          inputType: TextInputType.emailAddress,
                          validator: (v) => !_emailReg.hasMatch(v!.trim())
                              ? 'อีเมลไม่ถูกต้อง'
                              : null,
                        ),
                        const SizedBox(height: 20),

                        // ─────── รหัสผ่าน ───────
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
                        ),
                        const SizedBox(height: 20),

                        // ─────── ยืนยันรหัสผ่าน ───────
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
                            onPressed: () =>
                                setState(() => _hideConfirm = !_hideConfirm),
                          ),
                          validator: (v) =>
                              v != _passCtrl.text ? 'รหัสผ่านไม่ตรงกัน' : null,
                        ),
                        const SizedBox(height: 24),
                        if (_errorMsg != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _errorMsg!,
                              style: const TextStyle(
                                  color: Colors.red, height: 1.4),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFCC09C),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(200),
                              ),
                              elevation: 4,
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator()
                                : const Text(
                                    'สมัคร',
                                    style: TextStyle(
                                        fontSize: 20, color: Colors.black87),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ─────── ลิงก์ย้อนกลับ ───────
                        Center(
                          child: Text.rich(
                            TextSpan(
                              text: '< ย้อนกลับ',
                              style: TextStyle(
                                color: Colors.black.withOpacity(.65),
                                fontSize: 17,
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
              ),
            ),
          ),

          // ─────── Footer (ตกแต่งล่าง) ───────
          const Expanded(flex: 15, child: SizedBox()),
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
        hintStyle: TextStyle(color: Colors.black45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade500, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        errorStyle: const TextStyle(height: 1.2),
      ),
    );
  }
}
