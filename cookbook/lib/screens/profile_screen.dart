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
  String? _profileImageUrl; // URL เต็มไว้แสดง
  List<Ingredient> _allergyList = [];

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
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'เกิดข้อผิดพลาดในการโหลดข้อมูล');
      }
    }
  }

  // ---- path utils ----
  String? _normalizeServerPath(String? p) {
    if (p == null || p.isEmpty) return null;
    var s = p.replaceAll('\\', '/');
    final idx = s.indexOf('/uploads/');
    if (idx >= 0) s = s.substring(idx);
    final q = s.indexOf('?');
    if (q >= 0) s = s.substring(0, q);
    return s;
  }

  String? _composeFullUrl(String? maybePath) {
    if (maybePath == null || maybePath.isEmpty) return null;
    final p = maybePath.replaceAll('\\', '/');
    if (p.startsWith('http')) return p;
    try {
      final rel = p.startsWith('/') ? p.substring(1) : p;
      return Uri.parse(ApiService.baseUrl).resolve(rel).toString();
    } catch (_) {
      return maybePath;
    }
  }

  Future<void> _loadProfile() async {
    final data = await AuthService.getLoginData();
    if (!mounted) return;

    final rawName = (data['profileName'] ?? 'ผู้ใช้').toString().trim();
    final rawEmail = (data['email'] ?? '').toString().trim();
    final rawImage = (data['profileImage'] ?? '').toString();

    final norm = _normalizeServerPath(rawImage);
    final full = _composeFullUrl(norm);

    setState(() {
      _isLoggedIn = data['isLoggedIn'] ?? true;
      _username = rawName.isEmpty ? 'ผู้ใช้' : rawName;
      _email = rawEmail;
      _profileImageUrl = full;
    });
  }

  Future<void> _fetchAllergies() async {
    final list = await ApiService.fetchAllergyIngredients();
    if (!mounted) return;

    final adjustedList = list.map((ing) {
      final full = _composeFullUrl(_normalizeServerPath(ing.imageUrl));
      return ing.copyWith(imageUrl: full ?? '');
    }).toList();

    setState(() => _allergyList = adjustedList);
  }

  Future<void> _handleLogout() async {
    if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await AuthService.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
    }
  }

  Future<void> _navToEditProfile() async {
    final result = await Navigator.pushNamed(context, '/edit_profile');
    if (!mounted) return;

    // ★ รองรับ Optimistic UI จากหน้าก่อนหน้า
    if (result is Map && (result['updated'] == true)) {
      final newName = (result['newName'] ?? '').toString();
      final newPath =
          _normalizeServerPath((result['newImagePath'] ?? '').toString());
      final newUrl = (result['newImageUrl'] is String &&
              (result['newImageUrl'] as String).isNotEmpty)
          ? result['newImageUrl'] as String
          : _composeFullUrl(newPath);

      setState(() {
        if (newName.isNotEmpty) _username = newName;
        _profileImageUrl = newUrl; // ใส่ cache-buster มาด้วยอยู่แล้ว (ถ้าให้มา)
      });
    }

    // จะให้รีเฟรชจากเซิร์ฟเวอร์จริง ๆ ด้วยก็ได้ (แต่ UI เห็นผลทันทีแล้ว)
    setState(() {
      _initFuture = _initialize();
    });
  }

  Future<void> _navToAllergyScreen() async {
    await Navigator.pushNamed(context, '/allergy');
    if (mounted) {
      setState(() {
        _initFuture = _initialize();
      });
    }
  }

  void _onNavItemTapped(int index) {
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
        Navigator.pushReplacementNamed(context, '/my_recipes');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('โปรไฟล์ของฉัน')),
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: 3,
        onItemSelected: _onNavItemTapped,
        isLoggedIn: _isLoggedIn,
      ),
      body: FutureBuilder(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _allergyList.isEmpty &&
              _profileImageUrl == null &&
              _email.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_errorMessage != null || snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_errorMessage ?? 'เกิดข้อผิดพลาด',
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _initFuture = _initialize();
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('ลองอีกครั้ง'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _initialize,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme, TextTheme textTheme) {
    // cache-buster ถ้าต้องการ สามารถเติมจากฝั่ง Edit มาแล้วใน result
    final provider = (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
        ? NetworkImage(_profileImageUrl!)
        : const AssetImage('assets/images/default_avatar.png') as ImageProvider;

    return Column(
      children: [
        Semantics(
          label: 'รูปโปรไฟล์ของ $_username',
          image: true,
          child: CircleAvatar(
            radius: 50,
            backgroundColor: theme.colorScheme.surfaceVariant,
            backgroundImage: provider,
            onBackgroundImageError: (_, __) {}, // กัน error รูป
          ),
        ),
        const SizedBox(height: 16),
        Text(_username, style: textTheme.headlineSmall),
        if (_email.isNotEmpty)
          Text(
            _email,
            style: textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        TextButton(
          onPressed: _navToEditProfile,
          child: const Text('แก้ไขโปรไฟล์'),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(ThemeData theme) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        if (_allergyList.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: Text('ยังไม่มีข้อมูล')),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _allergyList.map((ing) {
              final hasUrl = ing.imageUrl.isNotEmpty;
              return Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: hasUrl
                        ? Image.network(
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
                          )
                        : Container(
                            width: 72,
                            height: 72,
                            color: theme.colorScheme.surfaceVariant,
                            alignment: Alignment.center,
                            child: const Icon(Icons.no_photography_outlined),
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
