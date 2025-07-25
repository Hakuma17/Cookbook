// lib/screens/profile_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cookbook/services/auth_service.dart';
import 'package:cookbook/services/api_service.dart';
import 'package:cookbook/widgets/custom_bottom_nav.dart';
import '../models/ingredient.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // --- State ---
  String _username = 'ผู้ใช้';
  String _email = '';
  String? _profileImageUrl;
  List<Ingredient> _allergyList = [];

  // ★ 1. เพิ่ม State สำหรับเก็บสถานะการล็อกอิน (เพื่อความสอดคล้อง)
  bool _isLoggedIn = false;
  late Future<void> _initFuture;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initFuture = _initialize();
  }

  Future<void> _initialize() async {
    if (!mounted) return;
    setState(() => _errorMessage = null);

    try {
      await Future.wait([
        _loadProfile(),
        _fetchAllergies(),
      ]);
    } on UnauthorizedException {
      await _handleLogout();
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted)
        setState(() => _errorMessage = 'เกิดข้อผิดพลาดในการโหลดข้อมูล');
    }
  }

  Future<void> _loadProfile() async {
    // ★ 2. ดึงสถานะ isLoggedIn มาพร้อมกับข้อมูล Profile
    final data = await AuthService.getLoginData();
    if (!mounted) return;

    final rawName = (data['profileName'] ?? 'ผู้ใช้').toString().trim();
    final rawEmail = (data['email'] ?? '').toString().trim();
    final rawImage = (data['profileImage'] ?? '').toString();

    String? fullImage;
    if (rawImage.isNotEmpty) {
      fullImage = rawImage.startsWith('http')
          ? rawImage
          : '${ApiService.baseUrl}$rawImage';
    }

    setState(() {
      // หน้านี้ถูกป้องกันด้วย AuthGuard ดังนั้น isLoggedIn จะเป็น true เสมอ
      _isLoggedIn = data['isLoggedIn'] ?? false;
      _username = rawName.isEmpty ? 'ผู้ใช้' : rawName;
      _email = rawEmail;
      _profileImageUrl = fullImage;
    });
  }

  Future<void> _fetchAllergies() async {
    final list = await ApiService.fetchAllergyIngredients();
    if (!mounted) return;

    final adjustedList = list.map((ing) {
      final imgUrl = ing.imageUrl;
      if (imgUrl.startsWith('http')) {
        return ing;
      }
      final fullUrl = '${ApiService.baseUrl}$imgUrl';
      return ing.copyWith(imageUrl: fullUrl);
    }).toList();

    setState(() => _allergyList = adjustedList);
  }

  Future<void> _handleLogout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
    }
  }

  Future<void> _navToEditProfile() async {
    final result = await Navigator.pushNamed(context, '/edit_profile');
    if (result == true && mounted) {
      setState(() {
        _profileImageUrl = null;
        _initFuture = _initialize();
      });
    }
  }

  Future<void> _navToAllergyScreen() async {
    await Navigator.pushNamed(context, '/allergy');
    if (mounted) {
      setState(() {
        _initFuture = _initialize();
      });
    }
  }

  // ★ 3. [แก้ไข] สร้างฟังก์ชันสำหรับจัดการการนำทางโดยเฉพาะ
  void _onNavItemTapped(int index) {
    if (index == 3) {
      // หน้าปัจจุบัน
      setState(() {
        _initFuture = _initialize(); // สั่ง refresh ข้อมูล
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
        Navigator.pushReplacementNamed(context, '/my_recipes');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('โปรไฟล์ของฉัน'),
      ),
      // ★ 4. [แก้ไข] ส่งค่า `isLoggedIn` เข้าไป และเรียกใช้ฟังก์ชันใหม่
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: 3,
        onItemSelected: _onNavItemTapped,
        isLoggedIn: _isLoggedIn,
      ),
      body: FutureBuilder(
          future: _initFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_errorMessage != null || snapshot.hasError) {
              return Center(child: Text(_errorMessage ?? 'เกิดข้อผิดพลาด'));
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildProfileHeader(theme, textTheme),
                  const SizedBox(height: 32),
                  _buildSettingsCard(theme),
                  const SizedBox(height: 32),
                  _buildAllergySection(theme, textTheme),
                ],
              ),
            );
          }),
    );
  }

  Widget _buildProfileHeader(ThemeData theme, TextTheme textTheme) {
    final imageUrlWithCacheBuster = _profileImageUrl != null
        ? '$_profileImageUrl?v=${DateTime.now().millisecondsSinceEpoch}'
        : null;

    final imageProvider = (imageUrlWithCacheBuster != null)
        ? NetworkImage(imageUrlWithCacheBuster)
        : const AssetImage('assets/images/default_avatar.png') as ImageProvider;

    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: theme.colorScheme.surfaceVariant,
          backgroundImage: imageProvider,
          onBackgroundImageError: (_, __) {},
        ),
        const SizedBox(height: 16),
        Text(_username, style: textTheme.headlineSmall),
        if (_email.isNotEmpty)
          Text(_email,
              style: textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        // ปุ่มแก้ไขโปรไฟล์อยู่ที่นี่ ถูกต้องตามแผนแล้ว
        TextButton(
          onPressed: _navToEditProfile,
          child: const Text('แก้ไขโปรไฟล์'),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(ThemeData theme) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text('การตั้งค่าบัญชี'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.pushNamed(context, '/settings'),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('จัดการวัตถุดิบที่แพ้'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _navToAllergyScreen,
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.logout, color: theme.colorScheme.error),
            title: Text('ออกจากระบบ',
                style: TextStyle(color: theme.colorScheme.error)),
            onTap: _handleLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildAllergySection(ThemeData theme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'รายการวัตถุดิบที่แพ้ (${_allergyList.length})',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _allergyList.isEmpty
            ? Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: Text('ยังไม่มีข้อมูล')),
              )
            : Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _allergyList.map((ing) {
                  return Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          ing.imageUrl,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 72,
                            height: 72,
                            color: theme.colorScheme.surfaceVariant,
                            child: const Icon(Icons.no_photography_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 72,
                        child: Text(
                          ing.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
      ],
    );
  }
}
