import 'dart:async';
import 'dart:io';

import 'package:cookbook/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  String? _currentImageUrl; // URL เดิมที่เซิร์ฟเวอร์ให้มา
  File? _newImageFile; // รูปที่ผู้ใช้เลือกใหม่

  bool _loading = false; // กำลังบันทึกโปรไฟล์
  bool _pickingImage = false; // กำลังเปิด image-picker

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await AuthService.checkAndRedirectIfLoggedOut(context)) {
        _loadUserProfile();
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  /*────────────────── โหลดข้อมูลโปรไฟล์ ──────────────────*/
  Future<void> _loadUserProfile() async {
    try {
      final data = await AuthService.getLoginData();
      if (!mounted) return;
      setState(() {
        _nameCtrl.text = data['profileName'] ?? '';
        _currentImageUrl = data['profileImage'] ?? '';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดโปรไฟล์ล้มเหลว: $e')),
        );
      }
    }
  }

/*────────────────── ฟังก์ชันขอสิทธิ์ ─────────────────────*/
  Future<bool> _requestStoragePermission() async {
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final sdkInt = androidInfo.version.sdkInt ?? 0;

    if (sdkInt >= 33) {
      // Android 13+ ใช้ photos (แทน images ที่ไม่มีใน permission_handler)
      final status = await Permission.photos.status;

      if (status.isGranted) return true;

      if (status.isDenied) {
        final result = await Permission.photos.request();
        return result.isGranted;
      }

      if (status.isPermanentlyDenied) {
        _showOpenSettingsDialog(); // ผู้ใช้เคยกดไม่ให้สิทธิ์แบบถาวร
        return false;
      }

      return false;
    } else {
      // Android 12 หรือต่ำกว่า
      final status = await Permission.storage.status;

      if (status.isGranted) return true;

      if (status.isDenied) {
        final result = await Permission.storage.request();
        return result.isGranted;
      }

      if (status.isPermanentlyDenied) {
        _showOpenSettingsDialog(); // ผู้ใช้เคยกดไม่ให้สิทธิ์แบบถาวร
        return false;
      }

      return false;
    }
  }

/*────────────────── แจ้งเตือนให้ไปเปิดสิทธิ์ใน Settings ─────────────────────*/
  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ไม่ได้รับสิทธิ์'),
        content: const Text('กรุณาเปิดสิทธิ์เข้าถึงรูปภาพในหน้าตั้งค่าแอป'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings(); // เปิดหน้าการตั้งค่าของแอป
            },
            child: const Text('เปิดการตั้งค่า'),
          ),
        ],
      ),
    );
  }

  /*────────────────── เลือกรูป + ครอบ ────────────────────*/
  Future<void> _pickImage() async {
    if (_pickingImage) return;
    _pickingImage = true;

    try {
      // ตรวจเวอร์ชัน Android แล้วขอสิทธิ์ให้ถูกต้อง
      if (Platform.isAndroid) {
        final granted = await _requestStoragePermission();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ไม่ได้รับสิทธิ์เข้าถึงรูปภาพ')),
            );
          }
          return;
        }
      }

      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;

      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 80,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'ครอบรูปโปรไฟล์',
            toolbarColor: Colors.deepOrange,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.black,
            cropFrameColor: Colors.white,
            activeControlsWidgetColor: Colors.orange,
            hideBottomControls: false,
            lockAspectRatio: true,
          ),
        ],
      );

      if (cropped != null && mounted) {
        setState(() => _newImageFile = File(cropped.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เลือกรูปล้มเหลว: $e')),
        );
      }
    } finally {
      _pickingImage = false;
    }
  }

  /*────────────────── บันทึกโปรไฟล์ ───────────────────────*/
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    final newName = _nameCtrl.text.trim();
    final loginData = await AuthService.getLoginData();
    final oldName = loginData['profileName'] ?? '';
    final oldImage = loginData['profileImage'] ?? '';

    // ไม่มีการเปลี่ยนแปลง
    if (newName == oldName && _newImageFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่มีการเปลี่ยนแปลง')),
        );
      }
      setState(() => _loading = false);
      return;
    }

    try {
      String imagePath = oldImage;

      if (_newImageFile != null) {
        imagePath = await ApiService.uploadProfileImage(_newImageFile!)
            .timeout(const Duration(seconds: 15));
      }

      final res = await ApiService.updateProfile(
        profileName: newName,
        imageUrl: imagePath,
      ).timeout(const Duration(seconds: 15));

      await AuthService.saveLogin(
        userId: loginData['userId'] ?? 0,
        profileName: res['profile_name'] ?? newName,
        profileImage: res['image_url'] ?? imagePath,
        email: loginData['email'] ?? '',
      );

      if (!mounted) return;
      setState(() => _currentImageUrl = imagePath); // แสดงรูปใหม่ทันที
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกโปรไฟล์สำเร็จ')),
      );
      Navigator.pop(context, true);
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เซิร์ฟเวอร์ตอบช้า ลองใหม่ภายหลัง')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ผิดพลาด: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /*────────────────── Preview รูปเต็ม ─────────────────────*/
  void _showImagePreview() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: _newImageFile != null
              ? Image.file(_newImageFile!)
              : (_currentImageUrl?.isNotEmpty ?? false)
                  ? Image.network(
                      _currentImageUrl!,
                      errorBuilder: (_, __, ___) =>
                          Image.asset('assets/images/default_avatar.png'),
                    )
                  : Image.asset('assets/images/default_avatar.png'),
        ),
      ),
    );
  }

  /*────────────────── UI ──────────────────────────────────*/
  @override
  Widget build(BuildContext context) {
    final avatar = _newImageFile != null
        ? FileImage(_newImageFile!)
        : (_currentImageUrl?.isNotEmpty ?? false)
            ? NetworkImage(_currentImageUrl!)
            : const AssetImage('assets/images/default_avatar.png')
                as ImageProvider;

    return Scaffold(
      appBar: AppBar(title: const Text('แก้ไขโปรไฟล์')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  Center(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: _showImagePreview,
                          child: CircleAvatar(
                              radius: 52,
                              backgroundColor: Colors.grey.shade200,
                              backgroundImage: avatar),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 4,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white,
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt,
                                  color: Colors.black, size: 18),
                              onPressed: _pickingImage ? null : _pickImage,
                              tooltip: 'เปลี่ยนรูปโปรไฟล์',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อผู้ใช้',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'กรุณากรอกชื่อ'
                        : null,
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _saveProfile,
        icon: const Icon(Icons.save),
        label: const Text('บันทึก'),
      ),
    );
  }
}
