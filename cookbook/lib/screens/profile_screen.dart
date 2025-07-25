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

  // ✅ 1. จัดการ State การโหลดเริ่มต้นด้วย Future เดียว
  late Future<void> _initFuture;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initFuture = _initialize();
  }

  // ✅ 2. รวมการโหลดข้อมูลเริ่มต้นไว้ในที่เดียว และปรับปรุง Error Handling
  Future<void> _initialize() async {
    // ❌ ลบการเช็คสิทธิ์ใน initState ออก เพราะเป็นหน้าที่ของ Router (AuthGuard)

    if (!mounted) return;
    setState(() => _errorMessage = null);

    try {
      // โหลดข้อมูล Profile และ Allergy พร้อมกัน
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
    final data = await AuthService.getLoginData();
    if (!mounted) return;

    final rawName = (data['profileName'] ?? 'ผู้ใช้').toString().trim();
    final rawEmail = (data['email'] ?? '').toString().trim();
    final rawImage = (data['profileImage'] ?? '').toString();

    // Note: การต่อ String แบบนี้ อาจย้ายไปไว้ใน Model หรือ Utility function ได้ในอนาคต
    String? fullImage;
    if (rawImage.isNotEmpty) {
      fullImage = rawImage.startsWith('http')
          ? rawImage
          : '${ApiService.baseUrl}$rawImage';
    }

    setState(() {
      _username = rawName.isEmpty ? 'ผู้ใช้' : rawName;
      _email = rawEmail;
      _profileImageUrl = fullImage;
    });
  }

  Future<void> _fetchAllergies() async {
    final list = await ApiService.fetchAllergyIngredients();
    if (!mounted) return;

    // --- ⭐️ จุดที่แก้ไขตามภาพที่ส่งมา ⭐️ ---
    // สร้าง List ใหม่โดยใช้ copyWith เพื่อเปลี่ยน imageUrl ให้เป็น URL เต็ม
    final adjustedList = list.map((ing) {
      final imgUrl = ing.imageUrl;
      if (imgUrl.startsWith('http')) {
        return ing; // ถ้าเป็น URL เต็มอยู่แล้ว ก็ใช้ object เดิมได้เลย
      }
      final fullUrl = '${ApiService.baseUrl}$imgUrl';
      // สร้าง object ใหม่ด้วย copyWith
      return ing.copyWith(imageUrl: fullUrl);
    }).toList();
    // ------------------------------------

    setState(() => _allergyList = adjustedList);
  }

  Future<void> _handleLogout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
    }
  }

  // ✅ 3. ปรับปรุงการนำทางให้ใช้ Named Routes
  Future<void> _navToEditProfile() async {
    final result = await Navigator.pushNamed(context, '/edit_profile');
    // ถ้าหน้า EditProfile pop กลับมาพร้อมค่า true (คือมีการ save สำเร็จ)
    if (result == true && mounted) {
      // โหลดข้อมูลโปรไฟล์ใหม่
      setState(() {
        _profileImageUrl = null;
        _initFuture = _initialize();
      });
    }
  }

  Future<void> _navToAllergyScreen() async {
    await Navigator.pushNamed(context, '/allergy');
    // โหลดข้อมูลใหม่เมื่อกลับมา
    if (mounted) {
      setState(() {
        _initFuture = _initialize();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 4. ลบ Manual Responsive Calculation และใช้ Theme
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('โปรไฟล์ของฉัน'),
      ),
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: 3,
        onItemSelected: (i) {
          if (i == 3) {
            setState(() => _initFuture = _initialize());
            return;
          }
          const routes = ['/home', '/search', '/my_recipes', null];
          if (routes[i] != null)
            Navigator.pushReplacementNamed(context, routes[i]!);
        },
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

  // ✅ 5. แยก UI section ออกมาเป็น Widget Builder และใช้ Theme
  Widget _buildProfileHeader(ThemeData theme, TextTheme textTheme) {
    // เพิ่ม cache-busting query string เพื่อให้รูป update ทันที
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
          onBackgroundImageError: (_, __) {}, // Handle network image error
        ),
        const SizedBox(height: 16),
        Text(_username, style: textTheme.headlineSmall),
        if (_email.isNotEmpty)
          Text(_email,
              style: textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        TextButton(
          onPressed: _navToEditProfile,
          child: const Text('แก้ไขโปรไฟล์'),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(ThemeData theme) {
    return Card(
      // Card จะดึงสไตล์ (shape, elevation) มาจาก CardTheme ใน main.dart
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
