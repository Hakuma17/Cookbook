// lib/screens/profile_screen.dart

import 'package:cookbook/screens/home_screen.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart'; // สำหรับดึงข้อมูลผู้ใช้
//import '../screens/edit_profile_screen.dart'; // TODO: สร้างหน้าแก้ไขโปรไฟล์
//import '../screens/allergies_screen.dart'; // TODO: สร้างหน้าเพิ่มวัตถุดิบที่แพ้

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _name;
  String? _email;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    // TODO: ดึง userId, profileName, profileImage จาก AuthService
    final prefs = await AuthService.isLoggedIn();
    // ตัวอย่างสมมติ
    setState(() {
      _name = 'Hakuma';
      _email = 'earthtyjoy11@gmail.com';
      _avatarUrl = null; // TODO: โหลด URL จริงจาก SharedPreferences หรือ API
    });
  }

  void _onLogout() async {
    await AuthService.logout();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('โปรไฟล์'),
        leading: BackButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Header ─────────────────────────────────────
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundImage: _avatarUrl != null
                        ? NetworkImage(_avatarUrl!)
                        : AssetImage('lib/assets/images/default_avatar.png')
                            as ImageProvider,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _name ?? '',
                    style: Theme.of(context).textTheme.headline6?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      );
                    },
                    child: const Text('แก้ไขโปรไฟล์'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── Settings List ───────────────────────────────
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('การตั้งค่าทั่วไป'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // TODO: นำทางไปหน้า SettingsScreen
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('เพิ่มวัตถุดิบที่แพ้'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('ออกจากระบบ'),
                    leading: const Icon(Icons.logout),
                    onTap: _onLogout,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── Allergies Summary ───────────────────────────
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'รายการอาหารที่แพ้',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    // TODO: สร้าง ListView หรือ Wrap แสดงรายการ Allergen แต่ละตัว
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: const [
                        Chip(label: Text('กุ้ง')),
                        Chip(label: Text('เต้าหู้')),
                        // เพิ่มรายการตามข้อมูลจริง
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // TODO: เพิ่ม UI ส่วนอื่นๆ ในอนาคต เช่น ประวัติการทำสูตรโปรด, สถิติ ฯลฯ
          ],
        ),
      ),
    );
  }
}

extension on TextTheme {
  get headline6 => null;
}
