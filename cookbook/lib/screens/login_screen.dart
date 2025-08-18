// lib/screens/login_screen.dart
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /* ── controllers & keys ───────────────────────────────────────── */
  final _formKey = GlobalKey<FormState>(); // คีย์ฟอร์ม
  final _emailCtrl = TextEditingController(); // อีเมล
  final _passCtrl = TextEditingController(); // รหัสผ่าน
  final _emailReg = RegExp(r'^[\w\.\-]+@[\w\-]+\.[A-Za-z]{2,}$'); // regex เมล

  // โฟกัส + toggle รหัสผ่าน
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  bool _obscurePass = true;

  // ลิงก์ "ไปยืนยัน" ใต้ช่องอีเมล (ต้อง dispose)
  late final TapGestureRecognizer _verifyTapRecognizer;

  /* ── Google ───────────────────────────────────────────────────── */
  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', 'openid'],
    serverClientId:
        '84901598956-dui13r3k1qmvo0t0kpj6h5mhjrjbvoln.apps.googleusercontent.com',
  );

  /* ── UI state ─────────────────────────────────────────────────── */
  bool _isLoading = false; // โหลดระหว่างยิง API
  String? _errorMsg; // error ลอย (กรณีอื่น ๆ)
  String? _emailVerifyError; // ★ ข้อความ “ต้องยืนยันก่อน” ใต้ช่องอีเมล

  @override
  void initState() {
    super.initState();
    // พิมพ์อีเมลใหม่ → เคลียร์ error ใต้ช่อง
    _emailCtrl.addListener(() {
      if (_emailVerifyError != null) setState(() => _emailVerifyError = null);
    });
    _verifyTapRecognizer = TapGestureRecognizer()..onTap = _goVerifyNow;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _verifyTapRecognizer.dispose(); // สำคัญ
    super.dispose();
  }

  /* ── navigation ───────────────────────────────────────────────── */
  void _navToHome() =>
      Navigator.of(context).pushReplacementNamed('/home', result: true);

  /* ── helpers ─────────────────────────────────────────────────── */
  void _setLoading(bool v) {
    if (!mounted) return;
    setState(() {
      _isLoading = v;
      if (v) _errorMsg = null; // เริ่มโหลดล้าง error ลอย
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ตรวจว่าดูเหมือน “ยังไม่ยืนยันอีเมล”
  bool _looksLikeEmailNotVerified(Map resOrData) {
    final code = (resOrData['errorCode'] ??
            resOrData['code'] ??
            resOrData['status'] ??
            '')
        .toString()
        .toUpperCase();
    if (code == 'EMAIL_NOT_VERIFIED' ||
        code == 'VERIFY_REQUIRED' ||
        code == 'UNVERIFIED') return true;

    if (resOrData['must_verify'] == true ||
        resOrData['require_verify'] == true ||
        resOrData['require_email_verify'] == true ||
        resOrData['email_verified'] == false) return true;

    final cand = <String>[];
    final msg = resOrData['message'];
    if (msg is String && msg.trim().isNotEmpty) cand.add(msg);
    final data = resOrData['data'];
    if (data is Map && data['message'] is String) cand.add(data['message']);
    final errs = resOrData['errors'];
    if (errs is List) cand.addAll(errs.map((e) => e.toString()));

    bool hasKW(String s) =>
        s.contains('ยืนยันอีเมล') ||
        (s.contains('ยืนยัน') && s.contains('อีเมล')) ||
        s.toLowerCase().contains('verify');
    return cand.any(hasKW);
  }

  /* ── actions ─────────────────────────────────────────────────── */
  Future<void> _enterAsGuest() async {
    await AuthService.logout();
    _navToHome();
  }

  Future<void> _loginWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    _setLoading(true);
    try {
      final res = await ApiService.login(
        _emailCtrl.text.trim(),
        _passCtrl.text,
      );

      if (res['success'] != true) {
        final msg =
            (res['message'] ?? 'อีเมลหรือรหัสผ่านไม่ถูกต้อง').toString();
        final looksUnverified = _looksLikeEmailNotVerified(res) ||
            msg.contains('ยืนยันอีเมล') ||
            (msg.contains('ยืนยัน') && msg.contains('อีเมล')) ||
            msg.toLowerCase().contains('verify');

        if (looksUnverified) {
          setState(() {
            _emailVerifyError = 'กรุณายืนยันอีเมลก่อนเข้าสู่ระบบ';
            _errorMsg = null;
          });
        } else {
          setState(() => _errorMsg = msg);
        }
        return;
      }

      await AuthService.saveLoginData(res['data']);
      _navToHome();
    } on ApiException catch (e) {
      // ★ เคส BE ตอบ 403 แล้วโยน exception → จับให้โชว์ใต้ช่องอีเมล
      final msg = e.message;
      final looksUnverified = (e.statusCode == 403) ||
          msg.contains('ยืนยันอีเมล') ||
          (msg.contains('ยืนยัน') && msg.contains('อีเมล')) ||
          msg.toLowerCase().contains('verify');

      if (looksUnverified) {
        setState(() {
          _emailVerifyError =
              msg.isNotEmpty ? msg : 'กรุณายืนยันอีเมลก่อนเข้าสู่ระบบ';
          _errorMsg = null;
        });
      } else {
        setState(() => _errorMsg = msg);
      }
    } catch (_) {
      setState(() => _errorMsg = 'เกิดข้อผิดพลาดที่ไม่รู้จัก');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loginWithGoogle() async {
    _setLoading(true);
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      final account = await _googleSignIn.signIn();
      if (account == null) return;
      final auth = await account.authentication;
      final token = auth.idToken;
      if (token == null) {
        throw ApiException('ไม่สามารถดึง Google ID Token ได้');
      }

      final res = await ApiService.googleSignIn(token);
      if (res['success'] != true) {
        setState(
            () => _errorMsg = res['message'] ?? 'ล็อกอินด้วย Google ล้มเหลว');
        return;
      }

      await AuthService.saveLoginData(res['data']);
      _navToHome();
    } on ApiException catch (e) {
      setState(() => _errorMsg = e.message);
      await _googleSignIn.signOut();
    } catch (_) {
      setState(() => _errorMsg = 'เกิดข้อผิดพลาดในการล็อกอินด้วย Google');
      await _googleSignIn.signOut();
    } finally {
      _setLoading(false);
    }
  }

  // ไปหน้ายืนยันอีเมล โดยเคารพคูลดาวน์ที่เหลือ
  Future<void> _goVerifyNow() async {
    final currentEmail = _emailCtrl.text.trim();
    if (currentEmail.isEmpty) {
      _showSnack('กรุณากรอกอีเมลก่อน');
      return;
    }
    final pending =
        await AuthService.getPendingEmailVerify(); // {email, secondsLeft}?
    final secondsLeft = (pending != null && pending['email'] == currentEmail)
        ? (pending['secondsLeft'] ?? 0)
        : 0;

    if (!mounted) return;
    Navigator.pushNamed(
      context,
      '/verify_email',
      arguments: {
        'email': currentEmail,
        'startCooldown': secondsLeft > 0,
      },
    );
  }

  /* ── build ───────────────────────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txt = theme.textTheme;
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- Logo + Title ---
                      const SizedBox(height: 6),
                      Image.asset('assets/images/logo.png', height: 96),
                      const SizedBox(height: 14),
                      Text(
                        'Cooking Guide',
                        textAlign: TextAlign.center,
                        style: txt.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // --- Email ---
                      TextFormField(
                        controller: _emailCtrl,
                        focusNode: _emailFocus,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _passFocus.requestFocus(),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email
                        ],
                        decoration: const InputDecoration(
                          labelText: 'อีเมล',
                          // ไม่ใช้ errorText เพื่อให้เราวาง RichText ที่มีลิงก์ได้
                        ),
                        validator: (v) {
                          final t = v?.trim() ?? '';
                          if (t.isEmpty) return 'กรุณากรอกอีเมล';
                          if (!_emailReg.hasMatch(t))
                            return 'รูปแบบอีเมลไม่ถูกต้อง';
                          return null;
                        },
                      ),

                      // ★ ข้อความ “ต้องยืนยัน” + ลิงก์ ไปยืนยัน (บรรทัดเดียว)
                      if (_emailVerifyError != null) ...[
                        const SizedBox(height: 8),
                        RichText(
                          text: TextSpan(
                            style: txt.bodyMedium?.copyWith(
                              color: cs.error,
                              height: 1.25,
                            ),
                            children: [
                              const TextSpan(
                                text: 'กรุณายืนยันอีเมลก่อนเข้าสู่ระบบ  ',
                              ),
                              TextSpan(
                                text: 'ไปยืนยัน',
                                style: TextStyle(
                                  color: cs.primary,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: _verifyTapRecognizer,
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // --- Password ---
                      TextFormField(
                        controller: _passCtrl,
                        focusNode: _passFocus,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) =>
                            _isLoading ? null : _loginWithEmail(),
                        obscureText: _obscurePass,
                        obscuringCharacter: '•',
                        enableSuggestions: false,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'รหัสผ่าน',
                          suffixIcon: IconButton(
                            tooltip:
                                _obscurePass ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                            icon: Icon(
                              _obscurePass
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 22,
                            ),
                            onPressed: () =>
                                setState(() => _obscurePass = !_obscurePass),
                          ),
                        ),
                        validator: (v) {
                          final t = v ?? '';
                          if (t.isEmpty) return 'กรุณากรอกรหัสผ่าน';
                          if (t.length < 6)
                            return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                          return null;
                        },
                      ),

                      // --- แถวลิงก์ขวา (เว้นระยะให้โล่งขึ้น) ---
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.pushNamed(
                                  context, '/reset_password'),
                          child: const Text('ลืมรหัสผ่าน?'),
                        ),
                      ),

                      // --- Error ลอย (เฉพาะกรณีอื่น) ---
                      if (_errorMsg != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _errorMsg!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.error),
                        ),
                      ],

                      const SizedBox(height: 10),
                      // --- Login Button ---
                      ElevatedButton(
                        onPressed: _isLoading ? null : _loginWithEmail,
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Text('ลงชื่อเข้าใช้'),
                      ),

                      const SizedBox(height: 18),

                      // --- Register link ---
                      Center(
                        child: RichText(
                          text: TextSpan(
                            text: 'ยังไม่มีบัญชีใช่ไหม? ',
                            style: txt.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant),
                            children: [
                              TextSpan(
                                text: 'สมัครสมาชิกเลย!',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                  color: cs.primary,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () =>
                                      Navigator.pushNamed(context, '/register'),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // --- Divider ---
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text('หรือ'),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // --- Google Sign-in ---
                      Semantics(
                        button: true,
                        label: 'เข้าสู่ระบบด้วย Google',
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _loginWithGoogle,
                          icon: SvgPicture.asset('assets/icons/google.svg',
                              width: 22),
                          label: const Text('ดำเนินการต่อด้วย Google'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cs.onSurface,
                            side: const BorderSide(color: Colors.black26),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // --- Guest ---
                      TextButton.icon(
                        onPressed: _isLoading ? null : _enterAsGuest,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('เข้าใช้งานโดยไม่ล็อกอิน'),
                        style: TextButton.styleFrom(
                          foregroundColor: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Loading overlay กันกดซ้ำ
            if (_isLoading)
              IgnorePointer(
                ignoring: true,
                child: Container(color: Colors.black.withOpacity(.12)),
              ),
          ],
        ),
      ),
    );
  }
}
