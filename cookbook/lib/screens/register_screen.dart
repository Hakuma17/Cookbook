// lib/screens/register_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/sanitize.dart';
import 'verify_otp_screen.dart'; // สำหรับ fallback นำทางตรงด้วย MaterialPageRoute

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  // ลิมิต (ให้ตรงกับ BE)
  static const int _kNameUiMax = 25; // จำกัดบน UI เท่านั้น
  static const int _kNameDbMaxBytes = 100; // หลังบ้านตรวจจริง (ไบต์)
  static const int _kEmailDbMax = 100;

  final _userNode = FocusNode();
  final _emailNode = FocusNode();
  final _passNode = FocusNode();
  final _confirmNode = FocusNode();

  late final TapGestureRecognizer _toLoginTap;

  bool _hidePass = true;
  bool _hideConfirm = true;

  bool _isLoading = false;
  String? _errorMsg;

  // ตรวจอีเมลซ้ำ (debounce)
  Timer? _emailDebounce;
  bool _emailChecking = false;
  bool? _emailAvailable;
  String? _emailServerError;

  // อีเมล: รูปแบบกว้าง ไม่อนุญาตช่องว่าง
  final _emailReg = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  // [ปรับปรุง] ลบ RegExp ที่เคยจำกัดอักขระชื่อโปรไฟล์ออกทั้งหมด
  // static final RegExp _usernameAllowedOneChar =
  //     RegExp(r'[A-Za-z0-9_.\-ก-ฮะ-์ \t]');
  // static final RegExp _usernameAllowedWhole =
  //     RegExp(r'^[A-Za-z0-9_.\-ก-ฮะ-์ \t]+$');

  // มิเตอร์ความแข็งแรง
  double get _strength => _calcStrength(_passCtrl.text);
  void _onPassChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _toLoginTap = TapGestureRecognizer()..onTap = () => Navigator.pop(context);
    _passCtrl.addListener(_onPassChanged);

    for (final c in [_userCtrl, _emailCtrl, _passCtrl, _confirmCtrl]) {
      c.addListener(() {
        if (_errorMsg != null && mounted) setState(() => _errorMsg = null);
      });
    }
    _emailCtrl.addListener(_onEmailChanged);
    _userCtrl.addListener(() => setState(() {})); // อัปเดตตัวนับ 0/25
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
    _userNode.dispose();
    _emailNode.dispose();
    _passNode.dispose();
    _confirmNode.dispose();
    _toLoginTap.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    setState(() {
      _emailServerError = null;
      _emailAvailable = null;
    });

    final s = _emailCtrl.text.trim();
    _emailDebounce?.cancel();

    if (!_emailReg.hasMatch(s) || s.length > _kEmailDbMax) {
      setState(() => _emailChecking = false);
      return;
    }

    _emailDebounce = Timer(const Duration(milliseconds: 450), () async {
      setState(() => _emailChecking = true);
      try {
        final res = await ApiService.checkEmailAvailability(s.toLowerCase());
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
          _emailAvailable = null;
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

  // ===== Validators (ตรงกับ BE ที่จำเป็น) =====
  String? _validateUsername(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'กรุณากรอกชื่อโปรไฟล์';
    if (utf8.encode(s).length > _kNameDbMaxBytes) {
      return 'ชื่อยาวเกินไป (เกิน 100 ไบต์)';
    }
    // [ปรับปรุง] ลบการตรวจสอบชนิดอักขระ ให้ตรงกับ BE
    // if (!_usernameAllowedWhole.hasMatch(s)) {
    //   return 'มีอักขระไม่ถูกต้อง';
    // }
    return null;
  }

  String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'กรุณากรอกอีเมล';
    if (!_emailReg.hasMatch(s)) return 'รูปแบบอีเมลไม่ถูกต้อง';
    if (s.length > _kEmailDbMax) return 'อีเมลยาวเกินไป';
    return null;
  }

  String? _validatePassword(String? v) {
    final s = v ?? ''; // ไม่ trim เพื่อให้เช็ค space ได้
    if (s.isEmpty) return 'กรุณากรอกรหัสผ่าน';
    if (s.length < 8) return 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร';
    if (!RegExp(r'(?=.*[A-Za-z])(?=.*\d)').hasMatch(s)) {
      return 'ต้องมีทั้งตัวอักษรและตัวเลข';
    }
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v == null || v.isEmpty) return 'กรุณายืนยันรหัสผ่าน';
    if (v != _passCtrl.text) return 'รหัสผ่านไม่ตรงกัน';
    return null;
  }

  // (ส่วน Strength meter, _parseErrors และ UI คงเดิม ไม่มีการเปลี่ยนแปลง)
  // ...
  // ===== Strength meter =====
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
    // ใช้ surfaceContainerHighest แทน surfaceVariant (M3)
    return theme.colorScheme.surfaceContainerHighest;
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

  // ===== Robust navigation to verify email =====
  Future<void> _goVerifyEmail(String email, bool startCooldown) async {
    if (!mounted) return;
    final args = {'email': email, 'startCooldown': startCooldown};

    // ปิด SnackBar ที่ค้างอยู่ก่อน
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // 1) ลอง root navigator ก่อน
    try {
      final rootNav = Navigator.of(context, rootNavigator: true);
      rootNav.pushNamedAndRemoveUntil('/verify_email', (_) => false,
          arguments: args);
      debugPrint('[_goVerifyEmail] root pushNamedAndRemoveUntil OK');
      return;
    } catch (e) {
      debugPrint('[_goVerifyEmail] root push failed: $e');
    }

    // 2) ลอง navigator ปกติ
    try {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/verify_email',
        (_) => false,
        arguments: args,
      );
      debugPrint('[_goVerifyEmail] context pushNamedAndRemoveUntil OK');
      return;
    } catch (e) {
      debugPrint('[_goVerifyEmail] context push failed: $e');
    }

    // 3) สุดท้าย fallback เป็น MaterialPageRoute โดยตรง (กันปัญหา route table)
    try {
      // ignore: use_build_context_synchronously
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => VerifyOtpScreen(
            email: email,
            startCooldown: startCooldown,
          ),
        ),
        (_) => false,
      );
      debugPrint('[_goVerifyEmail] MaterialPageRoute fallback OK');
    } catch (e) {
      debugPrint('[_goVerifyEmail] fallback failed: $e');
    }
  }

  // ===== Register =====
  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_emailAvailable == false) {
      setState(() => _errorMsg = 'อีเมลนี้ถูกใช้งานแล้ว');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    final email = _emailCtrl.text.trim().toLowerCase();
    final username = Sanitize.text(_userCtrl.text);
    final pass = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    try {
      print('Calling register API with email: $email');
      final res = await ApiService.register(email, pass, confirm, username);
      print('Register API response: $res');
      if (!mounted) return;

      // ตรวจสอบหลายรูปแบบของ success
      final isSuccess = res['success'] == true ||
          res['success'] == 'true' ||
          (res['status'] != null &&
              res['status'].toString().toLowerCase() == 'success');

      print(
          'isSuccess check: $isSuccess, original success value: ${res['success']}');

      if (isSuccess) {
        print('Registration success block entered');
        final sent = res['email_sent'] == true;
        await AuthService.markPendingEmailVerify(
            email: email, startCooldown: sent);

        print('Registration successful, navigating to verify_email...');
        print('Email: $email, startCooldown: $sent');

        // แสดงข้อความแจ้งให้ยืนยันอีเมล
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                sent
                    ? 'สมัครสมาชิกสำเร็จ! กรุณาตรวจสอบอีเมลเพื่อยืนยันบัญชี'
                    : 'สมัครสมาชิกสำเร็จ! กำลังส่งอีเมลยืนยัน',
              ),
              backgroundColor: Colors.green[600],
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // รอเล็กน้อยกันชน แล้วนำทางแบบ robust
        await Future.delayed(const Duration(milliseconds: 300));
        print(
            'Navigating to verify_email with email: $email, startCooldown: $sent');
        await _goVerifyEmail(email, sent);
        return;
      }
      print('Registration failed, success check failed');
      print('res[\'success\'] = ${res['success']}');
      print('res[\'status\'] = ${res['status']}');
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
      return const Icon(Icons.check_circle_outline, color: Colors.green);
    }
    if (_emailAvailable == false) {
      return Icon(Icons.error_outline,
          color: Theme.of(context).colorScheme.error);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final s = _strength;

    // ใช้ utf8.encode().length เพื่อให้ได้จำนวน byte ที่ถูกต้องสำหรับตัวนับ
    // แต่เพื่อ UX ที่ดี เราจะแสดงเป็นจำนวนตัวอักษร (rune)
    final charCount = _userCtrl.text.runes.length;
    final counterText = '$charCount/$_kNameUiMax';

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 6),
                  Image.asset('assets/images/logo.png', height: 90),
                  const SizedBox(height: 12),
                  Text(
                    'สร้างบัญชีใหม่',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),

                  // ===== [ปรับปรุง] ชื่อโปรไฟล์ (แยก Label กับ Counter) =====
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.end, // จัดให้ตัวนับชิดขวา
                    children: [
                      // เอา Label แบบเก่า 'Text('ชื่อโปรไฟล์'...)' ออกไปจากตรงนี้
                      Text(counterText, // เหลือแค่ตัวนับไว้
                          style: textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _userCtrl,
                    focusNode: _userNode,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _emailNode.requestFocus(),
                    // ซ่อน counter ของ TextFormField เอง
                    buildCounter: (_,
                            {required currentLength,
                            required isFocused,
                            maxLength}) =>
                        null,
                    inputFormatters: [
                      // [ปรับปรุง] ลบ FilteringTextInputFormatter ที่จำกัดอักขระออก
                      // FilteringTextInputFormatter.allow(_usernameAllowedOneChar),

                      // ใช้ LengthLimitingTextInputFormatter เพื่อจำกัด 'จำนวนตัวอักษร' ที่พิมพ์ได้บน UI
                      LengthLimitingTextInputFormatter(_kNameUiMax),
                    ],
                    // [ปรับปรุง] ใส่ labelText ที่นี่เพื่อให้มัน animate ได้
                    decoration: const InputDecoration(
                      labelText: 'ชื่อโปรไฟล์', // << เพิ่มตรงนี้
                      // hintText: 'ชื่อที่จะแสดงในโปรไฟล์', // เอา hintText ออก
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: _validateUsername,
                    autofillHints: const [AutofillHints.username],
                  ),

                  const SizedBox(height: 12),

                  // ===== อีเมล =====
                  TextFormField(
                    controller: _emailCtrl,
                    focusNode: _emailNode,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _passNode.requestFocus(),
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      LengthLimitingTextInputFormatter(_kEmailDbMax),
                    ],
                    decoration: InputDecoration(
                      labelText: 'อีเมล',
                      helperText: 'สำหรับรับ OTP',
                      prefixIcon: const Icon(Icons.email_outlined),
                      suffixIcon: _buildEmailSuffix(),
                      errorText: _emailServerError,
                    ),
                    validator: _validateEmail,
                    autofillHints: const [AutofillHints.email],
                  ),

                  const SizedBox(height: 12),

                  // ===== รหัสผ่าน =====
                  TextFormField(
                    controller: _passCtrl,
                    focusNode: _passNode,
                    obscureText: _hidePass,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _confirmNode.requestFocus(),
                    decoration: InputDecoration(
                      labelText: 'รหัสผ่าน',
                      helperText: 'อย่างน้อย 8 ตัวอักษร, ต้องมีตัวเลข',
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
                    autofillHints: const [AutofillHints.newPassword],
                  ),

                  // มิเตอร์ความแข็งแรง
                  const SizedBox(height: 6),
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
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              color: _strengthColor(theme, s),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _strengthLabel(s),
                        style: textTheme.bodySmall?.copyWith(
                            color: _strengthColor(theme, s),
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ===== ยืนยันรหัสผ่าน =====
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
                    autofillHints: const [AutofillHints.newPassword],
                  ),

                  const SizedBox(height: 12),

                  if (_errorMsg != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Text(
                        _errorMsg!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),

                  const SizedBox(height: 6),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 3, color: Colors.white),
                          )
                        : const Text('สมัครสมาชิก'),
                  ),
                  const SizedBox(height: 18),

                  Center(
                    child: Text.rich(
                      TextSpan(
                        text: 'มีบัญชีอยู่แล้ว? ',
                        style: textTheme.bodyMedium,
                        children: [
                          TextSpan(
                            text: 'ลงชื่อเข้าใช้',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: _toLoginTap,
                          ),
                        ],
                      ),
                    ),
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
