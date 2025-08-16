// lib/screens/change_password_screen.dart

import 'package:cookbook/services/api_service.dart';
import 'package:cookbook/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // haptics

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

  // focus
  final _oldFocus = FocusNode();
  final _newFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  // ★ Realtime: คอยฟังการพิมพ์รหัสใหม่แล้ว setState เพื่ออัปเดตแถบ
  void _onNewPassChanged() {
    if (mounted) setState(() {});
  }

  // ความแข็งแรง 0..1
  double get _strength => _calcStrength(_newPassCtrl.text);

  @override
  void initState() {
    super.initState();
    _newPassCtrl.addListener(_onNewPassChanged); // ★ realtime meter
  }

  @override
  void dispose() {
    _oldPassCtrl.dispose();
    _newPassCtrl.removeListener(_onNewPassChanged); // ★ cleanup
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _oldFocus.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  /* ───────────────── helper ───────────────── */
  void _showSnack(String msg, {bool isError = true}) {
    if (!mounted) return;
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
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

  // ประเมินความแข็งแรง (0..1) : ยาว/ตัวใหญ่/ตัวเล็ก/ตัวเลข/พิเศษ
  double _calcStrength(String p) {
    if (p.isEmpty) return 0.0;
    int score = 0;
    if (p.length >= 8) score++;
    if (p.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(p)) score++;
    if (RegExp(r'[a-z]').hasMatch(p)) score++;
    if (RegExp(r'\d').hasMatch(p)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-\\/\[\]=+;]').hasMatch(p)) score++;
    return (score / 6).clamp(0.0, 1.0);
  }

  // แปลงค่า strength → label/สี (ไว้ใช้ซ้ำ)
  (String label, Color color) _strengthInfo(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = _strength;
    if (s >= 0.75) return ('แข็งแรง', cs.primary);
    if (s >= 0.50) return ('ปานกลาง', Colors.orange);
    if (s > 0.0) return ('อ่อน', cs.error);
    return ('—', cs.surfaceVariant);
  }

  String? _validateNewPassword(String? v) {
    final p = (v ?? '').trim();
    if (p.isEmpty) return 'กรุณากรอกรหัสผ่าน';
    if (p.length < 8) return 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร';
    if (!RegExp(r'(?=.*[A-Za-z])(?=.*\d)').hasMatch(p)) {
      return 'ต้องมีทั้งตัวอักษรและตัวเลขอย่างน้อยอย่างละ 1';
    }
    if (_oldPassCtrl.text.trim().isNotEmpty && p == _oldPassCtrl.text.trim()) {
      return 'รหัสผ่านใหม่ต้องไม่เหมือนรหัสผ่านเดิม';
    }
    return null;
  }

  /* ───────────────── main action ───────────────── */
  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_newPassCtrl.text.trim() != _confirmPassCtrl.text.trim()) {
      _showSnack('รหัสผ่านใหม่กับยืนยันไม่ตรงกัน');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _loading = true);
    try {
      final res = await ApiService.changePassword(
        _oldPassCtrl.text.trim(),
        _newPassCtrl.text.trim(),
      );

      if (res['success'] == true) {
        HapticFeedback.lightImpact();
        _oldPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
        _showSnack('เปลี่ยนรหัสผ่านเรียบร้อยแล้ว', isError: false);
        if (mounted) Navigator.of(context).pop();
      } else {
        _showSnack(res['message'] ?? 'เกิดข้อผิดพลาด');
      }
    } on UnauthorizedException catch (e) {
      _showSnack(e.message);
      _handleLogout();
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
    final (label, color) = _strengthInfo(context);

    return Scaffold(
      appBar: AppBar(title: const Text('เปลี่ยนรหัสผ่าน')),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PasswordTextField(
                  label: 'รหัสผ่านปัจจุบัน',
                  controller: _oldPassCtrl,
                  obscureText: _obscureOld,
                  onToggleObscure: () =>
                      setState(() => _obscureOld = !_obscureOld),
                  focusNode: _oldFocus,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _newFocus.requestFocus(),
                  autofillHints: const [AutofillHints.password],
                ),
                const SizedBox(height: 20),
                _PasswordTextField(
                  label: 'รหัสผ่านใหม่',
                  controller: _newPassCtrl,
                  obscureText: _obscureNew,
                  onToggleObscure: () =>
                      setState(() => _obscureNew = !_obscureNew),
                  focusNode: _newFocus,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _confirmFocus.requestFocus(),
                  autofillHints: const [AutofillHints.newPassword],
                  validatorOverride: _validateNewPassword,
                ),
                const SizedBox(height: 10),

                // ★ Realtime strength meter
                _PasswordStrengthBar(
                  strength: _strength,
                  label: label,
                  color: color,
                ),

                const SizedBox(height: 20),
                _PasswordTextField(
                  label: 'ยืนยันรหัสผ่านใหม่',
                  controller: _confirmPassCtrl,
                  obscureText: _obscureConfirm,
                  onToggleObscure: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  focusNode: _confirmFocus,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _loading ? null : _changePassword(),
                  autofillHints: const [AutofillHints.newPassword],
                  validatorOverride: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'กรุณากรอกยืนยันรหัสผ่าน';
                    if (t != _newPassCtrl.text.trim()) {
                      return 'ยืนยันรหัสผ่านไม่ตรงกัน';
                    }
                    return null;
                  },
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
      ),
    );
  }
}

/// TextField สำหรับรหัสผ่าน
class _PasswordTextField extends StatelessWidget {
  const _PasswordTextField({
    required this.label,
    required this.controller,
    required this.obscureText,
    required this.onToggleObscure,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.validatorOverride,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final VoidCallback onToggleObscure;

  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final List<String>? autofillHints;
  final String? Function(String?)? validatorOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txt = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: txt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          keyboardType: TextInputType.visiblePassword,
          autofillHints: autofillHints,
          obscureText: obscureText,
          obscuringCharacter: '•',
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          smartDashesType: SmartDashesType.disabled,
          smartQuotesType: SmartQuotesType.disabled,
          style: txt.bodyLarge,
          decoration: InputDecoration(
            isDense: false,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            hintStyle: txt.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            suffixIcon: IconButton(
              tooltip: obscureText ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
              iconSize: 22,
              icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
              onPressed: onToggleObscure,
            ),
          ),
          validator: validatorOverride ??
              (v) {
                if (v == null || v.trim().isEmpty) return 'กรุณากรอกรหัสผ่าน';
                if (v.trim().length < 6) {
                  return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                }
                return null;
              },
        ),
      ],
    );
  }
}

/* ─────────── Password strength indicator ─────────── */
class _PasswordStrengthBar extends StatelessWidget {
  final double strength; // 0..1
  final String label;
  final Color color;
  const _PasswordStrengthBar({
    required this.strength,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ให้เปลี่ยนค่าแถบลื่น ๆ เมื่อพิมพ์
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: strength),
          duration: const Duration(milliseconds: 180),
          builder: (_, v, __) => LinearProgressIndicator(
            value: v == 0 ? null : v.clamp(0.05, 1.0),
            minHeight: 6,
            color: color,
            backgroundColor: cs.surfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'ความแข็งแรงรหัสผ่าน: $label',
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
