import 'dart:async';
import 'dart:io';

import 'package:cookbook/services/api_service.dart';
import 'package:cookbook/services/auth_service.dart';
import 'package:flutter/material.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

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

  /* ───────────────── helper ───────────────── */
  void _showSnack(String msg, {Color color = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AuthService.checkAndRedirectIfLoggedOut(context),
    );
  }

  @override
  void dispose() {
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  /* ───────────────── main action ───────────────── */
  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final res = await ApiService.changePassword(
              _oldPassCtrl.text.trim(), _newPassCtrl.text.trim())
          .timeout(const Duration(seconds: 15));

      if (!(mounted)) return;
      setState(() => _loading = false);

      if (res['success'] == true) {
        _oldPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
        _showSnack('เปลี่ยนรหัสผ่านเรียบร้อยแล้ว', color: Colors.green);
      } else {
        _showSnack(res['message'] ?? 'เกิดข้อผิดพลาด');
      }
    } on TimeoutException {
      _showSnack('เซิร์ฟเวอร์ตอบช้า ลองใหม่ภายหลัง');
    } on SocketException {
      _showSnack('ไม่มีการเชื่อมต่ออินเทอร์เน็ต');
    } catch (e) {
      _showSnack('ผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /* ───────────────── widget helper ───────────────── */
  Widget _passField({
    required String label,
    required TextEditingController ctrl,
    required bool obscure,
    required VoidCallback toggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          obscureText: obscure,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: toggle,
            ),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'กรุณากรอกรหัสผ่าน';
            if (v.trim().length < 6) return 'อย่างน้อย 6 ตัวอักษร';
            return null;
          },
        ),
      ],
    );
  }

  /* ───────────────── build ───────────────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('เปลี่ยนรหัสผ่าน'), centerTitle: true),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _passField(
                label: 'รหัสผ่านปัจจุบัน',
                ctrl: _oldPassCtrl,
                obscure: _obscureOld,
                toggle: () => setState(() => _obscureOld = !_obscureOld),
              ),
              const SizedBox(height: 20),
              _passField(
                label: 'รหัสผ่านใหม่',
                ctrl: _newPassCtrl,
                obscure: _obscureNew,
                toggle: () => setState(() => _obscureNew = !_obscureNew),
              ),
              const SizedBox(height: 20),
              _passField(
                label: 'ยืนยันรหัสผ่านใหม่',
                ctrl: _confirmPassCtrl,
                obscure: _obscureConfirm,
                toggle: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _changePassword,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('ยืนยันการเปลี่ยนรหัสผ่าน'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
