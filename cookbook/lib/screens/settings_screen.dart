// lib/screens/settings_screen.dart
//
// 2025-08-10 – cohesive with recent app changes
// - Uses AuthService + Named Routes
// - Works for both Guest and Logged-in flows
// - SettingsStore toggle for Thai tokenization (with confirm dialog)
// - NEW: Theme mode picker (System / Light / Dark) powered by SettingsStore
// - Pull-to-refresh on this screen
// - BottomNav logic matches other screens
// - Better error handling & retry

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:cookbook/services/api_service.dart';
import 'package:cookbook/services/auth_service.dart';
import '../widgets/custom_bottom_nav.dart';
import '../stores/settings_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<void> _initFuture;

  bool _isLoggedIn = false;
  String? _email;
  String? _errorMessage;

  bool _savingTokenize = false; // guard while persisting toggle

  /* ───────────────── init ───────────────── */
  @override
  void initState() {
    super.initState();
    _initFuture = _initialize();
  }

  Future<void> _initialize() async {
    try {
      final loggedIn = await AuthService.isLoggedIn();
      if (!mounted) return;

      setState(() {
        _isLoggedIn = loggedIn;
        _errorMessage = null;
      });

      if (loggedIn) {
        final email = await AuthService.getEmail();
        if (!mounted) return;
        setState(() => _email = email);
      } else {
        setState(() => _email = null);
      }
    } on UnauthorizedException {
      await _handleLogout();
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'ไม่สามารถโหลดข้อมูลได้');
    }
  }

  /* ───────────── actions ───────────── */
  Future<void> _handleLogout() async {
    try {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (e) {
      _showSnack('ออกจากระบบไม่สำเร็จ: $e');
    }
  }

  void _onNavItemTapped(int index) {
    // Settings/Profile tab index = 3 (consistent with other screens)
    if (index == 3) {
      setState(() {
        _initFuture = _initialize(); // ✅ ไม่คืน Future ออกไป
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
        if (_isLoggedIn) {
          Navigator.pushReplacementNamed(context, '/my_recipes');
        } else {
          Navigator.pushNamed(context, '/login');
        }
        break;
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<bool?> _confirmToggleTokenize(BuildContext context, bool enable) {
    final title = enable ? 'เปิดการตัดคำภาษาไทย?' : 'ปิดการตัดคำภาษาไทย?';
    final msg = enable
        ? 'เมื่อเปิด ระบบจะพยายามตัดคำภาษาไทยให้ละเอียดขึ้น ทำให้ค้นหาแม่นยำขึ้น แต่ความเร็วอาจลดลงเล็กน้อย'
        : 'เมื่อปิด ระบบจะค้นหาแบบแยกคำด้วยช่องว่าง/จุลภาคเท่านั้น ทำงานเร็วขึ้น แต่คำไทยที่ติดกันอาจหาไม่เจอบางกรณี';
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
  }

  /* ───────────── build ───────────── */
  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('การตั้งค่า'),
        automaticallyImplyLeading: canPop,
      ),
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: 3,
        onItemSelected: _onNavItemTapped,
        isLoggedIn: _isLoggedIn,
      ),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_errorMessage != null || snap.hasError) {
            final msg = _errorMessage ?? 'เกิดข้อผิดพลาด';
            return _buildErrorState(msg);
          }

          // Pull-to-refresh for consistency with other screens
          return RefreshIndicator(
            onRefresh: () {
              final f = _initialize();
              setState(() => _initFuture = f);
              return f;
            },
            child: (_isLoggedIn)
                ? _buildLoggedInView(context)
                : _buildGuestView(context),
          );
        },
      ),
    );
  }

  /* ───────────── views ───────────── */

  Widget _buildLoggedInView(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildThemeCard(context), // ← NEW: Theme picker
        const SizedBox(height: 12),
        _buildSearchSettingsCard(context), // Thai tokenization
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.email_outlined,
                    color: theme.colorScheme.primary),
                title: Text('อีเมล', style: textTheme.titleMedium),
                subtitle: Text(
                  _email ?? 'ไม่พบข้อมูล',
                  style: textTheme.bodyMedium,
                ),
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

  Widget _buildGuestView(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildThemeCard(context), // ← NEW: Theme picker
        const SizedBox(height: 12),
        _buildSearchSettingsCard(context), // Thai tokenization
        const SizedBox(height: 16),
        Card(
          color: theme.colorScheme.primaryContainer.withOpacity(0.5),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'เข้าร่วมกับเรา',
                  style: textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'เพื่อบันทึกสูตรโปรดและสร้างตะกร้าวัตถุดิบส่วนตัว',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
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
        Card(
          clipBehavior: Clip.antiAlias,
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

  /* ───────────── parts ───────────── */

  // NEW: Theme Mode picker (System / Light / Dark)
  Widget _buildThemeCard(BuildContext context) {
    final theme = Theme.of(context);
    final store = context.watch<SettingsStore>();
    final mode = store.themeMode;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.brightness_6, color: theme.colorScheme.primary),
            title: const Text('ธีมแอป'),
            subtitle: Text(
              'เลือกโหมดการแสดงผลของแอป (สว่าง / มืด หรือ ตามระบบ)',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('ตามระบบ'),
                  icon: Icon(Icons.brightness_auto),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('สว่าง'),
                  icon: Icon(Icons.light_mode),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('มืด'),
                  icon: Icon(Icons.dark_mode),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (set) =>
                  context.read<SettingsStore>().setThemeMode(set.first),
            ),
          ),
        ],
      ),
    );
  }

  // Thai tokenization card
  Widget _buildSearchSettingsCard(BuildContext context) {
    final theme = Theme.of(context);
    final store = context.watch<SettingsStore>();
    final enabled = store.searchTokenizeEnabled;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.search, color: theme.colorScheme.primary),
            title: const Text('การค้นหา'),
            subtitle: Text(
              'ตั้งค่าการค้นหาเมนูและวัตถุดิบของคุณ',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const Divider(height: 1),
          SwitchListTile.adaptive(
            title: const Text('ตัดคำภาษาไทย (ทดลอง)'),
            subtitle: Text(
              enabled
                  ? 'เปิดการตัดคำ: ค้นหาไทยแม่นขึ้น แต่ความเร็วอาจลดลงเล็กน้อย'
                  : 'ปิดการตัดคำ: แยกคำด้วยช่องว่าง/จุลภาค เร็วขึ้น',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            value: enabled,
            onChanged: _savingTokenize
                ? null
                : (next) async {
                    final ok = await _confirmToggleTokenize(context, next);
                    if (ok != true) return;

                    setState(() => _savingTokenize = true);
                    try {
                      await context
                          .read<SettingsStore>()
                          .setSearchTokenizeEnabled(next);
                      if (!mounted) return;
                      _showSnack(next ? 'เปิดการตัดคำแล้ว' : 'ปิดการตัดคำแล้ว');
                    } catch (_) {
                      if (!mounted) return;
                      _showSnack('ไม่สามารถบันทึกการตั้งค่าได้', error: true);
                    } finally {
                      if (mounted) setState(() => _savingTokenize = false);
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              Text(
                msg,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _initFuture = _initialize();
                  });
                },
                child: const Text('ลองอีกครั้ง'),
              ),
            ],
          ),
        ),
      );
}
