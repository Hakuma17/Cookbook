import 'dart:async';

import 'package:cookbook/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:cookbook/services/auth_service.dart';

import '../widgets/custom_bottom_nav.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ✅ 1. ใช้ FutureBuilder ในการจัดการ State การโหลด
  late Future<String?> _emailFuture;

  /* ───────────────────────── init ───────────────────────── */
  @override
  void initState() {
    super.initState();
    _emailFuture = _loadUserEmail();
  }

  /// ✅ 2. ปรับปรุงการโหลดข้อมูลและ Error Handling
  Future<String?> _loadUserEmail() async {
    // ❌ ลบ AuthService.checkAndRedirectIfLoggedOut ออก
    // เพราะหน้านี้ควรถูกป้องกันโดย AuthGuard ที่ Router
    try {
      final email = await AuthService.getEmail();
      return email ?? 'ไม่พบข้อมูลอีเมล';
    } on UnauthorizedException {
      await _handleLogout();
      rethrow;
    } on ApiException catch (e) {
      _showSnack(e.message);
      // rethrow เพื่อให้ FutureBuilder แสดง Error
      rethrow;
    } catch (e) {
      _showSnack('ไม่สามารถโหลดข้อมูลได้');
      rethrow;
    }
  }

  /* ───────────────────────── actions ────────────────────── */
  Future<void> _handleLogout() async {
    try {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (e) {
      _showSnack('ออกจากระบบไม่สำเร็จ: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  /* ───────────────────────── build ──────────────────────── */
  @override
  Widget build(BuildContext context) {
    // ✅ 3. ลบ Manual Responsive Calculation และใช้ Theme
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('การตั้งค่า'),
      ),
      body: FutureBuilder<String?>(
        future: _emailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child:
                  Text(snapshot.error?.toString() ?? 'ไม่สามารถโหลดข้อมูลได้'),
            );
          }

          final email = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Card(
                // Card จะใช้สไตล์จาก CardTheme ใน main.dart
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.email_outlined,
                          color: theme.colorScheme.primary),
                      title: Text('อีเมล', style: textTheme.titleMedium),
                      subtitle: Text(email, style: textTheme.bodyMedium),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.lock_reset_outlined,
                          color: theme.colorScheme.primary),
                      title:
                          Text('เปลี่ยนรหัสผ่าน', style: textTheme.titleMedium),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () =>
                          Navigator.pushNamed(context, '/change_password'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.info_outline,
                          color: theme.colorScheme.primary),
                      title:
                          Text('ข้อมูลอ้างอิง', style: textTheme.titleMedium),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => Navigator.pushNamed(context, '/references'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading:
                          Icon(Icons.logout, color: theme.colorScheme.error),
                      title: Text(
                        'ออกจากระบบ',
                        style: textTheme.titleMedium
                            ?.copyWith(color: theme.colorScheme.error),
                      ),
                      onTap: _handleLogout,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: 3,
        onItemSelected: (idx) {
          if (idx == 3) return; // อยู่หน้า Profile/Settings แล้ว
          const routes = ['/home', '/search', '/my_recipes', null];
          if (routes[idx] != null) {
            Navigator.pushReplacementNamed(context, routes[idx]!);
          }
        },
      ),
    );
  }
}
