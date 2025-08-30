// lib/screens/edit_profile_screen.dart
//
// 2025-08-25 — Google-linked only button + polished UI
// • แสดงปุ่ม “คืนค่าโปรไฟล์จาก Google” เฉพาะบัญชีที่เชื่อม Google (google_id ไม่ว่าง)
// • ปรับปุ่มเป็นการ์ดสวยๆ พร้อมไอคอน Google และคำอธิบายย่อ
// • ปรับ overlay แยกข้อความระหว่าง "กำลังบันทึก..." กับ "กำลังดึงข้อมูลจาก Google..."
//
// ต้องมีไฟล์: assets/icons/google.png, assets/images/default_avatar.png
//
// 2025-08-29 — FIX & ENHANCE
// • รักษา google_id ใน local login หลัง save (ถ้า AuthService.saveLogin รองรับ googleId ส่งไปด้วย)
// • ถ้าไม่มี google_id ใน local → พยายาม signInSilently() เทียบอีเมล เพื่อตัดสินว่าเชื่อม Google
// • เพิ่มช่องแก้ไข “ข้อมูลแสดงใต้โปรไฟล์” (profile_info / profileInfo) + validate

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cookbook/screens/crop_avatar_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

const int kNameUiMax = 25;
const int kNameDbMaxBytes = 100;

// ★ ใหม่: ลิมิตสำหรับ “ข้อมูลแสดงใต้โปรไฟล์”
const int kInfoUiMax = 160; // ตัวอักษรบน UI
const int kInfoDbMaxBytes = 1000; // ไบต์ที่ยอมรับส่งขึ้นหลังบ้าน

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // ───── Form state ─────
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  // ★ ใหม่: ช่องข้อมูลใต้โปรไฟล์
  final _infoCtrl = TextEditingController();

  // ───── Avatar state ─────
  String? _currentImageUrl; // Full URL for display (e.g., https://...)
  String? _currentImagePathRaw; // Path for backend (e.g., uploads/...)
  File? _newImageFile; // Cropped file ready for upload

  // ───── Loading flags ─────
  bool _bootLoading = true;
  bool _isLoading = false; // กำลังทำงานอยู่ (save/restore)
  String? _blockingText; // บล็อกชั่วคราว (เช่น เปิด crop)
  String? _busyText; // ข้อความบน overlay ระหว่างงานยาว ๆ

  // ───── Helpers ─────
  late final _ImagePickerHelper _picker;
  final _googleSignIn = GoogleSignIn();

  // ───── Initial snapshot ─────
  String _initialName = '';
  String _initialImagePathRaw = '';
  // ★ ใหม่: เก็บสแน็ปช็อต info
  String _initialInfo = '';

  // ───── Google link flag ─────
  bool _isGoogleLinked = false; // โชว์ปุ่มเฉพาะเมื่อ true

  @override
  void initState() {
    super.initState();
    _picker = _ImagePickerHelper(context: context, onBlocking: _setBlocking);
    _nameCtrl.addListener(() => setState(() {}));
    _infoCtrl.addListener(() => setState(() {})); // ★
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _infoCtrl.dispose(); // ★
    super.dispose();
  }

  // ───────────────────────────── Utilities ─────────────────────────────
  String? _normalizeServerPath(String? p) {
    if (p == null || p.isEmpty) return null;

    // หากเป็นลิงก์ภายนอก (ไม่มี /uploads/) ให้ถือว่าไม่มี path ฝั่งเซิร์ฟเวอร์เรา
    final isExternalUrl = p.startsWith('http://') || p.startsWith('https://');
    if (isExternalUrl && !p.contains('/uploads/')) return null;

    var s = p.replaceAll('\\', '/');
    final idx = s.indexOf('/uploads/');
    if (idx >= 0) s = s.substring(idx);

    final q = s.indexOf('?');
    if (q >= 0) s = s.substring(0, q);

    if (s.startsWith('/')) s = s.substring(1);

    return s.isEmpty ? null : s;
  }

  String? _composeFullUrl(String? maybePath) {
    if (maybePath == null || maybePath.isEmpty) return null;
    final p = maybePath.replaceAll('\\', '/');
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    try {
      final rel = p.startsWith('/') ? p.substring(1) : p;
      return Uri.parse(ApiService.baseUrl).resolve(rel).toString();
    } catch (_) {
      return maybePath;
    }
  }

  // ───────────────────────────── Data Load & Actions ─────────────────────────────
  Future<void> _loadUserProfile() async {
    try {
      final data = await AuthService.getLoginData();
      if (!mounted) return;

      // ชื่อ + รูป
      final rawName = (data['profileName'] ?? '').toString().trim();
      final rawImage = (data['profileImage'] ?? '').toString();
      final normPath = _normalizeServerPath(rawImage);
      final String? uiUrl =
          rawImage.startsWith('http') ? rawImage : _composeFullUrl(normPath);

      // ★ ใหม่: ข้อมูลใต้โปรไฟล์ (รองรับทั้ง profileInfo และ profile_info)
      final rawInfo =
          ((data['profileInfo'] ?? data['profile_info']) ?? '').toString();

      // ตรวจว่าเชื่อม Google ไหม (รองรับทั้ง google_id และ googleId)
      final rawGoogleId =
          ((data['google_id'] ?? data['googleId']) ?? '').toString().trim();

      bool linked = rawGoogleId.isNotEmpty &&
          rawGoogleId.toLowerCase() != 'null' &&
          rawGoogleId.toLowerCase() != 'none' &&
          rawGoogleId != '0';

      // ★ เสริมความทน: ถ้า local ไม่มี google_id แต่เคยลงชื่อด้วย Google ในเครื่องนี้ ให้แสดงปุ่มได้
      if (!linked) {
        try {
          final acc = await _googleSignIn.signInSilently();
          final email = (data['email'] ?? '').toString().toLowerCase();
          if (acc != null && acc.email.toLowerCase() == email) {
            linked = true;
          }
        } catch (_) {
          // เงียบไว้ ไม่รบกวน UX
        }
      }

      setState(() {
        _nameCtrl.text = rawName;
        _infoCtrl.text = rawInfo; // ★
        _currentImagePathRaw = normPath;
        _currentImageUrl = uiUrl;

        _initialName = _nameCtrl.text;
        _initialImagePathRaw = _currentImagePathRaw ?? '';
        _initialInfo = _infoCtrl.text; // ★

        _isGoogleLinked = linked;
        _bootLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('ไม่สามารถโหลดโปรไฟล์ได้: $e');
      setState(() => _bootLoading = false);
    }
  }

  void _setBlocking(String? text) {
    if (!mounted) return;
    setState(() => _blockingText = text);
  }

  Future<void> _pickImage() async {
    final file = await _picker.showPickerSheet();
    if (file == null || !mounted) return;

    _setBlocking('กำลังเตรียมรูปภาพ...');
    try {
      final ready = await _picker.enforceConstraints(file);
      setState(() => _newImageFile = ready);
    } catch (e) {
      _showSnack('เตรียมรูปภาพไม่สำเร็จ: $e');
    } finally {
      _setBlocking(null);
    }
  }

  void _removeImage() {
    setState(() {
      _newImageFile = null;
      _currentImagePathRaw = null;
      _currentImageUrl = null;
    });
  }

  // ★ คืนค่าจาก Google — แสดงเฉพาะบัญชีที่เชื่อม Google
  Future<void> _restoreFromGoogle() async {
    setState(() {
      _isLoading = true;
      _busyText = 'กำลังดึงข้อมูลจาก Google...';
    });
    try {
      // พยายาม sign-in แบบเงียบก่อน ถ้าไม่ได้ ให้เปิดหน้าต่างลงชื่อเข้าใช้
      var account = await _googleSignIn.signInSilently();
      account ??= await _googleSignIn.signIn();

      if (account == null) {
        _showSnack('ไม่สามารถดึงข้อมูลจาก Google ได้ กรุณาลองอีกครั้ง');
        return;
      }
      final googleName = account.displayName ?? '';
      final googleImage = account.photoUrl;

      setState(() {
        _nameCtrl.text = googleName;
        _newImageFile = null; // ล้างไฟล์ที่เพิ่งครอปไว้
        _currentImageUrl = googleImage; // ใช้รูปจาก Google แสดงผล
        _currentImagePathRaw = null; // รูปภายนอก ไม่มี path บนเซิร์ฟเวอร์
      });
      _showSnack('คืนค่าข้อมูลจาก Google สำเร็จ', isError: false);
    } catch (e) {
      _showSnack('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _busyText = null;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final newName = _nameCtrl.text.trim();
    final newInfo = _infoCtrl.text.trim(); // ★
    final login = await AuthService.getLoginData();
    final oldName = (login['profileName'] ?? '').toString();
    final oldImgRaw =
        _normalizeServerPath((login['profileImage'] ?? '').toString()) ?? '';
    final oldInfo =
        ((login['profileInfo'] ?? login['profile_info']) ?? '').toString(); // ★

    final noChange = newName == oldName &&
        newInfo == oldInfo && // ★
        _newImageFile == null &&
        ((_currentImagePathRaw ?? '') == oldImgRaw);
    if (noChange) {
      _showSnack('ไม่มีการเปลี่ยนแปลง', isError: false);
      return;
    }

    setState(() {
      _isLoading = true;
      _busyText = 'กำลังบันทึก...';
    });

    try {
      String? serverPath = _currentImagePathRaw;
      String? uiUrl;

      if (_newImageFile != null) {
        final constrained = await _picker.enforceConstraints(_newImageFile!);
        final uploaded = await ApiService.uploadProfileImage(constrained);
        serverPath = _normalizeServerPath(uploaded);
        final base = _composeFullUrl(serverPath);
        if (base != null) {
          final sep = base.contains('?') ? '&' : '?';
          uiUrl = '$base${sep}t=${DateTime.now().millisecondsSinceEpoch}';
        }
      }

      // ★ ส่ง profileInfo ขึ้นหลังบ้านด้วย (ถ้า API รองรับ)
      final updated = await ApiService.updateProfile(
        profileName: newName,
        imageUrl: serverPath ?? '',
        profileInfo: newInfo, // ← เพิ่มพารามิเตอร์ (optional)
      );

      final originalImage = (login['profileImage'] ?? '').toString();
      final isOriginalExternal = originalImage.startsWith('http') &&
          !originalImage.contains('/uploads/');

      String finalPathToSave;
      String? finalShowUrl;

      if (isOriginalExternal &&
          _newImageFile == null &&
          _currentImageUrl != null) {
        finalPathToSave = originalImage;
        finalShowUrl = originalImage;
      } else {
        final serverResponsePath =
            _normalizeServerPath(updated['image_url'] ?? serverPath) ?? '';
        finalPathToSave = serverResponsePath;
        finalShowUrl = uiUrl ?? _composeFullUrl(finalPathToSave);
      }

      // ★ รักษา google_id เดิมไว้ใน local (ถ้า saveLogin รองรับ googleId ให้ส่งต่อ)
      final preservedGoogleId =
          ((login['google_id'] ?? login['googleId']) ?? '').toString();

      await AuthService.saveLogin(
        userId: login['userId'],
        profileName: updated['profile_name'] ?? newName,
        profileImage: finalPathToSave,
        email: login['email'],
        // ↓ NOTE:
        // ถ้าโปรเจกต์ของคุณรองรับพารามิเตอร์เสริม ให้เปิดบรรทัดนี้ใน AuthService.saveLogin:
        // googleId: preservedGoogleId,
        // profileInfo: updated['profile_info'] ?? newInfo,
      );

      if (!mounted) return;
      _showSnack('บันทึกโปรไฟล์เรียบร้อยแล้ว', isError: false);

      setState(() {
        _newImageFile = null;
        _currentImagePathRaw =
            finalPathToSave.startsWith('http') ? null : finalPathToSave;
        _currentImageUrl = finalShowUrl;
        _initialName = newName;
        _initialImagePathRaw = _currentImagePathRaw ?? '';
        _initialInfo = newInfo; // ★
        // ★ คงสถานะการเชื่อม Google เอาไว้ ไม่ให้ปุ่มหายทันทีหลังบันทึก
        if (preservedGoogleId.isNotEmpty &&
            preservedGoogleId.toLowerCase() != 'null' &&
            preservedGoogleId != '0') {
          _isGoogleLinked = true;
        }
      });

      Navigator.pop(context, {
        'updated': true,
        'newName': newName,
        'newImagePath': _currentImagePathRaw,
        'newImageUrl': finalShowUrl,
        'newProfileInfo': newInfo, // ★ ส่งกลับให้หน้าโปรไฟล์ใช้ได้ทันที
      });
    } on UnauthorizedException {
      _showSnack('เซสชันหมดอายุ กรุณาลงชื่อเข้าใช้อีกครั้ง');
      await AuthService.logout();
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _busyText = null;
        });
      }
    }
  }

  // ─────────────────────────────── Helpers ───────────────────────────────
  void _showSnack(String m, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor:
          isError ? Theme.of(context).colorScheme.error : Colors.green[600],
    ));
  }

  bool get _hasChanges {
    final nameChanged = _nameCtrl.text.trim() != _initialName.trim();
    final infoChanged = _infoCtrl.text.trim() != _initialInfo.trim(); // ★
    final imageChanged = _newImageFile != null ||
        (_currentImagePathRaw ?? '') != _initialImagePathRaw;
    return nameChanged || infoChanged || imageChanged; // ★ รวม info
  }

  Future<bool> _confirmDiscardIfNeeded() async {
    if (!_hasChanges) return true;
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('มีข้อมูลที่ยังไม่ได้บันทึก'),
            content:
                const Text('คุณต้องการออกโดยไม่บันทึกการเปลี่ยนแปลงหรือไม่?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('ยกเลิก')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('ออก')),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildAvatarWidget() {
    if (_newImageFile != null) {
      return Image.file(
        _newImageFile!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) =>
            Image.asset('assets/images/default_avatar.png', fit: BoxFit.cover),
      );
    }
    if (_currentImageUrl?.isNotEmpty ?? false) {
      return Image.network(
        _currentImageUrl!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        loadingBuilder: (c, w, p) => p == null
            ? w
            : const Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))),
        errorBuilder: (_, __, ___) =>
            Image.asset('assets/images/default_avatar.png', fit: BoxFit.cover),
      );
    }
    return Image.asset('assets/images/default_avatar.png', fit: BoxFit.cover);
  }

  Widget _buildLoadingOverlay({String? text}) {
    return Container(
      color: Colors.black.withOpacity(.35),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (text != null) ...[
              const SizedBox(height: 12),
              Text(text,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }

  // ปุ่ม “คืนค่าโปรไฟล์จาก Google” แบบการ์ด
  Widget _buildGoogleRestoreCard() {
    if (!_isGoogleLinked) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final onSurfaceVar = theme.colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      label: 'คืนค่าโปรไฟล์จาก Google',
      child: InkWell(
        onTap: _isLoading ? null : _restoreFromGoogle,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // ไอคอน Google จาก assets
              Image.asset(
                'assets/icons/google.png',
                width: 22,
                height: 22,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('คืนค่าโปรไฟล์จาก Google',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      'ดึงชื่อและรูปโปรไฟล์จากบัญชี Google ที่เชื่อมไว้',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: onSurfaceVar,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.chevron_right, color: onSurfaceVar),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────── Build ─────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vp = MediaQuery.of(context).viewPadding;
    final String? overlayText =
        _blockingText ?? (_isLoading ? _busyText : null);

    return WillPopScope(
      onWillPop: _confirmDiscardIfNeeded,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('แก้ไขโปรไฟล์'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _confirmDiscardIfNeeded()) {
                if (mounted) Navigator.pop(context);
              }
            },
          ),
        ),
        body: _bootLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  Form(
                    key: _formKey,
                    child: ListView(
                      padding:
                          EdgeInsets.fromLTRB(24, 24, 24, 24 + 72 + vp.bottom),
                      children: [
                        Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      theme.colorScheme.primary
                                          .withOpacity(.25),
                                      theme.colorScheme.primary
                                          .withOpacity(.05),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              ),
                              ClipOval(
                                child: SizedBox.square(
                                  dimension: 104,
                                  child: _buildAvatarWidget(),
                                ),
                              ),
                              Positioned(
                                bottom: 2,
                                right: 8,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(100),
                                    boxShadow: [
                                      BoxShadow(
                                        blurRadius: 8,
                                        color: Colors.black.withOpacity(.10),
                                        offset: const Offset(0, 2),
                                      )
                                    ],
                                  ),
                                  child: Semantics(
                                    button: true,
                                    label: 'เปลี่ยนรูปโปรไฟล์',
                                    child: IconButton.filledTonal(
                                      onPressed: _isLoading ? null : _pickImage,
                                      icon: const Icon(Icons.camera_alt,
                                          size: 18),
                                      tooltip: 'เปลี่ยนรูปโปรไฟล์',
                                      style: IconButton.styleFrom(
                                        padding: const EdgeInsets.all(8),
                                        minimumSize: const Size(36, 36),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if ((_newImageFile != null) ||
                                  ((_currentImageUrl ?? '').isNotEmpty))
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: IconButton(
                                    tooltip: 'ลบรูปโปรไฟล์',
                                    onPressed: _isLoading ? null : _removeImage,
                                    icon: const Icon(Icons.close),
                                    style: IconButton.styleFrom(
                                      backgroundColor:
                                          theme.colorScheme.errorContainer,
                                      foregroundColor:
                                          theme.colorScheme.onErrorContainer,
                                      minimumSize: const Size(28, 28),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),

                        // ───── ชื่อผู้ใช้ ─────
                        TextFormField(
                          controller: _nameCtrl,
                          decoration:
                              const InputDecoration(labelText: 'ชื่อผู้ใช้'),
                          textInputAction: TextInputAction.next,
                          maxLength: kNameUiMax,
                          maxLengthEnforcement: MaxLengthEnforcement.enforced,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(kNameUiMax)
                          ],
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return 'กรุณากรอกชื่อ';
                            if (t.length < 2) return 'ชื่อสั้นเกินไป';
                            final bytes = utf8.encode(t).length;
                            if (bytes > kNameDbMaxBytes) {
                              return 'ชื่อต้องมีความยาวไม่เกิน $kNameDbMaxBytes ไบต์';
                            }
                            return null;
                          },
                        ),

                        // ───── ★ ใหม่: ข้อมูลแสดงใต้โปรไฟล์ ─────
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _infoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ข้อมูลแสดงใต้โปรไฟล์',
                            hintText: 'เช่น “ชอบทำอาหารไทย | แพ้ถั่วลิสง”',
                          ),
                          minLines: 2,
                          maxLines: 4,
                          textInputAction: TextInputAction.done,
                          maxLength: kInfoUiMax,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(kInfoUiMax),
                          ],
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return null; // ไม่บังคับกรอก
                            final bytes = utf8.encode(t).length;
                            if (bytes > kInfoDbMaxBytes) {
                              return 'ข้อมูลยาวเกินไป (ไม่เกิน $kInfoDbMaxBytes ไบต์)';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) =>
                              !_isLoading ? _saveProfile() : null,
                        ),

                        // ★ ปุ่มคืนค่าโปรไฟล์จาก Google (แสดงเฉพาะคนที่เชื่อม Google)
                        const SizedBox(height: 16),
                        _buildGoogleRestoreCard(),
                      ],
                    ),
                  ),
                  if (overlayText != null)
                    Positioned.fill(
                        child: _buildLoadingOverlay(text: overlayText)),
                ],
              ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: _isLoading || !_hasChanges ? null : _saveProfile,
            icon: const Icon(Icons.save_outlined),
            label: const Text('บันทึก'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ────────────────────────────────────────────────────────────── */
/* Helper class for Image Picking & Processing                    */
/* ────────────────────────────────────────────────────────────── */

class _ImagePickerHelper {
  final BuildContext context;
  final ImagePicker _picker = ImagePicker();
  final ValueChanged<String?>? onBlocking;

  _ImagePickerHelper({required this.context, this.onBlocking});

  Future<File?> showPickerSheet() async {
    return await showModalBottomSheet<File?>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('ถ่ายภาพ'),
              onTap: () async {
                final f = await _pickImage(ImageSource.camera);
                if (context.mounted) Navigator.pop(sheetCtx, f);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('เลือกจากคลังภาพ'),
              onTap: () async {
                final f = await _pickImage(ImageSource.gallery);
                if (context.mounted) Navigator.pop(sheetCtx, f);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<File?> _pickImage(ImageSource src) async {
    final ok = src == ImageSource.camera
        ? await _ensureCamera()
        : await _ensurePhotos();
    if (!ok) return null;

    try {
      final x = await _picker.pickImage(
        source: src,
        imageQuality: 90,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (x == null) return null;

      onBlocking?.call('กำลังเปิดเครื่องมือตัดรูป...');
      final cropped = await _cropImage(x.path);
      onBlocking?.call(null);

      if (cropped == null) return null;
      return await enforceConstraints(cropped);
    } catch (e) {
      _snack('ไม่สามารถเลือกรูปได้: $e');
      onBlocking?.call(null);
      return null;
    }
  }

  Future<File> enforceConstraints(File input) =>
      _enforceImageConstraints(input);

  Future<File?> _cropImage(String path) async {
    return Navigator.push<File?>(
      context,
      MaterialPageRoute(builder: (_) => CropAvatarScreen(sourcePath: path)),
    );
  }

  Future<bool> _ensurePhotos() async {
    if (Platform.isIOS) return _ask(Permission.photos);
    final info = await DeviceInfoPlugin().androidInfo;
    if (info.version.sdkInt >= 33) return true; // Android 13+ ไม่ต้องขอ storage
    return _ask(Permission.storage);
  }

  Future<bool> _ensureCamera() => _ask(Permission.camera);

  Future<bool> _ask(Permission p) async {
    final s = await p.status;
    if (s.isGranted) return true;
    if (s.isPermanentlyDenied) {
      _openSettingsDialog();
      return false;
    }
    return (await p.request()).isGranted;
  }

  void _openSettingsDialog() => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('ไม่อนุญาต'),
          content: const Text('กรุณาอนุญาตสิทธิ์ที่จำเป็นในการตั้งค่าแอป'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ยกเลิก')),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await openAppSettings();
              },
              child: const Text('เปิดการตั้งค่า'),
            ),
          ],
        ),
      );

  void _snack(String m) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<File> _enforceImageConstraints(
    File file, {
    int maxBytes = 2 * 1024 * 1024,
    int firstMaxSide = 2048,
  }) async {
    try {
      final original = await file.readAsBytes();
      img.Image? image = img.decodeImage(original);
      if (image == null) return file;

      image = img.bakeOrientation(image);

      // ลองบีบอัดก่อน
      for (final q in const [85, 75, 65, 55, 45, 35]) {
        final jpg = img.encodeJpg(image, quality: q);
        if (jpg.lengthInBytes <= maxBytes) {
          return file.writeAsBytes(jpg, flush: true);
        }
      }

      // ถ้ายังเกิน ลองย่อขนาดและบีบอัดใหม่
      final candidates = <int>[firstMaxSide, 1600, 1200];
      for (final side in candidates) {
        final resized = img.copyResize(
          image,
          width: image.width >= image.height ? side : null,
          height: image.height > image.width ? side : null,
          interpolation: img.Interpolation.average,
        );
        for (final q in const [80, 70, 60, 50, 40]) {
          final jpg = img.encodeJpg(resized, quality: q);
          if (jpg.lengthInBytes <= maxBytes) {
            return file.writeAsBytes(jpg, flush: true);
          }
        }
      }

      // ทางเลือกสุดท้าย
      final finalImg = img.copyResize(image, width: 1200);
      final jpg = img.encodeJpg(finalImg, quality: 50);
      return file.writeAsBytes(jpg, flush: true);
    } catch (_) {
      return file;
    }
  }
}
