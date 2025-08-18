// lib/screens/edit_profile_screen.dart
//
// ★★★ Updated: 2025-08-18 – Avatar display, loading & upload polish ★★★
//   • วงกลมโปรไฟล์: ClipOval + Image (สีปกติในวงกลม) + gaplessPlayback
//   • หน้าโหลด 3 ชั้น:
//       1) _bootLoading  : โหลดข้อมูลผู้ใช้ครั้งแรก
//       2) _blockingText : โหลดชั่วคราวตอนเตรียมไฟล์หลังครอป (บีบอัด ฯลฯ)
//       3) _isLoading    : ตอนกด "บันทึก" อัปเดตโปรไฟล์/อัปโหลดรูปขึ้นเซิร์ฟเวอร์
//   • หลังอัปโหลดรูป เติม cache-buster กันรูปเก่าคาแคช
//   • เก็บไฟล์ฝั่งเซิร์ฟเวอร์แบบ “สี่เหลี่ยมเต็ม” (วงกลมเป็นหน้าที่ UI)

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
  // ───── Form state ─────
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  // ───── Avatar state ─────
  String? _currentImageUrl; // URL ที่ใช้งานอยู่ (จากเซิร์ฟเวอร์ หรือค่าว่าง)
  File? _newImageFile; // ไฟล์ใหม่ที่เพิ่งเลือก (ผ่าน cropper แล้ว) พร้อมอัปโหลด

  // ───── Loading flags ─────
  bool _bootLoading = true; // หน้าโหลดครั้งแรก: ระหว่างดึงข้อมูลผู้ใช้
  bool _isLoading = false; // ระหว่างกด "บันทึก" ส่งข้อมูลขึ้นเซิร์ฟเวอร์
  String?
      _blockingText; // หน้าโหลดชั่วคราว: ตอนเตรียมไฟล์หลังครอป (บีบอัด/ตรวจข้อจำกัด)

  // ───── Helpers ─────
  late final _ImagePickerHelper _picker;

  // ───── Initial snapshot (ไว้ตรวจว่ามีการเปลี่ยนแปลงไหม) ─────
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

  // ───────────────────────────────── Data ─────────────────────────────────

  Future<void> _loadUserProfile() async {
    try {
      final data = await AuthService.getLoginData();
      if (!mounted) return;
      setState(() {
        _nameCtrl.text = data['profileName'] ?? '';
        _currentImageUrl = data['profileImage'];
        _initialName = _nameCtrl.text;
        _initialImageUrl = _currentImageUrl ?? '';
        _bootLoading = false; // ปิดโหลดครั้งแรก
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('โหลดโปรไฟล์ล้มเหลว: $e');
      setState(() => _bootLoading = false);
    }
  }

  // หน้าโหลดชั่วคราว (เช่น ขณะบีบอัดรูป) — ส่งข้อความ null เพื่อซ่อน
  void _setBlocking(String? text) {
    if (!mounted) return;
    setState(() => _blockingText = text);
  }

  Future<void> _pickImage() async {
    // เปิด bottom sheet → ไปหน้า crop → ได้ไฟล์กลับมา (หรือ null ถ้ายกเลิก)
    final file = await _picker.showPickerSheet();
    if (file == null || !mounted) return;

    // แสดงหน้าโหลดระหว่าง "เตรียมไฟล์" (บีบอัด/ลดขนาด ให้ผ่านข้อจำกัด)
    _setBlocking('กำลังเตรียมรูป...');
    try {
      // หมายเหตุ: ถ้า _ImagePickerHelper ครอป/บีบอัดมาแล้วพอดี
      // และคุณไม่อยากบีบอัดซ้ำ ให้แทนที่ด้วย:
      //   final ready = file;
      final ready = await _picker.enforceConstraints(file);
      setState(() => _newImageFile = ready);
    } catch (e) {
      _showSnack('เตรียมรูปไม่สำเร็จ: $e');
    } finally {
      _setBlocking(null);
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

      // กรณีลบรูป (ไม่ตั้งไฟล์ใหม่ + URL ปัจจุบันว่าง)
      if (_newImageFile == null && (_currentImageUrl ?? '').isEmpty) {
        imgUrl = '';
      }

      // อัปโหลดรูปใหม่
      if (_newImageFile != null) {
        // (เผื่อบางอุปกรณ์ไฟล์ยังใหญ่ ให้บังคับลงเงื่อนไขอีกครั้ง)
        final constrained = await _picker.enforceConstraints(_newImageFile!);
        imgUrl = await ApiService.uploadProfileImage(constrained);

        // ป้องกันรูปเก่าคาแคชด้วย query param เวลาแสดงผล
        final sep = imgUrl.contains('?') ? '&' : '?';
        imgUrl = '$imgUrl${sep}t=${DateTime.now().millisecondsSinceEpoch}';
      }

      // อัปเดตโปรไฟล์ฝั่งเซิร์ฟเวอร์
      final updated = await ApiService.updateProfile(
        profileName: newName,
        imageUrl: imgUrl,
      );

      // เซฟลง local/session
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

  // รูปโปรไฟล์พร้อม fallback และตัว Loading builder
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

  // ───────────────────────────────── Build ─────────────────────────────────

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

        // ① หน้าโหลดครั้งแรก
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
                              // วงแหวนตกแต่ง
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
                              // รูปจริง (วงกลม)
                              ClipOval(
                                child: SizedBox.square(
                                  dimension: 104,
                                  child: _buildAvatarWidget(),
                                ),
                              ),
                              // ปุ่มเปลี่ยนรูป
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
                              // ปุ่มลบรูป
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

                        // ชื่อผู้ใช้
                        TextFormField(
                          controller: _nameCtrl,
                          decoration:
                              const InputDecoration(labelText: 'ชื่อผู้ใช้'),
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

                  // ② หน้าโหลดตอนกด "บันทึก"
                  if (_isLoading)
                    Container(
                      color: Colors.black.withOpacity(.3),
                      child: const Center(child: CircularProgressIndicator()),
                    ),

                  // ③ หน้าโหลดชั่วคราวตอนเตรียมไฟล์หลังครอป
                  if (_blockingText != null)
                    Container(
                      color: Colors.black.withOpacity(.35),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 12),
                            Text(_blockingText!,
                                style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
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

  // แผ่นล่างเลือกแหล่งรูป: กล้อง / คลังรูป → ส่งไฟล์ที่ครอปกลับ
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

  // เลือกรูป → ไปหน้า crop → ได้ไฟล์กลับ (หรือ null)
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

      // คืนไฟล์ “ที่ผ่านข้อจำกัด” กลับไป (เช่น ≤2MB)
      return await enforceConstraints(cropped);
    } catch (e) {
      _snack('เลือกรูปไม่สำเร็จ: $e');
      return null;
    }
  }

  // เผย public method เผื่อภายนอกอยาก enforce ซ้ำ (ใช้อยู่ใน _pickImage() ของหน้าหลัก)
  Future<File> enforceConstraints(File input) =>
      _enforceImageConstraints(input);

  // เปิดหน้า crop แบบ custom ของเรา
  Future<File?> _cropImage(String path) async {
    return Navigator.push<File?>(
      context,
      MaterialPageRoute(builder: (_) => CropAvatarScreen(sourcePath: path)),
    );
  }

  // ───── Permissions (Android friendly) ─────
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

  // ───── Enforce image constraints (≤ ~2MB แบบคมชัด) ─────
  Future<File> _enforceImageConstraints(
    File file, {
    int maxBytes = 2 * 1024 * 1024, // 2MB
    int firstMaxSide = 2048,
  }) async {
    try {
      final original = await file.readAsBytes();
      img.Image? image = img.decodeImage(original);
      if (image == null) return file;

      image = img.bakeOrientation(image); // เคารพ EXIF

      // ลดคุณภาพก่อน (ไม่ลดขนาด)
      for (final q in const [85, 75, 65, 55, 45, 35]) {
        final jpg = img.encodeJpg(image, quality: q);
        if (jpg.lengthInBytes <= maxBytes) {
          return file.writeAsBytes(jpg, flush: true);
        }
      }

      // ลดขนาด + คุณภาพทีละขั้น
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

      // สำรองกรณีสุดท้าย
      final finalImg = img.copyResize(image, width: 1200);
      final jpg = img.encodeJpg(finalImg, quality: 50);
      return file.writeAsBytes(jpg, flush: true);
    } catch (_) {
      // ถ้ามีปัญหาก็คืนไฟล์เดิม (อย่าบล็อกฟลว์ผู้ใช้)
      return file;
    }
  }
}
