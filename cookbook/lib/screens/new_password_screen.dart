// lib/screens/new_password_screen.dart
//
// 2025-08-12 – UI polish for large typography
//   • ใช้ titleMedium/bodyLarge ตามธีมใหม่ใน main.dart
//   • เพิ่ม spacing และ contentPadding ช่องกรอกรหัส
//   • ไอคอนแสดง/ซ่อนรหัสใหญ่ขึ้น
//   • แถบความแข็งแรงหนา/โค้งมนขึ้น อ่านง่ายขึ้น
//   • คง logic reset_token (ทางเลือก B) ไว้เหมือนเดิมผ่าน ApiService
//
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // haptics
import '../services/api_service.dart';

/// หน้าตั้งรหัสผ่านใหม่: รับ email + otp (ที่ฝั่ง API แมปเป็น reset_token แล้ว)
class NewPasswordScreen extends StatefulWidget {
  final String email;
  final String
      otp; // ← ชื่อ param เดิมคงไว้ได้ เพราะ ApiService ส่งเป็น reset_token ให้เอง
  const NewPasswordScreen({
    super.key,
    required this.email,
    required this.otp,
  });

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  /* ── form & controllers ─────────────────────────────────── */
  final _formKey = GlobalKey<FormState>();
  final _pass1Ctrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  final _pass1Focus = FocusNode();
  final _pass2Focus = FocusNode();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _isLoading = false;
  String? _errorMsg;

  // ★ Realtime: ฟังการพิมพ์รหัสผ่านใหม่ แล้วอัปเดตแถบความแข็งแรงทันที
  void _onPass1Changed() {
    if (mounted) setState(() {});
  }

  // ประเมินความแข็งแรงรหัสผ่าน (0..1)
  double get _strength => _calcStrength(_pass1Ctrl.text);

  @override
  void initState() {
    super.initState();
    _pass1Ctrl.addListener(_onPass1Changed); // ★ realtime meter
  }

  @override
  void dispose() {
    _pass1Ctrl.removeListener(_onPass1Changed); // ★ cleanup
    _pass1Ctrl.dispose();
    _pass2Ctrl.dispose();
    _pass1Focus.dispose();
    _pass2Focus.dispose();
    super.dispose();
  }

  /* ── helpers ───────────────────────────────────────────── */
  // (removed) unused _showSnack

  // โลจิกให้คะแนน: ยาว≥8, ยาว≥12, มี A-Z, มี a-z, มีตัวเลข, มีอักขระพิเศษ → รวม 6 คะแนน
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

  String? _validateNew(String? v) {
    final p = (v ?? '').trim();
    if (p.isEmpty) return 'กรุณากรอกรหัสผ่าน';
    if (p.length < 8) return 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร';
    if (!RegExp(r'(?=.*[A-Za-z])(?=.*\d)').hasMatch(p)) {
      return 'ต้องมีทั้งตัวอักษรและตัวเลขอย่างน้อยอย่างละ 1';
    }
    return null;
  }

  /* ── submit ────────────────────────────────────────────── */
  Future<void> _submitNewPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_pass1Ctrl.text != _pass2Ctrl.text) {
      setState(() => _errorMsg = 'รหัสผ่านใหม่และการยืนยันไม่ตรงกัน');
      return;
    }

    setState(() {
      _errorMsg = null;
      _isLoading = true;
    });

    try {
      final res = await ApiService.resetPassword(
        widget.email,
        widget.otp, // ← ส่งต่อให้ ApiService แมปเป็น reset_token
        _pass1Ctrl.text.trim(),
      );

      if (res['success'] == true) {
        HapticFeedback.lightImpact();
        _pass1Ctrl.clear();
        _pass2Ctrl.clear();
        if (mounted) await _showSuccessDialog();
      } else {
        setState(
          () => _errorMsg = res['message'] ?? 'เกิดข้อผิดพลาดที่ไม่รู้จัก',
        );
      }
    } on ApiException catch (e) {
      setState(() => _errorMsg = e.message);
    } catch (_) {
      setState(() => _errorMsg = 'เกิดข้อผิดพลาดในการเชื่อมต่อ');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showSuccessDialog() async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    // ★ จำกัด text scale กัน overflow จากการตั้งค่าฟอนต์ใหญ่ของเครื่อง
    final clampedScaler = MediaQuery.textScalerOf(context)
        .clamp(minScaleFactor: 1.0, maxScaleFactor: 1.3);

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return MediaQuery(
          // ใช้ text scale ที่คลัมป์แล้วภายใน dialog นี้เท่านั้น
          data: MediaQuery.of(ctx).copyWith(textScaler: clampedScaler),
          child: Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                  maxWidth: 420), // สวยบนแท็บเล็ต/เดสก์ท็อป
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // เนื้อหา
                  Padding(
                    // เผื่อพื้นที่ด้านบนสำหรับ badge
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
                    child: SingleChildScrollView(
                      // กันล้นแนวตั้งกรณีฟอนต์ใหญ่มาก
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'สำเร็จ',
                            style: tt.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            // ตัด \n ออกเพื่อให้จัดบรรทัดอัตโนมัติสวยขึ้น
                            'รหัสผ่านของคุณถูกเปลี่ยนเรียบร้อยแล้ว กรุณาเข้าสู่ระบบอีกครั้งด้วยรหัสผ่านใหม่',
                            textAlign: TextAlign.center,
                            style: tt.bodyLarge?.copyWith(
                              height: 1.5,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () => Navigator.of(ctx)
                                  .pushNamedAndRemoveUntil(
                                      '/login', (_) => false),
                              child: const Text('ดำเนินการต่อ'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Badge ไอคอนเช็ค ลอยเหนือการ์ดเล็กน้อย
                  Positioned(
                    top: -36,
                    left: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor:
                          cs.tertiaryContainer, // โทนสำเร็จที่เข้ากับธีม M3
                      child: Icon(Icons.check_rounded,
                          size: 42, color: cs.onTertiaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /* ── build ─────────────────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;

    // คำอธิบาย/สีตาม strength (คำนวณใน build เพื่อให้สดใหม่)
    final s = _strength;
    Color barColor;
    String label;
    if (s >= 0.75) {
      barColor = theme.colorScheme.primary;
      label = 'แข็งแรง';
    } else if (s >= 0.5) {
      barColor = Colors.orange;
      label = 'ปานกลาง';
    } else if (s > 0.0) {
      barColor = theme.colorScheme.error;
      label = 'อ่อน';
    } else {
      // เปลี่ยนเป็นสีพื้น container สูงสุด (M3 แนะนำ)
      barColor = theme.colorScheme.surfaceContainerHighest;
      label = '—';
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('ตั้งรหัสผ่านใหม่')),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.fromLTRB(24, 28, 24, 32), // ★ padding ใหญ่ขึ้น
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'สร้างรหัสผ่านใหม่ที่แตกต่างจากรหัสผ่านเดิมเพื่อความปลอดภัย',
                style: tt.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ), // ★ bodyLarge
              ),
              const SizedBox(height: 26),

              if (_errorMsg != null) ...[
                Text(
                  _errorMsg!,
                  textAlign: TextAlign.center,
                  style: tt.bodyLarge // ★ ใหญ่ขึ้น
                      ?.copyWith(color: theme.colorScheme.error),
                ),
                const SizedBox(height: 14),
              ],

              // รหัสผ่านใหม่
              Text('รหัสผ่านใหม่',
                  style: tt.titleMedium // ★ ใหญ่ขึ้น
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _pass1Ctrl,
                focusNode: _pass1Focus,
                style: tt.bodyLarge, // ★ ตัวพิมพ์ใหญ่ขึ้น
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _pass2Focus.requestFocus(),
                obscureText: _obscure1,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  hintText: 'อย่างน้อย 8 ตัว มีตัวอักษรและตัวเลข',
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 18), // ★
                  suffixIcon: IconButton(
                    tooltip: _obscure1 ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                    iconSize: 24, // ★
                    icon: Icon(
                        _obscure1 ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                  ),
                ),
                validator: _validateNew,
              ),
              const SizedBox(height: 14),

              // ★ Realtime + ลื่นขึ้นด้วยอนิเมชัน
              _PasswordStrengthBar(
                strength: s,
                label: 'ความแข็งแรงรหัสผ่าน: $label',
                color: barColor,
              ),

              const SizedBox(height: 26),

              // ยืนยันรหัสผ่านใหม่
              Text('ยืนยันรหัสผ่านใหม่',
                  style: tt.titleMedium // ★ ใหญ่ขึ้น
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _pass2Ctrl,
                focusNode: _pass2Focus,
                style: tt.bodyLarge, // ★
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) =>
                    _isLoading ? null : _submitNewPassword(),
                obscureText: _obscure2,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  hintText: 'กรอกรหัสผ่านใหม่อีกครั้ง',
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 18), // ★
                  suffixIcon: IconButton(
                    tooltip: _obscure2 ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                    iconSize: 24, // ★
                    icon: Icon(
                        _obscure2 ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                  ),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'กรุณายืนยันรหัสผ่าน';
                  if (t != _pass1Ctrl.text.trim()) {
                    return 'ยืนยันรหัสผ่านไม่ตรงกัน';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 34),

              ElevatedButton(
                onPressed: _isLoading ? null : _submitNewPassword,
                child: _isLoading
                    ? const SizedBox(
                        height: 26, // ★
                        width: 26, // ★
                        child: CircularProgressIndicator(
                            strokeWidth: 3, color: Colors.white),
                      )
                    : const Text('ยืนยันและตั้งรหัสผ่านใหม่'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ───────────────── Password strength indicator ───────────────── */
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
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ★ แถบหนาและโค้งมนขึ้น
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: strength),
            duration: const Duration(milliseconds: 200),
            builder: (_, v, __) => LinearProgressIndicator(
              value: v == 0 ? null : v.clamp(0.06, 1.0),
              minHeight: 10, // ★ หนาขึ้น
              color: color,
              // เดิมใช้ surfaceVariant ซึ่งเลิกแนะนำ → ใช้ surfaceContainerHighest
              backgroundColor: cs.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: tt.bodyLarge // ★ ใหญ่ขึ้น
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
