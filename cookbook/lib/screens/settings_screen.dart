// lib/screens/settings_screen.dart

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
  // 1. [แก้ไข] State ใหม่สำหรับรองรับทั้ง Guest และ User
  late Future<void> _initFuture;
  bool _isLoggedIn = false;
  String? _email;
  String? _errorMessage;

  /* ───────────────────────── init ───────────────────────── */
  @override
  void initState() {
    super.initState();
    _initFuture = _initialize();
  }

  //  2. [แก้ไข] ปรับปรุง Logic การโหลดข้อมูลใหม่ทั้งหมด
  Future<void> _initialize() async {
    try {
      // ดึงสถานะล็อกอินก่อนเป็นอันดับแรก
      final loggedIn = await AuthService.isLoggedIn();
      if (!mounted) return;

      setState(() {
        _isLoggedIn = loggedIn;
      });

      // ถ้าล็อกอินแล้ว ถึงจะไปดึงข้อมูลอีเมลต่อ
      if (loggedIn) {
        final emailData = await AuthService.getEmail();
        if (mounted) {
          setState(() {
            _email = emailData;
          });
        }
      }
    } on UnauthorizedException {
      await _handleLogout();
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'ไม่สามารถโหลดข้อมูลได้');
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

  // 3. ฟังก์ชันสำหรับจัดการการนำทางของ BottomNav
  void _onNavItemTapped(int index) {
    // หน้านี้ถูกมองว่าเป็น index 3
    if (index == 3) {
      setState(() {
        _initFuture = _initialize();
      });
      return;
    }

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/search');
        break;
      case 2:
        // My Recipes ต้องล็อกอิน
        if (!_isLoggedIn) {
          Navigator.pushNamed(context, '/login');
        } else {
          Navigator.pushReplacementNamed(context, '/my_recipes');
        }
        break;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('การตั้งค่า'),
        // ถ้าเป็น Guest จะไม่มีปุ่ม back อัตโนมัติ (เพราะเข้าจาก Tab Bar)
        // ถ้าเป็น User ที่เข้ามาจากหน้า Profile จะมีปุ่ม back ให้
        automaticallyImplyLeading: Navigator.canPop(context),
      ),
      //  4. [แก้ไข] ส่งค่า `isLoggedIn` เข้าไป และเรียกใช้ฟังก์ชันใหม่
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: 3,
        onItemSelected: _onNavItemTapped,
        isLoggedIn: _isLoggedIn,
      ),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_errorMessage != null || snapshot.hasError) {
            return Center(child: Text(_errorMessage ?? 'เกิดข้อผิดพลาด'));
          }

          // 5. [แก้ไข] แสดงผล UI ตามสถานะ _isLoggedIn
          return _isLoggedIn
              ? _buildLoggedInView(context)
              : _buildGuestView(context);
        },
      ),
    );
  }

  ///  6. UI สำหรับผู้ใช้ที่ล็อกอินแล้ว (โค้ดส่วนใหญ่มาจากของเดิม)
  Widget _buildLoggedInView(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.email_outlined,
                    color: theme.colorScheme.primary),
                title: Text('อีเมล', style: textTheme.titleMedium),
                subtitle:
                    Text(_email ?? 'ไม่พบข้อมูล', style: textTheme.bodyMedium),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.lock_reset_outlined,
                    color: theme.colorScheme.primary),
                title: Text('เปลี่ยนรหัสผ่าน', style: textTheme.titleMedium),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => Navigator.pushNamed(context, '/change_password'),
              ),
              const Divider(height: 1),
              ListTile(
                leading:
                    Icon(Icons.info_outline, color: theme.colorScheme.primary),
                title: Text('ข้อมูลอ้างอิง', style: textTheme.titleMedium),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => Navigator.pushNamed(context, '/references'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.logout, color: theme.colorScheme.error),
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
  }

  ///  7. UI สำหรับผู้เยี่ยมชม (Guest)
  Widget _buildGuestView(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // ปุ่มเชิญชวนให้ล็อกอิน
        Card(
          color: theme.colorScheme.primaryContainer.withOpacity(0.5),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Text(
                  'เข้าร่วมกับเรา',
                  style: textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'เพื่อบันทึกสูตรโปรดและสร้างตะกร้าวัตถุดิบส่วนตัว',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  child: const Text('เข้าสู่ระบบ / สมัครสมาชิก'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // เมนูที่ Guest สามารถเข้าถึงได้
        Card(
          child: ListTile(
            leading: Icon(Icons.info_outline, color: theme.colorScheme.primary),
            title: Text('ข้อมูลอ้างอิง', style: textTheme.titleMedium),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.pushNamed(context, '/references'),
          ),
        ),
      ],
    );
  }
}
