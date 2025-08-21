// lib/screens/reset_password_screen.dart
//
// 2025-08-02 – polish: clearer validation, safer error parsing,
//                     consistent email regex, nicer UX & navigation.

import 'package:cookbook/screens/otp_verification_screen.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  /* ─────────── Form & Controllers ─────────── */
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _emailNode = FocusNode();

  // Same pattern used across the app
  final _emailReg = RegExp(r'^[\w\.\-\+]+@([\w\-]+\.)+[A-Za-z]{2,}$');

  /* ─────────── UI State ─────────── */
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _emailNode.dispose();
    super.dispose();
  }

  /* ─────────── Helpers ─────────── */

  String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'กรุณากรอกอีเมล';
    if (!_emailReg.hasMatch(s)) return 'รูปแบบอีเมลไม่ถูกต้อง';
    return null;
  }

  String _parseErrors(dynamic raw, {String? fallback}) {
    if (raw == null) return fallback ?? 'เกิดข้อผิดพลาด';
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

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? cs.error : Colors.green[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /* ─────────── Action ─────────── */
  Future<void> _sendOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    final email = _emailCtrl.text.trim();

    try {
      final result = await ApiService.sendOtp(email);
      if (!mounted) return;

      final success = result['success'] == true;
      final message = (result['message'] ?? '').toString();
      final errorCode = (result['errorCode'] ?? '').toString();

      // Treat rate limit/cooldown responses as "sent" for UX
      final looksLikeCooldown = errorCode.toUpperCase() == 'RATE_LIMIT' ||
          message.contains('กรุณารอ');

      if (success || looksLikeCooldown) {
        _showSnack('ส่งรหัส OTP ไปยังอีเมลแล้ว', error: false);
        Navigator.pushNamed(context, OtpVerificationScreen.route,
            arguments: email);
        return;
      }

      // Specific case: account not found
      if (errorCode.toUpperCase() == 'ACCOUNT_NOT_FOUND') {
        setState(() => _errorMsg = 'ไม่พบบัญชีอีเมลนี้ในระบบ');
        return;
      }

      // Generic errors
      final errs = result['errors'];
      setState(() => _errorMsg =
          _parseErrors(errs, fallback: message.isEmpty ? null : message));
    } on ApiException catch (e) {
      setState(() => _errorMsg = e.message);
    } catch (_) {
      setState(() => _errorMsg = 'เกิดข้อผิดพลาดในการเชื่อมต่อ');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /* ─────────── UI ─────────── */
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txt = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('ลืมรหัสผ่าน'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.lock_reset,
                    size: 80, color: theme.colorScheme.primary),
                const SizedBox(height: 24),
                Text(
                  'กรอกอีเมลที่ใช้สมัครเพื่อรับรหัส OTP สำหรับตั้งรหัสผ่านใหม่ของคุณ',
                  textAlign: TextAlign.center,
                  style: txt.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                Text('อีเมลของคุณ',
                    style:
                        txt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  focusNode: _emailNode,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _sendOtp(),
                  decoration: const InputDecoration(
                    hintText: 'email@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),
                if (_errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      _errorMsg!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text('ส่งรหัส OTP'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
