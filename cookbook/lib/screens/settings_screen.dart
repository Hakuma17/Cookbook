import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'change_password_screen.dart';
import '../widgets/custom_bottom_nav.dart'; // ← ใช้ถ้ามี bottom-nav

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _email;
  bool _loading = true;
  int _selectedIndex = 3; // tab “Profile/Settings”

  /* ───────────────────────── init ───────────────────────── */
  @override
  void initState() {
    super.initState();
    // ไม่ต้องรอ frame — โหลดได้เลย
    _loadProfileSafely();
  }

  Future<void> _loadProfileSafely() async {
    // ถ้า logout จะถูก redirect โดยฟังก์ชันนี้
    final ok = await AuthService.checkAndRedirectIfLoggedOut(context);
    if (!ok || !mounted) return;

    try {
      final data =
          await AuthService.getLoginData().timeout(const Duration(seconds: 10));

      if (!mounted) return;
      setState(() {
        _email = data['email'] ?? '-';
        _loading = false;
      });
    } on TimeoutException {
      _showSnack('เซิร์ฟเวอร์ตอบช้า ลองใหม่ภายหลัง');
    } on SocketException {
      _showSnack('ไม่มีการเชื่อมต่ออินเทอร์เน็ต');
    } catch (e) {
      _showSnack('โหลดข้อมูลไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /* ───────────────────────── actions ────────────────────── */
  Future<void> _logout() async {
    try {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } catch (e) {
      _showSnack('ออกจากระบบไม่สำเร็จ');
    }
  }

  void _showSnack(String msg) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(msg)));
  }

  /* ───────────────────────── build ──────────────────────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('การตั้งค่า'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.email),
                        title: const Text('อีเมลของคุณ'),
                        subtitle: Text(_email ?? '-'),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.lock_reset),
                        title: const Text('เปลี่ยนรหัสผ่าน'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ChangePasswordScreen()),
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        leading:
                            const Icon(Icons.logout, color: Colors.redAccent),
                        title: const Text('ออกจากระบบ',
                            style: TextStyle(color: Colors.redAccent)),
                        onTap: _logout,
                      ),
                    ],
                  ),
                ),
              ],
            ),

      // ถ้าคุณใช้ bottom-nav ทั่วแอป ให้ใส่ไว้ด้วย ↓
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: _selectedIndex,
        isLoggedIn: true,
        onItemSelected: (idx) {
          if (idx == _selectedIndex) return;
          Navigator.pushReplacementNamed(
              context, ['/home', '/search', '/my_recipes', '/profile'][idx]);
        },
      ),
    );
  }
}
