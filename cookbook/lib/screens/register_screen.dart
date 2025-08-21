// lib/screens/register_screen.dart
import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  /* ───── Form & Controllers ───── */
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  // โฟกัส
  final _userNode = FocusNode();
  final _emailNode = FocusNode();
  final _passNode = FocusNode();
  final _confirmNode = FocusNode();

  late final TapGestureRecognizer _toLoginTap; // ลิงก์กลับหน้า Login

  // ซ่อน/โชว์รหัสผ่าน
  bool _hidePass = true;
  bool _hideConfirm = true;

  /* ───── State ───── */
  bool _isLoading = false;
  String? _errorMsg;

  // ★ สถานะตรวจอีเมลแบบเรียลไทม์
  Timer? _emailDebounce;
  bool _emailChecking = false;
  bool? _emailAvailable; // true=ว่างใช้ได้, false=ถูกใช้แล้ว, null=ยังไม่รู้
  String? _emailServerError; // โชว์ใต้ช่องอีเมลเมื่อซ้ำ/ผิด

  final _emailReg = RegExp(r'^[\w\.\-\+]+@([\w\-]+\.)+[A-Za-z]{2,}$');

  // มิเตอร์ความแข็งแรง (0..1)
  double get _strength => _calcStrength(_passCtrl.text);
  void _onPassChanged() {
    if (mounted) setState(() {}); // อัปเดตมิเตอร์
  }

  @override
  void initState() {
    super.initState();
    // แตะ “กลับไปลงชื่อเข้าใช้”
    _toLoginTap = TapGestureRecognizer()
      ..onTap = () {
        if (!mounted) return;
        Navigator.pop(context);
      };
    _passCtrl.addListener(_onPassChanged); // อัปเดตมิเตอร์เรียลไทม์

    // พิมพ์อะไรให้เคลียร์ error
    for (final c in [_userCtrl, _emailCtrl, _passCtrl, _confirmCtrl]) {
      c.addListener(() {
        if (_errorMsg != null && mounted) setState(() => _errorMsg = null);
      });
    }

    // ★ ตรวจอีเมลแบบ debounce
    _emailCtrl.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    _emailDebounce?.cancel();
    _userCtrl.dispose();
    _emailCtrl.removeListener(_onEmailChanged);
    _emailCtrl.dispose();
    _passCtrl.removeListener(_onPassChanged);
    _passCtrl.dispose();
    _confirmCtrl.dispose();

    // ล้าง focus
    _userNode.dispose();
    _emailNode.dispose();
    _passNode.dispose();
    _confirmNode.dispose();
    _toLoginTap.dispose();
    super.dispose();
  }

  // ★ ตรวจอีเมลซ้ำเมื่อผู้ใช้พิมพ์เสร็จ (debounce 450ms)
  void _onEmailChanged() {
    setState(() {
      _emailServerError = null;
      _emailAvailable = null; // reset icon
    });

    final s = _emailCtrl.text.trim();
    _emailDebounce?.cancel();

    if (!_emailReg.hasMatch(s)) {
      // รูปแบบยังไม่ถูก → ยังไม่ยิง
      setState(() {
        _emailChecking = false;
      });
      return;
    }

    _emailDebounce = Timer(const Duration(milliseconds: 450), () async {
      setState(() {
        _emailChecking = true;
      });
      try {
        final res = await ApiService.checkEmailAvailability(s);
        if (!mounted) return;
        final exists = res['exists'] == true;
        setState(() {
          _emailChecking = false;
          _emailAvailable = !exists;
          _emailServerError = exists
              ? (res['message'] as String? ?? 'อีเมลนี้มีอยู่แล้ว')
              : null;
        });
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() {
          _emailChecking = false;
          _emailAvailable = null; // unknown
          _emailServerError = e.message;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _emailChecking = false;
          _emailAvailable = null;
        });
      }
    });
  }

  /* ───── Validators ───── */
  String? _validateUsername(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'กรุณากรอกชื่อผู้ใช้';
    if (s.length < 3) return 'ชื่อผู้ใช้ต้องมีอย่างน้อย 3 ตัวอักษร';
    // อักษร/ตัวเลข/._- + ไทย
    if (!RegExp(r'^[A-Za-z0-9_.\-ก-ฮะ-์\s]+$').hasMatch(s)) {
      return 'ใช้ได้เฉพาะอักษร/ตัวเลข/._- เท่านั้น';
    }
  }

  String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'กรุณากรอกอีเมล';
    if (!_emailReg.hasMatch(s)) return 'รูปแบบอีเมลไม่ถูกต้อง';
    return null; // ★ ซ้ำจะถูกใส่ผ่าน _emailServerError แทน
  }

  // เกณฑ์เดียวกับหน้าเปลี่ยนรหัสผ่าน
  String? _validatePassword(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'กรุณากรอกรหัสผ่าน';
    if (s.length < 8) return 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร';
    if (!RegExp(r'(?=.*[A-Za-z])(?=.*\d)').hasMatch(s))
      return 'ต้องมีทั้งตัวอักษรและตัวเลขอย่างละ 1';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v == null || v.isEmpty) return 'กรุณายืนยันรหัสผ่าน';
    if (v != _passCtrl.text) return 'รหัสผ่านไม่ตรงกัน';
    return null;
  }

  /* ───── Strength logic ───── */
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

  String _strengthLabel(double s) {
    if (s >= 0.75) return 'แข็งแรง';
    if (s >= 0.5) return 'ปานกลาง';
    if (s > 0.0) return 'อ่อน';
    return '—';
  }

  Color _strengthColor(ThemeData theme, double s) {
    if (s >= 0.75) return theme.colorScheme.primary;
    if (s >= 0.5) return Colors.orange;
    if (s > 0.0) return theme.colorScheme.error;
    return theme.colorScheme.surfaceVariant;
  }

  String _parseErrors(dynamic raw) {
    if (raw == null) return 'เกิดข้อผิดพลาด';
    if (raw is String) return raw;
    if (raw is List) return raw.map((e) => e.toString()).join('\n');
    if (raw is Map) {
      final parts = <String>[];
      raw.forEach((k, v) {
        if (v is List) {
          parts
              .add('${k.toString()}: ${v.map((e) => e.toString()).join(', ')}');
        } else {
          parts.add('${k.toString()}: ${v.toString()}');
        }
      });
      return parts.join('\n');
    }
    return raw.toString();
  }

  /* ───── Register Method ───── */
  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // ★ ถ้าเช็คแล้วพบว่าอีเมลซ้ำ → บล็อคก่อน
    if (_emailAvailable == false) {
      setState(() => _errorMsg = 'อีเมลนี้มีอยู่แล้ว');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    // อ่านค่าจากฟอร์ม
    final email = _emailCtrl.text.trim();
    final username = _userCtrl.text.trim();
    final pass = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    try {
      // ยิงสมัคร
      final res = await ApiService.register(email, pass, confirm, username);
      if (!mounted) return;

      if (res['success'] == true) {
        // ส่งเมลสำเร็จไหม?
        final sent = res['email_sent'] == true;

        // จำสถานะ “รอยืนยัน” เพื่อ resume
        await AuthService.markPendingEmailVerify(
            email: email, startCooldown: sent);
        Navigator.pushReplacementNamed(
          context,
          '/verify_email',
          arguments: {'email': email, 'startCooldown': sent},
        );
        return;
      }
      // ถ้าไม่สำเร็จ → แสดงข้อความผิดพลาด
      final msgDyn = res['message'];
      final errs = res['errors'];
      final msg = (msgDyn is String && msgDyn.trim().isNotEmpty)
          ? msgDyn
          : _parseErrors(errs);
      setState(() => _errorMsg = msg);
    } on ApiException catch (e) {
      setState(() => _errorMsg = e.message);
    } catch (_) {
      setState(() => _errorMsg = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ★ ไอคอนสถานะท้ายช่องอีเมล
  Widget? _buildEmailSuffix() {
    if (_emailChecking) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: Padding(
          padding: EdgeInsets.all(2),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_emailAvailable == true) {
      return const Icon(Icons.check_circle_outline);
    }
    if (_emailAvailable == false) {
      return const Icon(Icons.error_outline);
    }
    return null;
  }

  /* ───── Build UI ───── */
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final s = _strength;

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // โลโก้ + หัวเรื่อง
                  Image.asset('assets/images/logo.png', height: 100),
                  const SizedBox(height: 16),
                  Text(
                    'สร้างบัญชีใหม่',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),

                  // Username
                  TextFormField(
                    controller: _userCtrl,
                    focusNode: _userNode,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _emailNode.requestFocus(),
                    decoration: const InputDecoration(
                      labelText: 'ชื่อผู้ใช้',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: _validateUsername,
                  ),
                  const SizedBox(height: 16),

                  // Email
                  TextFormField(
                    controller: _emailCtrl,
                    focusNode: _emailNode,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _passNode.requestFocus(),
                    decoration: InputDecoration(
                      labelText: 'อีเมล',
                      prefixIcon: const Icon(Icons.email_outlined),
                      suffixIcon: _buildEmailSuffix(), // ★
                      errorText: _emailServerError, // ★
                    ),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passCtrl,
                    focusNode: _passNode,
                    obscureText: _hidePass,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _confirmNode.requestFocus(),
                    decoration: InputDecoration(
                      labelText: 'รหัสผ่าน (อย่างน้อย 8 ตัวอักษร)',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_hidePass
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(() => _hidePass = !_hidePass),
                        tooltip: _hidePass ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                      ),
                    ),
                    validator: _validatePassword,
                  ),

                  // Strength meter
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: s),
                            duration: const Duration(milliseconds: 180),
                            builder: (_, v, __) => LinearProgressIndicator(
                              minHeight: 6,
                              value: v == 0 ? null : v.clamp(0.05, 1.0),
                              backgroundColor: theme.colorScheme.surfaceVariant,
                              color: _strengthColor(theme, s),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _strengthLabel(s),
                        style: textTheme.bodySmall?.copyWith(
                            color: _strengthColor(theme, s),
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password
                  TextFormField(
                    controller: _confirmCtrl,
                    focusNode: _confirmNode,
                    obscureText: _hideConfirm,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _register(),
                    decoration: InputDecoration(
                      labelText: 'ยืนยันรหัสผ่าน',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_hideConfirm
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _hideConfirm = !_hideConfirm),
                        tooltip: _hideConfirm ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                      ),
                    ),
                    validator: _validateConfirm,
                  ),
                  const SizedBox(height: 16),

                  // Error รวม
                  if (_errorMsg != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(_errorMsg!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.error)),
                    ),

                  // ปุ่มสมัคร
                  ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 3, color: Colors.white))
                        : const Text('สมัครสมาชิก'),
                  ),
                  const SizedBox(height: 24),

                  // ลิงก์กลับไป Login
                  Center(
                    child: Text.rich(TextSpan(
                      text: 'มีบัญชีอยู่แล้ว? ',
                      style: textTheme.bodyMedium,
                      children: [
                        TextSpan(
                          text: 'กลับไปลงชื่อเข้าใช้',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: _toLoginTap,
                        ),
                      ],
                    )),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
