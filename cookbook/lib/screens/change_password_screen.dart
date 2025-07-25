// lib/screens/change_password_screen.dart

import 'dart:async';
// import 'dart:io'; // 🗑️ ลบออก ไม่ได้ใช้แล้ว

import 'package:cookbook/services/api_service.dart';
import 'package:cookbook/services/auth_service.dart';
import 'package:flutter/material.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // ❌ 1. ลบการเช็คสิทธิ์ออกจาก initState
    // การป้องกัน Route ควรทำที่ระดับ Router (เช่น ใช้ AuthGuard) ไม่ใช่ในหน้าจอเอง
    // WidgetsBinding.instance.addPostFrameCallback(
    //   (_) => AuthService.checkAndRedirectIfLoggedOut(context),
    // );
  }

  @override
  void dispose() {
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  /* ───────────────── helper ───────────────── */
  void _showSnack(String msg, {bool isError = true}) {
    if (!mounted) return;
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? theme.colorScheme.error : Colors.green.shade600,
    ));
  }

  Future<void> _handleLogout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  /* ───────────────── main action ───────────────── */
  /// ✅ 2. ปรับปรุง Error Handling ให้รองรับ Custom Exception
  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_newPassCtrl.text.trim() != _confirmPassCtrl.text.trim()) {
      _showSnack('รหัสผ่านใหม่กับยืนยันไม่ตรงกัน');
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await ApiService.changePassword(
        _oldPassCtrl.text.trim(),
        _newPassCtrl.text.trim(),
      );

      if (res['success'] == true) {
        _oldPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
        _showSnack('เปลี่ยนรหัสผ่านเรียบร้อยแล้ว', isError: false);
        // อาจจะ pop กลับไปหน้าก่อนหน้า
        if (mounted) Navigator.of(context).pop();
      } else {
        _showSnack(res['message'] ?? 'เกิดข้อผิดพลาด');
      }
    } on UnauthorizedException catch (e) {
      _showSnack(e.message);
      _handleLogout(); // Session หมดอายุ, บังคับ Logout
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('เกิดข้อผิดพลาดที่ไม่รู้จัก: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /* ───────────────── build ───────────────── */
  @override
  Widget build(BuildContext context) {
    // ✅ 3. ลบการคำนวณ Responsive ทั้งหมด และใช้ Theme แทน
    return Scaffold(
      appBar: AppBar(
        title: const Text('เปลี่ยนรหัสผ่าน'),
        // centerTitle: true, // ถูกกำหนดใน Theme หลักแล้ว
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch, // ทำให้ปุ่มยืดเต็มความกว้าง
            children: [
              _PasswordTextField(
                // ✅ 4. ใช้ Widget ที่ Refactor แล้ว
                label: 'รหัสผ่านปัจจุบัน',
                controller: _oldPassCtrl,
                obscureText: _obscureOld,
                onToggleObscure: () =>
                    setState(() => _obscureOld = !_obscureOld),
              ),
              const SizedBox(height: 20),
              _PasswordTextField(
                label: 'รหัสผ่านใหม่',
                controller: _newPassCtrl,
                obscureText: _obscureNew,
                onToggleObscure: () =>
                    setState(() => _obscureNew = !_obscureNew),
              ),
              const SizedBox(height: 20),
              _PasswordTextField(
                label: 'ยืนยันรหัสผ่านใหม่',
                controller: _confirmPassCtrl,
                obscureText: _obscureConfirm,
                onToggleObscure: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _changePassword,
                child: _loading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 3),
                      )
                    : const Text('ยืนยันการเปลี่ยนรหัสผ่าน'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ✅ 5. แยก Password Field ออกมาเป็น Widget ของตัวเองเพื่อความสะอาด
/// Widget นี้จะดึงสไตล์จาก Theme โดยตรง ทำให้โค้ดเรียกใช้สั้นและสะอาด
class _PasswordTextField extends StatelessWidget {
  const _PasswordTextField({
    required this.label,
    required this.controller,
    required this.obscureText,
    required this.onToggleObscure,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final VoidCallback onToggleObscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            // ไม่ต้องกำหนด Border, Padding, หรือ FillColor เพราะ Theme หลักจัดการให้แล้ว
            suffixIcon: IconButton(
              icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
              onPressed: onToggleObscure,
            ),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'กรุณากรอกรหัสผ่าน';
            if (v.trim().length < 6)
              return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
            return null;
          },
        ),
      ],
    );
  }
}
