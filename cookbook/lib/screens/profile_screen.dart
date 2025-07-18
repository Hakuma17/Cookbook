// lib/screens/profile_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cookbook/screens/edit_profile_screen.dart';
import 'package:cookbook/screens/allergy_screen.dart';
import 'package:cookbook/services/auth_service.dart';
import 'package:cookbook/services/api_service.dart';
import 'package:cookbook/widgets/custom_bottom_nav.dart';
import '../models/ingredient.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _username = 'ผู้ใช้';
  String _email = '';
  String? _profileImageUrl;
  List<Ingredient> _allergyList = [];
  bool _loadingProfile = true;
  bool _loadingAllergy = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ok = await AuthService.checkAndRedirectIfLoggedOut(context);
      if (ok) await _loadProfile();
    });
    _fetchAllergies();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await AuthService.getLoginData();
      final rawName = (data['profileName'] ?? 'ผู้ใช้').toString().trim();
      final rawEmail = (data['email'] ?? '').toString().trim();
      final rawImage = (data['profileImage'] ?? '').toString();

      String? fullImage;
      if (rawImage.isNotEmpty) {
        fullImage = rawImage.startsWith('http')
            ? rawImage
            : '${ApiService.baseUrl}$rawImage';
      }

      if (!mounted) return;
      setState(() {
        _username = rawName;
        _email = rawEmail;
        _profileImageUrl = fullImage;
        _loadingProfile = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดข้อมูลโปรไฟล์ไม่สำเร็จ: $e')));
      setState(() => _loadingProfile = false);
    }
  }

  Future<void> _fetchAllergies() async {
    try {
      final list = await ApiService.fetchAllergyIngredients()
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;

      final adjusted = list.map((ing) {
        final img = ing.imageUrl;
        final full = img.startsWith('http') ? img : '${ApiService.baseUrl}$img';
        return Ingredient(
          id: ing.id,
          name: ing.name,
          imageUrl: full,
          category: ing.category,
        );
      }).toList();

      setState(() => _allergyList = adjusted);
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เซิร์ฟเวอร์ไม่ตอบสนอง ลองใหม่ภายหลัง')),
        );
      }
    } on SocketException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่มีการเชื่อมต่ออินเทอร์เน็ต')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ดึงรายการแพ้ไม่สำเร็จ: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingAllergy = false);
    }
  }

  Future<void> _logout() async {
    try {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ไม่สามารถออกจากระบบได้: $e')));
    }
  }

  Widget _buildAvatar(double size) {
    const placeholder = AssetImage('assets/images/default_avatar.png');
    final url = _profileImageUrl;

    return ClipOval(
      child: url != null && url.isNotEmpty
          ? Image.network(
              '$url?${DateTime.now().millisecondsSinceEpoch}',
              width: size,
              height: size,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : SizedBox(
                      width: size,
                      height: size,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
              errorBuilder: (_, __, ___) =>
                  Image(image: placeholder, width: size, height: size),
            )
          : Image(image: placeholder, width: size, height: size),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      /* ───── responsive metrics ───── */
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;

      double clamp(double v, double min, double max) =>
          v < min ? min : (v > max ? max : v);

      final pad = clamp(w * 0.05, 16, 32); // list padding
      final avatar = clamp(w * 0.28, 80, 140); // avatar size
      final titleSz = clamp(w * 0.055, 18, 26); // username font
      final subSz = clamp(w * 0.035, 12, 16); // email font
      final secHd = clamp(w * 0.042, 14, 18); // section header
      final chipImg = clamp(w * 0.16, 56, 72); // allergy image
      final chipFont = clamp(w * 0.033, 11, 14); // allergy text
      final gapL = h * 0.04; // ~32
      final gapM = h * 0.03; // ~24
      final gapS = h * 0.02; // ~16

      return Scaffold(
        appBar: AppBar(
          title: const Text('โปรไฟล์ของฉัน'),
          centerTitle: true,
        ),
        /* ───── bottom-nav: ใช้ widget กลาง — ไม่ซ้อน Navigator ซ้ำ ───── */
        bottomNavigationBar: CustomBottomNav(
          selectedIndex: 3,
          isLoggedIn: true,
          onItemSelected: (i) async {
            if (i == 3) {
              await _loadProfile();
              await _fetchAllergies();
            }
            // Navigation ด้านในจัดการแล้วใน CustomBottomNav
          },
        ),
        body: _loadingProfile
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: _buildAvatar(avatar)),
                    SizedBox(height: gapS),
                    Center(
                      child: Text(
                        _username,
                        style: TextStyle(
                            fontSize: titleSz, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (_email.isNotEmpty)
                      Center(
                        child: Text(_email,
                            style:
                                TextStyle(color: Colors.grey, fontSize: subSz)),
                      ),
                    Center(
                      child: TextButton(
                        onPressed: () async {
                          final updated = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const EditProfileScreen()),
                          );
                          if (updated == true && mounted) {
                            setState(() {
                              _loadingProfile = true;
                              _profileImageUrl = null;
                            });
                            await _loadProfile();
                          }
                        },
                        child: const Text('แก้ไขโปรไฟล์',
                            style: TextStyle(color: Color(0xFFFF9B05))),
                      ),
                    ),
                    SizedBox(height: gapL),
                    /* ───── setting card ───── */
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Column(
                        children: [
                          ListTile(
                            title: const Text('การตั้งค่าทั่วไป'),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () =>
                                Navigator.pushNamed(context, '/settings'),
                          ),
                          const Divider(),
                          ListTile(
                            title: const Text('เพิ่มวัตถุดิบที่แพ้'),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () async {
                              final updated = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const AllergyScreen()),
                              );
                              if (updated == true && mounted) {
                                setState(() {
                                  _loadingAllergy = true;
                                  _allergyList = [];
                                });
                                await _fetchAllergies();
                              }
                            },
                          ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.logout),
                            title: const Text('ออกจากระบบ'),
                            onTap: _logout,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: gapL),
                    Text(
                      'รายการวัตถุดิบที่แพ้ (${_allergyList.length})',
                      style: TextStyle(
                          fontSize: secHd, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: gapS),
                    _loadingAllergy
                        ? const Center(child: CircularProgressIndicator())
                        : _allergyList.isEmpty
                            ? const Text('ยังไม่มีวัตถุดิบที่แพ้',
                                style: TextStyle(color: Colors.grey))
                            : Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: _allergyList.map((ing) {
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(
                                          '${ing.imageUrl}?${DateTime.now().millisecondsSinceEpoch}',
                                          width: chipImg,
                                          height: chipImg,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (_, child,
                                                  progress) =>
                                              progress == null
                                                  ? child
                                                  : SizedBox(
                                                      width: chipImg,
                                                      height: chipImg,
                                                      child: const Center(
                                                        child:
                                                            CircularProgressIndicator(
                                                                strokeWidth: 2),
                                                      ),
                                                    ),
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.broken_image),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      SizedBox(
                                        width: chipImg,
                                        child: Text(
                                          ing.name,
                                          style: TextStyle(fontSize: chipFont),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                  ],
                ),
              ),
      );
    });
  }
}
