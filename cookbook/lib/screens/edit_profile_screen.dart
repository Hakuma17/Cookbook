// lib/screens/edit_profile_screen.dart
// -----------------------------------------------------------------

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
  /* ───────── state / controller ───────── */
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _currentImageUrl; // URL เดิม
  File? _newImageFile; // รูปใหม่
  bool _loading = false; // กำลัง save
  bool _pickingImage = false; // กำลัง pick

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

  /* ───────── responsive helpers ───────── */
  late double _scale, _w, _h;
  double px(double v) => v * _scale; // อ้างอิงดีไซน์ 360 px
  double clamp(double v, double min, double max) =>
      v < min ? min : (v > max ? max : v);

  /* ───────── โหลด profile ───────── */
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('โหลดโปรไฟล์ล้มเหลว: $e')));
      }
    }
  }

  /* ───────── permission helper ───────── */
  Future<bool> _ensurePhotosPermission() async {
    // Android ≤ 32 ต้องขอ READ_EXTERNAL / Storage; Android 13+ ไม่จำเป็น
    final info = await DeviceInfoPlugin().androidInfo;
    final sdk = info.version.sdkInt;

    if (Platform.isIOS) {
      final status = await Permission.photos.status;
      if (status.isGranted) return true;
      if (status.isDenied) return (await Permission.photos.request()).isGranted;
      if (status.isPermanentlyDenied) _showOpenSettingsDialog();
      return false;
    }

    if (sdk >= 33) return true; // PhotoPicker API – ไม่ต้องขอ
    final status = await Permission.storage.status;
    if (status.isGranted) return true;
    if (status.isDenied) return (await Permission.storage.request()).isGranted;
    if (status.isPermanentlyDenied) _showOpenSettingsDialog();
    return false;
  }

  Future<bool> _ensureCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;
    if (status.isDenied) return (await Permission.camera.request()).isGranted;
    if (status.isPermanentlyDenied) _showOpenSettingsDialog();
    return false;
  }

  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ไม่ได้รับสิทธิ์'),
        content: const Text('กรุณาเปิดสิทธิ์ในหน้าตั้งค่าแอป'),
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
  }

  /* ───────── pick & crop image ───────── */
  Future<void> _pickFromGallery() async {
    if (!await _ensurePhotosPermission()) {
      _showSnack('ไม่ได้รับสิทธิ์เข้าถึงรูปภาพ');
      return;
    }
    await _doPick(ImageSource.gallery);
  }

  Future<void> _pickFromCamera() async {
    if (!await _ensureCameraPermission()) {
      _showSnack('ไม่ได้รับสิทธิ์ใช้กล้อง');
      return;
    }
    await _doPick(ImageSource.camera);
  }

  Future<void> _doPick(ImageSource src) async {
    if (_pickingImage) return;
    _pickingImage = true;

    try {
      final picked = await _picker.pickImage(source: src, imageQuality: 90);
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
              lockAspectRatio: true),
        ],
      );

      if (cropped != null && mounted) {
        setState(() => _newImageFile = File(cropped.path));
      }
    } catch (e) {
      _showSnack('เลือกรูปล้มเหลว: $e');
    } finally {
      _pickingImage = false;
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('ถ่ายรูป'),
              onTap: () {
                Navigator.pop(context);
                _pickFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('เลือกรูปจากคลัง'),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  /* ───────── save profile ───────── */
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _loading = true);
    final newName = _nameCtrl.text.trim();
    final login = await AuthService.getLoginData();
    final oldName = login['profileName'] ?? '';
    final oldImg = login['profileImage'] ?? '';

    if (newName == oldName && _newImageFile == null) {
      _showSnack('ไม่มีการเปลี่ยนแปลง', color: Colors.orange);
      setState(() => _loading = false);
      return;
    }

    try {
      String imgPath = oldImg;
      if (_newImageFile != null) {
        imgPath = await ApiService.uploadProfileImage(_newImageFile!)
            .timeout(const Duration(seconds: 15));
      }

      final res = await ApiService.updateProfile(
              profileName: newName, imageUrl: imgPath)
          .timeout(const Duration(seconds: 15));

      await AuthService.saveLogin(
        userId: login['userId'] ?? 0,
        profileName: res['profile_name'] ?? newName,
        profileImage: res['image_url'] ?? imgPath,
        email: login['email'] ?? '',
      );

      if (!mounted) return;
      setState(() => _currentImageUrl = imgPath);
      _showSnack('บันทึกโปรไฟล์สำเร็จ', color: Colors.green);
      Navigator.pop(context, true);
    } on TimeoutException {
      _showSnack('เซิร์ฟเวอร์ตอบช้า ลองใหม่ภายหลัง');
    } on SocketException {
      _showSnack('ไม่มีการเชื่อมต่ออินเทอร์เน็ต');
    } catch (e) {
      _showSnack('ผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /* ───────── preview full image ───────── */
  void _showImagePreview() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: _newImageFile != null
              ? Image.file(_newImageFile!)
              : (_currentImageUrl?.isNotEmpty ?? false)
                  ? Image.network(_currentImageUrl!,
                      errorBuilder: (_, __, ___) =>
                          Image.asset('assets/images/default_avatar.png'))
                  : Image.asset('assets/images/default_avatar.png'),
        ),
      ),
    );
  }

  /* ───────── snack ───────── */
  void _showSnack(String m, {Color color = Colors.red}) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(m), backgroundColor: color));

  /* ───────── build ───────── */
  @override
  Widget build(BuildContext context) {
    _w = MediaQuery.of(context).size.width;
    _h = MediaQuery.of(context).size.height;
    _scale = (_w / 360).clamp(0.85, 1.25);

    final pad = px(20);
    final avatarR = px(52);
    final overlayR = px(18);
    final overlayRight = px(4);
    final space30 = px(30);
    final bottomSpace = px(100);
    final borderRad = px(12);
    final txtF = px(16);

    final avatarProvider = _newImageFile != null
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
            padding: EdgeInsets.all(pad),
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
                            radius: avatarR,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: avatarProvider,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: overlayRight,
                          child: CircleAvatar(
                            radius: overlayR,
                            backgroundColor: Colors.white,
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt),
                              iconSize: overlayR,
                              onPressed:
                                  _pickingImage ? null : _showImagePickerSheet,
                              tooltip: 'เปลี่ยนรูปโปรไฟล์',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: space30),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'ชื่อผู้ใช้',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(borderRad)),
                    ),
                    style: TextStyle(fontSize: txtF),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'กรุณากรอกชื่อ'
                        : null,
                  ),
                  SizedBox(height: bottomSpace),
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
