// lib/screens/edit_profile_screen.dart
// 2025‑07‑23  fixed: double‑pop image sheet, refresh after save

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

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

  String? _currentImageUrl;
  File? _newImageFile;
  bool _isLoading = false;

  late final _ImagePickerHelper _picker;

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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final newName = _nameCtrl.text.trim();
    final login = await AuthService.getLoginData();
    final oldName = login['profileName'] ?? '';
    final oldImg = login['profileImage'] ?? '';

    if (newName == oldName && _newImageFile == null) {
      _showSnack('ไม่มีการเปลี่ยนแปลง', isError: false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String imgUrl = oldImg;
      if (_newImageFile != null) {
        imgUrl = await ApiService.uploadProfileImage(_newImageFile!);
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

  /* ───── build ───── */
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    ImageProvider avatar = const AssetImage('assets/images/default_avatar.png');
    if (_newImageFile != null) {
      avatar = FileImage(_newImageFile!);
    } else if (_currentImageUrl?.isNotEmpty ?? false) {
      avatar = NetworkImage(_currentImageUrl!);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('แก้ไขโปรไฟล์')),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: theme.colorScheme.surfaceVariant,
                        backgroundImage: avatar,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 4,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: theme.colorScheme.surface,
                          child: IconButton(
                            onPressed: _pickImage,
                            tooltip: 'เปลี่ยนรูปโปรไฟล์',
                            icon: const Icon(Icons.camera_alt, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'ชื่อผู้ใช้'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อ' : null,
                ),
                const SizedBox(height: 100),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _saveProfile,
        icon: const Icon(Icons.save_outlined),
        label: const Text('บันทึก'),
      ),
    );
  }
}

/* ────────────────────────────────────────────────────────────── */
/*  Helper class (fixed double‑pop)                               */
/* ────────────────────────────────────────────────────────────── */

class _ImagePickerHelper {
  final BuildContext context;
  final ImagePicker _picker = ImagePicker();

  _ImagePickerHelper({required this.context});

  /// แสดงแผ่นล่าง แล้วส่ง File กลับ
  Future<File?> showPickerSheet() async {
    return await showModalBottomSheet<File?>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('ถ่ายรูป'),
              onTap: () async {
                final f = await _pickImage(ImageSource.camera);
                Navigator.pop(sheetCtx, f); // pop ครั้งเดียวพร้อมผลลัพธ์
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

  /* ───── pick & crop ───── */
  Future<File?> _pickImage(ImageSource src) async {
    final ok = src == ImageSource.camera
        ? await _ensureCamera()
        : await _ensurePhotos();
    if (!ok) return null;

    try {
      final x = await _picker.pickImage(source: src, imageQuality: 90);
      if (x == null) return null;
      return await _cropImage(x.path);
    } catch (e) {
      _snack('เลือกรูปไม่สำเร็จ: $e');
      return null;
    }
  }

  Future<File?> _cropImage(String path) async {
    final theme = Theme.of(context);
    final cropped = await ImageCropper().cropImage(
      sourcePath: path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 80,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'ครอบตัดรูป',
          toolbarColor: theme.colorScheme.primary,
          toolbarWidgetColor: theme.colorScheme.onPrimary,
          activeControlsWidgetColor: theme.colorScheme.primary,
          backgroundColor: Colors.black,
          lockAspectRatio: true,
        ),
        IOSUiSettings(title: 'ครอบตัดรูป', aspectRatioLockEnabled: true),
      ],
    );
    return cropped != null ? File(cropped.path) : null;
  }

  /* ───── permission helpers ───── */
  Future<bool> _ensurePhotos() async {
    if (Platform.isIOS) return _ask(Permission.photos);

    final info = await DeviceInfoPlugin().androidInfo;
    if (info.version.sdkInt >= 33) return true; // Android 13+ Photo Picker
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

  /* ───── dialogs / snack ───── */
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
                child: const Text('เปิดการตั้งค่า')),
          ],
        ),
      );
  void _snack(String m) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }
}
