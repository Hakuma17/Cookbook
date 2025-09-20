// lib/screens/profile_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/safe_image.dart';
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
  String _profileInfo = ''; // ★ คำบรรยายใต้โปรไฟล์
  String? _profileImageUrl; // URL เต็มไว้แสดง (บัสต์แคชแล้ว)
  List<Ingredient> _allergyList = [];

  bool _isLoggedIn = false;
  late Future<void> _initFuture;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // ★ ดึงแคชก่อน → แล้วดึงสดมาทับเสมอ (ให้เห็นค่าล่าสุดแน่ ๆ)
    _initFuture = _initialize(forceServer: true);
  }

  // ───────────────── helpers ─────────────────
  String _safeStr(dynamic v) {
    if (v == null) return '';
    final s = v.toString().trim();
    const nullLikes = {'null', 'NULL', '(null)', 'undefined'};
    return nullLikes.contains(s) ? '' : s;
  }

  Map<String, dynamic> _asMap(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  Map<String, dynamic> _unwrapUser(dynamic raw) {
    var m = _asMap(raw);
    for (var i = 0; i < 4; i++) {
      if (m['data'] is Map) {
        m = _asMap(m['data']);
        continue;
      }
      if (m['user'] is Map) {
        m = _asMap(m['user']);
        continue;
      }
      if (m['me'] is Map) {
        m = _asMap(m['me']);
        continue;
      }
      break;
    }
    return m;
  }

  // ---- cache-buster ----
  String _bust(String url) {
    if (url.isEmpty) return url;
    final sep = url.contains('?') ? '&' : '?';
    return '$url${sep}t=${DateTime.now().millisecondsSinceEpoch}';
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
    // ★ ใช้ util กลางของ ApiService เพื่อแก้ host localhost/127.0.0.1 ให้เหมาะกับ emulator/web
    if (maybePath == null || maybePath.isEmpty) return null;
    final u = ApiService.normalizeUrl(maybePath);
    // บัสต์เฉพาะรูปผู้ใช้ (โฟลเดอร์ uploads/users) เพื่อไม่ไปรบกวน asset อื่น
    return u.contains('/uploads/users/') ? _bust(u) : u;
  }

  // ───────────────── init ─────────────────
  Future<void> _initialize({bool forceServer = false}) async {
    if (!mounted) return;
    setState(() => _errorMessage = null);

    try {
      await _loadProfile(); // แคช → ขึ้นภาพแรก
      await _fetchAllergies(); // แพ้อาหาร
      await _fetchProfileFromServer(force: true); // สด → ทับค่าล่าสุด
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

  Future<void> _loadProfile() async {
    final data = await AuthService.getLoginData();
    if (!mounted) return;

    final rawName =
        _safeStr(data['profileName'] ?? data['profile_name'] ?? 'ผู้ใช้');
    final rawEmail = _safeStr(data['email'] ?? '');
    final rawImage = _safeStr(data['profileImage'] ??
        data['profile_image'] ??
        data['path_imgProfile']);
    final rawInfo = _safeStr(data['profileInfo'] ?? data['profile_info']); // ★

    // ★ ให้ normalize + compose ผ่าน ApiService.normalizeUrl เสมอ
    final norm = _normalizeServerPath(rawImage) ?? rawImage;
    final full = _composeFullUrl(norm) ??
        (rawImage.startsWith('http') ? _bust(rawImage) : null);

    setState(() {
      _isLoggedIn = data['isLoggedIn'] ?? true;
      _username = rawName.isEmpty ? 'ผู้ใช้' : rawName;
      _email = rawEmail;
      _profileImageUrl = full;
      _profileInfo = rawInfo; // ★
    });
  }

  // ★ ดึงสดจากเซิร์ฟเวอร์แล้วทับ
  Future<void> _fetchProfileFromServer({bool force = false}) async {
    try {
      final me = await ApiService.fetchMyProfile();
      if (!mounted) return;

      final root = _unwrapUser(me);
      if (root.isEmpty) return;

      final serverName = _safeStr(root['profile_name'] ?? root['profileName']);
      final serverInfo = _safeStr(root['profile_info'] ?? root['profileInfo']);
      final serverEmail = _safeStr(root['email']);
      // รองรับทั้ง path และ url ที่กลับมา
      final rawImg = _safeStr(root['path_imgProfile'] ??
          root['profile_image'] ??
          root['avatar'] ??
          root['image_url']);
      final serverPath = _normalizeServerPath(rawImg) ?? rawImg;
      final showUrl = _composeFullUrl(serverPath) ??
          (rawImg.startsWith('http') ? _bust(rawImg) : null);

      setState(() {
        if (serverName.isNotEmpty) _username = serverName;
        if (serverInfo.isNotEmpty) _profileInfo = serverInfo;
        if (serverEmail.isNotEmpty) _email = serverEmail; // ★ อัปเดตอีเมลจาก BE
        if ((showUrl ?? '').isNotEmpty) _profileImageUrl = showUrl;
      });

      // ★ sync cache ท้องถิ่นเบาๆ (ไม่ยุ่ง isLoggedIn)
      await AuthService.updateLocalProfile(
        profileName: serverName,
        profileImage: serverPath,
        email: serverEmail,
        profileInfo: serverInfo,
      );
    } catch (_) {
      // เงียบไว้ ไม่ให้ UX สั่น
    }
  }

  Future<void> _fetchAllergies() async {
    final list = await ApiService.fetchAllergyIngredients();
    if (!mounted) return;

    final adjustedList = list.map((ing) {
      // ★ ให้ normalize ผ่าน ApiService.normalizeUrl เพื่อแก้ host
      final full = ApiService.normalizeUrl(
        _normalizeServerPath(ing.imageUrl) ?? ing.imageUrl,
      );
      return ing.copyWith(imageUrl: full);
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

    // ★ Optimistic: รับค่าที่แก้มาทันที
    if (result is Map && (result['updated'] == true)) {
      final newName = _safeStr(result['newName']);
      final newPath = _normalizeServerPath(_safeStr(result['newImagePath'])) ??
          _safeStr(result['newImagePath']);
      final rawNewUrl = _safeStr(result['newImageUrl']).isNotEmpty
          ? _safeStr(result['newImageUrl'])
          : (_composeFullUrl(newPath) ?? '');
      final busted = rawNewUrl.isEmpty ? '' : _bust(rawNewUrl);

      setState(() {
        if (newName.isNotEmpty) _username = newName;
        _profileImageUrl = (result['newImagePath'] == null &&
                _safeStr(result['newImageUrl']).isEmpty)
            ? null
            : (busted.isEmpty ? null : busted);
        if (result.containsKey('newProfileInfo')) {
          _profileInfo = _safeStr(result['newProfileInfo']);
        }
      });
    }

    // แล้วรีเฟรชสดอีกที (ตอนนี้ฝั่ง BE ก็ส่ง ?t=... มาแล้ว)
    setState(() {
      _initFuture = _initialize(forceServer: true);
    });
  }

  Future<void> _navToAllergyScreen() async {
    await Navigator.pushNamed(context, '/allergy');
    if (mounted) {
      setState(() {
        _initFuture = _initialize(forceServer: true);
      });
    }
  }

  void _onNavItemTapped(int index) {
    if (index == 3) {
      setState(() {
        _initFuture = _initialize(forceServer: true);
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
                          _initFuture = _initialize(forceServer: true);
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
            onRefresh: () => _initialize(forceServer: true),
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
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: .6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              _Avatar(url: _profileImageUrl),
              Positioned(
                bottom: 0,
                right: 8,
                child: _EditAvatarButton(onTap: _navToEditProfile),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _username,
            style:
                textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          if (_email.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              _email,
              style: textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
          if (_profileInfo.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _profileInfo,
              style: textTheme.bodyMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsCard(ThemeData theme) {
    final cs = theme.colorScheme;
    return Card(
      color: cs.secondaryContainer.withValues(alpha: .35),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.person_outline, color: cs.onSecondaryContainer),
            title: const Text('การตั้งค่าบัญชี'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.pushNamed(context, '/settings'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.warning_amber_outlined,
                color: cs.onSecondaryContainer),
            title: const Text('จัดการวัตถุดิบที่แพ้'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _navToAllergyScreen,
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.logout, color: cs.error),
            title: Text('ออกจากระบบ', style: TextStyle(color: cs.error)),
            onTap: _handleLogout,
          ),
        ],
      ),
    );
  }

  // รายการวัตถุดิบที่แพ้
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
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
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
                        ? SafeImage(
                            url: ing.imageUrl,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            error: Container(
                              width: 72,
                              height: 72,
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.no_photography_outlined),
                            ),
                          )
                        : Container(
                            width: 72,
                            height: 72,
                            color: theme.colorScheme.surfaceContainerHighest,
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

// ───────────── Avatar with white ring + shadow ─────────────
class _Avatar extends StatelessWidget {
  const _Avatar({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.surface,
          border: Border.all(color: Colors.white, width: 4),
        ),
        padding: const EdgeInsets.all(2),
        child: ClipOval(
          child: SafeImage(
            url: (url == null || url!.isEmpty)
                ? 'assets/images/default_avatar.png'
                : url!,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class _EditAvatarButton extends StatelessWidget {
  const _EditAvatarButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(Icons.edit, size: 18, color: cs.primary),
        ),
      ),
    );
  }
}
