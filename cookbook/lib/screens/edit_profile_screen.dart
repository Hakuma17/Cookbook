// lib/screens/edit_profile_screen.dart
// ★★★ Updated: 2025-08-12 – Avatar display & upload polish ★★★
//   • แสดงรูปโปรไฟล์ด้วย ClipOval + Image (สีปกติในวงกลม)
//   • รองรับ loading/error และ gaplessPlayback (ไม่กระพริบเวลาเปลี่ยนรูป)
//   • หลังอัปโหลดรูป เติม cache-buster ป้องกันเบราว์เซอร์/ระบบแคชภาพเก่า
//   • เก็บไฟล์ฝั่งเซิร์ฟเวอร์แบบ “สี่เหลี่ยมเต็ม” ส่วนวงกลมเป็นหน้าที่ UI

import 'dart:async';
import 'dart:io';

import 'package:cookbook/screens/crop_avatar_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:image/image.dart' as img;

import '../services/api_service.dart';
import '../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  String? _currentImageUrl; // url ปัจจุบันที่แสดง
  File? _newImageFile; // ไฟล์ใหม่ที่เพิ่งเลือก (ผ่าน cropper แล้ว)
  bool _isLoading = false;

  late final _ImagePickerHelper _picker;

  String _initialName = '';
  String _initialImageUrl = '';

  @override
  void initState() {
    super.initState();
    _picker = _ImagePickerHelper(context: context);
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  /* ───── data ───── */
  Future<void> _loadUserProfile() async {
    try {
      final data = await AuthService.getLoginData();
      if (!mounted) return;
      setState(() {
        _nameCtrl.text = data['profileName'] ?? '';
        _currentImageUrl = data['profileImage'];
        _initialName = _nameCtrl.text;
        _initialImageUrl = _currentImageUrl ?? '';
      });
    } catch (e) {
      _showSnack('โหลดโปรไฟล์ล้มเหลว: $e');
    }
  }

  Future<void> _pickImage() async {
    final file = await _picker.showPickerSheet();
    if (file != null && mounted) {
      setState(() => _newImageFile = file);
    }
  }

  void _removeImage() {
    setState(() {
      _newImageFile = null;
      _currentImageUrl = null;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final newName = _nameCtrl.text.trim();
    final login = await AuthService.getLoginData();
    final oldName = login['profileName'] ?? '';
    final oldImg = login['profileImage'] ?? '';

    // ไม่มีอะไรเปลี่ยน → ข้าม
    if (newName == oldName &&
        _newImageFile == null &&
        ((_currentImageUrl ?? '') == oldImg)) {
      _showSnack('ไม่มีการเปลี่ยนแปลง', isError: false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String imgUrl = oldImg;

      // ลบรูป
      if (_newImageFile == null && (_currentImageUrl ?? '').isEmpty) {
        imgUrl = '';
      }

      // อัปโหลดรูปใหม่
      if (_newImageFile != null) {
        final constrained = await _picker.enforceConstraints(_newImageFile!);
        imgUrl = await ApiService.uploadProfileImage(constrained);

        // ป้องกันแคชค้าง
        final sep = imgUrl.contains('?') ? '&' : '?';
        imgUrl = '$imgUrl${sep}t=${DateTime.now().millisecondsSinceEpoch}';
      }

      final updated = await ApiService.updateProfile(
        profileName: newName,
        imageUrl: imgUrl,
      );

      await AuthService.saveLogin(
        userId: login['userId'],
        profileName: updated['profile_name'] ?? newName,
        profileImage: updated['image_url'] ?? imgUrl,
        email: login['email'],
      );

      if (!mounted) return;
      _showSnack('บันทึกโปรไฟล์สำเร็จ', isError: false);
      setState(() {
        _newImageFile = null;
        _currentImageUrl = imgUrl;
        _initialName = newName;
        _initialImageUrl = imgUrl;
      });
      Navigator.pop(context, true);
    } on UnauthorizedException {
      _showSnack('Session หมดอายุ กรุณาเข้าสู่ระบบใหม่');
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /* ───── helpers ───── */
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
    final imageChanged =
        _newImageFile != null || (_currentImageUrl ?? '') != _initialImageUrl;
    return nameChanged || imageChanged;
  }

  Future<bool> _confirmDiscardIfNeeded() async {
    if (!_hasChanges) return true;
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('ยังไม่ได้บันทึก'),
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

  // แยกเป็นเมธอดเดียวเพื่อใช้งานซ้ำ/อ่านง่าย
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

  /* ───── build ───── */
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vp = MediaQuery.of(context).viewPadding;

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
        body: Stack(
          children: [
            Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + 72 + vp.bottom),
                children: [
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // วงแหวนตกแต่ง
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary.withOpacity(.25),
                                theme.colorScheme.primary.withOpacity(.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),

                        // วงกลมรูปโปรไฟล์จริง
                        ClipOval(
                          child: SizedBox.square(
                            dimension: 104,
                            child: _buildAvatarWidget(),
                          ),
                        ),

                        // ปุ่มเลือกรูป
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
                                onPressed: _pickImage,
                                icon: const Icon(Icons.camera_alt, size: 18),
                                tooltip: 'เปลี่ยนรูปโปรไฟล์',
                                style: IconButton.styleFrom(
                                  padding: const EdgeInsets.all(8),
                                  minimumSize: const Size(36, 36),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // ปุ่มลบรูป
                        if ((_newImageFile != null) ||
                            ((_currentImageUrl ?? '').isNotEmpty))
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              tooltip: 'ลบรูปโปรไฟล์',
                              onPressed: _removeImage,
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

                  // ชื่อผู้ใช้
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'ชื่อผู้ใช้'),
                    textInputAction: TextInputAction.done,
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return 'กรุณากรอกชื่อ';
                      if (t.length < 2) return 'ชื่อสั้นเกินไป';
                      if (t.length > 50) return 'ชื่อยาวเกินไป';
                      return null;
                    },
                    onFieldSubmitted: (_) =>
                        !_isLoading ? _saveProfile() : null,
                  ),
                ],
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(.3),
                child: const Center(child: CircularProgressIndicator()),
              ),
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
/* Helper class for Image Picking & Processing                   */
/* ────────────────────────────────────────────────────────────── */

class _ImagePickerHelper {
  final BuildContext context;
  final ImagePicker _picker = ImagePicker();

  _ImagePickerHelper({required this.context});

  Future<File?> showPickerSheet() async {
    return await showModalBottomSheet<File?>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('ถ่ายรูป'),
              onTap: () async {
                final f = await _pickImage(ImageSource.camera);
                Navigator.pop(sheetCtx, f);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('เลือกรูปจากคลัง'),
              onTap: () async {
                final f = await _pickImage(ImageSource.gallery);
                Navigator.pop(sheetCtx, f);
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

      final cropped = await _cropImage(x.path);
      if (cropped == null) return null;

      return await enforceConstraints(cropped);
    } catch (e) {
      _snack('เลือกรูปไม่สำเร็จ: $e');
      return null;
    }
  }

  Future<File> enforceConstraints(File input) =>
      _enforceImageConstraints(input);

  Future<File?> _cropImage(String path) async {
    // ใช้หน้าครอปแบบ custom ของเรา
    final f = await Navigator.push<File?>(
      context,
      MaterialPageRoute(builder: (_) => CropAvatarScreen(sourcePath: path)),
    );
    return f;
  }

  /* ───── permission helpers ───── */
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
    return await p.request().isGranted;
  }

  void _openSettingsDialog() => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('ไม่ได้รับสิทธิ์'),
          content: const Text('โปรดเปิดสิทธิ์ในหน้าตั้งค่าแอป'),
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

  /* ───── image constraints ───── */
  Future<File> _enforceImageConstraints(
    File file, {
    int maxBytes = 2 * 1024 * 1024, // 2MB
    int firstMaxSide = 2048,
  }) async {
    try {
      final original = await file.readAsBytes();
      img.Image? image = img.decodeImage(original);
      if (image == null) return file;

      image = img.bakeOrientation(image);

      // ลดคุณภาพก่อน
      for (final q in const [85, 75, 65, 55, 45, 35]) {
        final jpg = img.encodeJpg(image, quality: q);
        if (jpg.lengthInBytes <= maxBytes) {
          return file.writeAsBytes(jpg, flush: true);
        }
      }

      // ค่อย ๆ ลดขนาด + คุณภาพ
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

      // เผื่อกรณีสุดท้าย
      final finalImg = img.copyResize(image, width: 1200);
      final jpg = img.encodeJpg(finalImg, quality: 50);
      return file.writeAsBytes(jpg, flush: true);
    } catch (_) {
      return file;
    }
  }
}
