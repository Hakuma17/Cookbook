import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cookbook/screens/references_screen.dart';
import 'package:cookbook/services/auth_service.dart';
import 'package:cookbook/screens/change_password_screen.dart';
import 'package:cookbook/widgets/custom_bottom_nav.dart';

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
    _loadProfileSafely();
  }

  Future<void> _loadProfileSafely() async {
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
    } catch (_) {
      _showSnack('ออกจากระบบไม่สำเร็จ');
    }
  }

  void _showSnack(String msg) => ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(content: Text(msg)));

  /* ───────────────────────── build ──────────────────────── */
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      /* ── responsive metrics ── */
      final w = constraints.maxWidth;
      double clamp(double v, double min, double max) =>
          v < min ? min : (v > max ? max : v);

      final pad = clamp(w * 0.05, 16, 32); // page padding
      final cardPad = clamp(w * 0.03, 12, 24); // inner card padding
      final titleF = clamp(w * 0.048, 16, 22); // ListTile title
      final subF = clamp(w * 0.038, 13, 16); // subtitle
      final iconSz = clamp(w * 0.07, 20, 28); // leading icon
      final divider = Divider(height: clamp(w * 0.12, 32, 48));

      return Scaffold(
        appBar: AppBar(
          title: const Text('การตั้งค่า'),
          centerTitle: true,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.all(pad),
                children: [
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: cardPad),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(Icons.email,
                                size: iconSz, color: Colors.grey[700]),
                            title: Text('อีเมลของคุณ',
                                style: TextStyle(fontSize: titleF)),
                            subtitle: Text(_email ?? '-',
                                style: TextStyle(fontSize: subF)),
                            horizontalTitleGap: 10,
                          ),
                          divider,
                          ListTile(
                            leading: Icon(Icons.lock_reset, size: iconSz),
                            title: Text('เปลี่ยนรหัสผ่าน',
                                style: TextStyle(fontSize: titleF)),
                            trailing: Icon(Icons.arrow_forward_ios,
                                size: iconSz * 0.7),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ChangePasswordScreen()),
                            ),
                          ),

                          // ★★★ เพิ่มส่วนนี้เข้ามา ★★★
                          divider,
                          ListTile(
                            leading: Icon(Icons.info_outline, size: iconSz),
                            title: Text('ข้อมูลอ้างอิง',
                                style: TextStyle(fontSize: titleF)),
                            trailing: Icon(Icons.arrow_forward_ios,
                                size: iconSz * 0.7),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ReferencesScreen(),
                                ),
                              );
                            },
                          ),
                          // ★★★ จบส่วนที่เพิ่ม ★★★

                          divider,
                          ListTile(
                            leading: Icon(Icons.logout,
                                size: iconSz, color: Colors.redAccent),
                            title: Text('ออกจากระบบ',
                                style: TextStyle(
                                    fontSize: titleF, color: Colors.redAccent)),
                            onTap: _logout,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

        /* ───────── bottom-nav (คงเดิม) ───────── */
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
    });
  }
}
