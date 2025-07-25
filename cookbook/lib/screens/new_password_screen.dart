import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// หน้าตั้งรหัสผ่านใหม่: รับ email + otp จากหน้าก่อนหน้า
class NewPasswordScreen extends StatefulWidget {
  final String email;
  final String otp;
  const NewPasswordScreen({
    super.key,
    required this.email,
    required this.otp,
  });

  @override
  _NewPasswordScreenState createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  // ✅ ใช้ GlobalKey<FormState> เพื่อจัดการ validation
  final _formKey = GlobalKey<FormState>();
  // Controllers สำหรับกรอกรหัสผ่านใหม่และยืนยันรหัสผ่าน
  final _pass1Ctrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  bool _obscure1 = true; // สลับการมองเห็นรหัสผ่านช่องแรก
  bool _obscure2 = true; // สลับการมองเห็นรหัสผ่านช่องสอง
  bool _isLoading = false; // แสดงสถานะกำลังส่งข้อมูล
  String? _errorMsg; // ข้อความแสดงข้อผิดพลาด

  @override
  void dispose() {
    _pass1Ctrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  /* ───────── submit reset ───────── */
  /// ✅ 1. ปรับปรุง Error Handling และ Validation
  Future<void> _submitNewPassword() async {
    // 1. Validate Form ก่อน
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // 2. ตรวจสอบว่ารหัสผ่านใหม่และยืนยันรหัสผ่านตรงกัน
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
        widget.otp,
        _pass1Ctrl.text,
      );

      if (res['success'] == true) {
        // เมื่อสำเร็จ, แสดง Dialog และเมื่อกดปุ่มจะเคลียร์ Stack แล้วไปหน้า Login
        if (mounted) await _showSuccessDialog();
      } else {
        setState(
            () => _errorMsg = res['message'] ?? 'เกิดข้อผิดพลาดที่ไม่รู้จัก');
      }
    } on ApiException catch (e) {
      setState(() => _errorMsg = e.message);
    } catch (e) {
      setState(() => _errorMsg = 'เกิดข้อผิดพลาดในการเชื่อมต่อ');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /* ───────── dialog สำเร็จ ───────── */
  /// ✅ 2. ปรับปรุง Dialog ให้ใช้ Theme และ Navigation ที่ถูกต้อง
  Future<void> _showSuccessDialog() async {
    final theme = Theme.of(context);
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ไอคอนติ๊กถูกในวงกลม
            CircleAvatar(
              radius: 36,
              backgroundColor: Colors.green.shade600,
              child: const Icon(Icons.check, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            // หัวข้อ “สำเร็จ”
            Text('สำเร็จ', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            // คำอธิบาย
            Text(
              'รหัสผ่านของคุณถูกเปลี่ยนเรียบร้อยแล้ว\nกรุณาเข้าสู่ระบบอีกครั้งด้วยรหัสผ่านใหม่',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 24),
            // ปุ่ม “ดำเนินการต่อ”
            ElevatedButton(
              onPressed: () {
                // เคลียร์ Stack ทั้งหมดแล้วไปหน้า Login
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/login', (_) => false);
              },
              child: const Text('ดำเนินการต่อ'),
            ),
          ]),
        ),
      ),
    );
  }

  /* ──────────── build ──────────── */
  @override
  Widget build(BuildContext context) {
    // ✅ 3. ลบ Manual Responsive Calculation และใช้ Theme
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      // ✅ 4. เปลี่ยนมาใช้ AppBar มาตรฐาน
      appBar: AppBar(
        title: const Text('ตั้งรหัสผ่านใหม่'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'สร้างรหัสผ่านใหม่ที่แตกต่างจากรหัสผ่านเดิมเพื่อความปลอดภัย',
                style: textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              // แสดง error ถ้ามี
              if (_errorMsg != null) ...[
                Text(
                  _errorMsg!,
                  style: textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
              ],
              // ช่องรหัสผ่านใหม่
              Text(
                'รหัสผ่านใหม่',
                style:
                    textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _pass1Ctrl,
                obscureText: _obscure1,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  hintText: 'กรอกรหัสผ่านใหม่อย่างน้อย 6 ตัว',
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure1 ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'กรุณากรอกรหัสผ่าน';
                  if (v.length < 6) return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // ช่องยืนยันรหัสผ่าน
              Text(
                'ยืนยันรหัสผ่านใหม่',
                style:
                    textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _pass2Ctrl,
                obscureText: _obscure2,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  hintText: 'กรอกรหัสผ่านใหม่อีกครั้ง',
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure2 ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'กรุณายืนยันรหัสผ่าน';
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // ปุ่ม “อัปเดตรหัสผ่าน”
              ElevatedButton(
                onPressed: _isLoading ? null : _submitNewPassword,
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 3, color: Colors.white),
                      )
                    : const Text('ยืนยันและตั้งรหัสผ่านใหม่'),
              ),
            ],
          ),
        ),
      ),
      // ❌ 5. ลบ Bottom Nav Bar ออก
      // ในหน้านี้ ผู้ใช้ควรมีทางเลือกแค่ "ตั้งรหัสผ่าน" หรือ "ย้อนกลับ" เท่านั้น
      // bottomNavigationBar: CustomBottomNav(...)
    );
  }
}
