// lib/screens/edit_profile_screen.dart
//
// หมายเหตุ (TH): โค้ดหน้านี้จัดระเบียบการใช้งาน BuildContext หลัง await ตามแนวทางปลอดภัย
// - จับ nav/messenger/theme ก่อน await เพื่อไม่ฝืนใช้ context เดิมข้าม async gap
// - เปิด dialog/bottom sheet ผ่าน builder context ภายในเพื่อหลีกเลี่ยง context หลุด scope
// - เช็ค mounted ก่อน setState เสมอเมื่อกลับมาจากงาน async
// - ปรับตาม Material 3 (PopScope, Color.withValues, TextScaler ฯลฯ)
// - การ bust URL ของรูปโปรไฟล์ทำเพื่อบังคับรีเฟรช cache หลังอัปโหลดภาพใหม่
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
//
// 2025-09-19 — Cache-bust avatar
// • เพิ่ม _bust() และบัสต์ URL ทุกครั้งที่เป็นรูปใน /uploads/users/ เพื่อบังคับรีเฟรชรูปหลังบันทึก

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cookbook/screens/crop_avatar_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/google_oauth.dart';
import '../utils/safe_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/sanitize.dart';

const int kNameUiMax = 25;
const int kNameDbMaxBytes = 100;

// ★ ใหม่: ลิมิตสำหรับ “ข้อมูลแสดงใต้โปรไฟล์”
const int kInfoUiMax = 81; // ตัวอักษรบน UI (ข้อกำหนดใหม่)
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
  // ใช้ config เดียวกับหน้าเข้าสู่ระบบ เพื่อให้ได้สิทธิ์ profile/photo ครบ
  final _googleSignIn = GoogleSignIn(
    scopes: GoogleOAuthConfig.scopes,
    serverClientId: GoogleOAuthConfig.webClientId,
  );

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
  String _bust(String url) {
    if (url.isEmpty) return url;
    final sep = url.contains('?') ? '&' : '?';
    return '$url${sep}t=${DateTime.now().millisecondsSinceEpoch}';
  }

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
    if (p.startsWith('http://') || p.startsWith('https://')) {
      // External URL: ไม่แตะ cache-buster
      return p;
    }
    try {
      final rel = p.startsWith('/') ? p.substring(1) : p;
      final full = Uri.parse(ApiService.baseUrl).resolve(rel).toString();
      // บัสต์เฉพาะรูปในโฟลเดอร์ผู้ใช้
      return full.contains('/uploads/users/') ? _bust(full) : full;
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
        _currentImageUrl = googleImage; // ใช้รูปจาก Google แสดงผล (external)
        _currentImagePathRaw = null; // รูปภายนอก ไม่มี path บนเซิร์ฟเวอร์
      });
      _showSnack('คืนค่าข้อมูลจาก Google สำเร็จ', isError: false);
    } on PlatformException catch (pe) {
      final code = pe.code;
      String errorMessage;
      if (code == 'network_error') {
        errorMessage =
            'เกิดข้อผิดพลาดเครือข่าย กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ตและลองใหม่';
      } else if (code == 'sign_in_canceled') {
        errorMessage = 'ยกเลิกการเข้าสู่ระบบ Google';
      } else {
        errorMessage = 'เกิดข้อผิดพลาด Google: [$code]';
      }
      _showSnack(errorMessage);
    } catch (e) {
      _showSnack('เกิดข้อผิดพลาด: ${e.toString()}');
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

    // ★ ป้องกัน use_build_context_synchronously: จับ Navigator และ ScaffoldMessenger ไว้ก่อน await
    final nav = Navigator.of(
        context); // ใช้ปิด/เปิดหน้า โดยไม่อ้างอิง context หลัง await
    final messenger = ScaffoldMessenger.of(context); // ใช้แสดง SnackBar
    final errorColor = Theme.of(context).colorScheme.error; // สี error ล่วงหน้า

    // helper ภายใน method นี้เท่านั้น ไม่อ้างอิง context โดยตรง
    void showSnackLocal(String m, {bool isError = true}) {
      messenger.showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: isError ? errorColor : Colors.green[600],
      ));
    }

    final newName = Sanitize.text(_nameCtrl.text);
    final newInfo = Sanitize.text(_infoCtrl.text); // ★
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
      // ใช้ messenger ที่จับไว้เพื่อหลีกเลี่ยง context หลัง await
      showSnackLocal('ไม่มีการเปลี่ยนแปลง', isError: false);
      return;
    }

    setState(() {
      _isLoading = true;
      _busyText = 'กำลังบันทึก...';
    });

    try {
      String? serverPath = _currentImagePathRaw; // path บนเซิร์ฟเวอร์ (ถ้ามี)
      String? uiUrl; // URL สำหรับแสดงผล

      // ตรวจว่ารูปปัจจุบันเป็นลิงก์ภายนอก (เช่น จาก Google) หรือไม่
      final isCurrentExternal = (_currentImageUrl != null &&
          _currentImageUrl!.startsWith('http') &&
          !_currentImageUrl!.contains('/uploads/'));

      bool uploadedNow =
          false; // อัปโหลดรูปในรอบนี้หรือไม่ (ใหม่หรือจาก Google)

      // 1) อัปโหลดรูปใหม่ถ้ามี
      if (_newImageFile != null) {
        final constrained = await _picker.enforceConstraints(_newImageFile!);
        final uploaded = await ApiService.uploadProfileImage(constrained);
        serverPath = _normalizeServerPath(uploaded);
        final base = _composeFullUrl(serverPath);
        if (base != null) {
          uiUrl = base; // _composeFullUrl จะใส่ ?t= ให้แล้ว
        }
        uploadedNow = true;
      } else if (isCurrentExternal && (_currentImageUrl?.isNotEmpty ?? false)) {
        // 1.1 ดาวน์โหลดรูปจากภายนอก (เช่น Google) → บีบ/ย่อ → อัปโหลดเข้าระบบเรา
        try {
          final res = await http.get(Uri.parse(_currentImageUrl!));
          if (res.statusCode == 200) {
            final tmpDir = await getTemporaryDirectory();
            final tmp = File(
                '${tmpDir.path}/google_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');
            await tmp.writeAsBytes(res.bodyBytes, flush: true);
            final constrained = await _picker.enforceConstraints(tmp);
            final uploaded = await ApiService.uploadProfileImage(constrained);
            serverPath = _normalizeServerPath(uploaded);
            final base = _composeFullUrl(serverPath);
            if (base != null) {
              uiUrl = base; // มี ?t=
            }
            uploadedNow = true;
          } else {
            showSnackLocal('ดึงรูปจาก Google ไม่สำเร็จ (${res.statusCode})');
          }
        } catch (e) {
          showSnackLocal('ดึงรูปจาก Google ไม่สำเร็จ: $e');
        }
      }

      // 2) ตัดสินใจว่าจะส่ง imageUrl ไปอัปเดตหลังบ้านหรือไม่
      //    - ถ้าผู้ใช้ "ลบรูป" (ทั้ง path และ url ว่าง) → ส่ง "" เพื่อให้ BE ลบ/รีเซ็ต
      //    - ถ้าใช้ "ลิงก์ภายนอก" (เช่น จาก Google) และไม่ได้อัปโหลดใหม่ → ไม่ส่ง imageUrl (null)
      //    - ถ้าปัจจุบันเป็น path ภายใน → ส่ง path นั้น (serverPath)
      String? imageParam;
      if (uploadedNow) {
        imageParam = serverPath; // ส่ง path ที่อัปโหลดใหม่
      } else if ((_currentImageUrl == null && _currentImagePathRaw == null)) {
        imageParam = ''; // ลบรูป
      } else if (isCurrentExternal) {
        imageParam = null; // ไม่แตะรูปฝั่ง BE
      } else {
        imageParam = serverPath; // ใช้ path เดิมบนเซิร์ฟเวอร์
      }

      // ★ ส่ง profileInfo ขึ้นหลังบ้านด้วย (ถ้า API รองรับ)
      final updated = await ApiService.updateProfile(
        profileName: newName,
        imageUrl: imageParam,
        profileInfo: newInfo, // ← เพิ่มพารามิเตอร์ (optional)
      );

      // 3) คำนวณค่าที่จะเซฟลง local และ preview บน UI
      String finalPathToSave;
      String? finalShowUrl;

      if (uploadedNow) {
        // ใช้ path ที่ BE ตอบกลับ (ถ้ามี) หรือของเรา และ URL ที่มี cache buster
        final serverResponsePath =
            _normalizeServerPath(updated['image_url'] ?? serverPath) ?? '';
        finalPathToSave = serverResponsePath;
        finalShowUrl = uiUrl ?? _composeFullUrl(finalPathToSave); // มี ?t=
      } else if (_currentImageUrl == null && _currentImagePathRaw == null) {
        // ลบรูป → ให้ใช้ค่า default (ปล่อยเป็นค่าว่าง; หน้าอื่นค่อยตัดสินใจแสดง default)
        finalPathToSave = '';
        finalShowUrl = null;
      } else {
        // ใช้ path ภายในเดิม (หรือค่าที่ BE ส่งมา)
        final serverResponsePath =
            _normalizeServerPath(updated['image_url'] ?? serverPath) ?? '';
        finalPathToSave = serverResponsePath;
        finalShowUrl = _composeFullUrl(finalPathToSave); // มี ?t=
      }

      // ★ รักษา google_id เดิมไว้ใน local (ถ้า saveLogin รองรับ googleId ให้ส่งต่อ)
      final preservedGoogleId =
          ((login['google_id'] ?? login['googleId']) ?? '').toString();

      // อัปเดตเฉพาะฟิลด์ที่เปลี่ยน โดยไม่แตะ googleId (คงค่าเดิมไว้)
      await AuthService.updateLocalProfile(
        profileName: (updated['profile_name'] ?? newName).toString(),
        profileImage: finalPathToSave,
        email: (login['email'] ?? '').toString(),
        profileInfo: (updated['profile_info'] ?? newInfo).toString(),
      );

      if (!mounted) return;
      showSnackLocal('บันทึกโปรไฟล์เรียบร้อยแล้ว', isError: false);

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

      // ใช้ nav ที่จับไว้เพื่อหลีกเลี่ยงการอ้างอิง context หลัง await
      nav.pop({
        'updated': true,
        'newName': newName,
        'newImagePath': _currentImagePathRaw,
        'newImageUrl': finalShowUrl,
        'newProfileInfo': newInfo, // ★ ส่งกลับให้หน้าโปรไฟล์ใช้ได้ทันที
      });
    } on UnauthorizedException {
      showSnackLocal('เซสชันหมดอายุ กรุณาลงชื่อเข้าใช้อีกครั้ง');
      await AuthService.logout();
      // ใช้ nav ที่จับไว้แทนการเรียก Navigator.of(context) หลัง await
      nav.pushNamedAndRemoveUntil('/login', (route) => false);
    } on ApiException catch (e) {
      showSnackLocal(e.message);
    } catch (e) {
      showSnackLocal('เกิดข้อผิดพลาด: $e');
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
      return SafeImage(
        url: _currentImageUrl!,
        fit: BoxFit.cover,
        fallbackAsset: 'assets/images/default_avatar.png',
      );
    }
    return Image.asset('assets/images/default_avatar.png', fit: BoxFit.cover);
  }

  Widget _buildLoadingOverlay({String? text}) {
    return Container(
      // ปรับ alpha API ใหม่ withValues
      color: Colors.black.withValues(alpha: .35),
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
                color: Colors.black.withValues(alpha: 0.04),
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

    // ย้ายจาก WillPopScope → PopScope (API ใหม่)
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmDiscardIfNeeded()) {
          if (context.mounted) Navigator.maybePop(context);
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('แก้ไขโปรไฟล์'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              // จับ navigator ก่อน await เพื่อเลี่ยง use_build_context_synchronously
              final nav = Navigator.of(context);
              if (await _confirmDiscardIfNeeded()) {
                if (mounted) nav.pop();
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
                                      // แทนที่ withOpacity → withValues
                                      theme.colorScheme.primary
                                          .withValues(alpha: .25),
                                      theme.colorScheme.primary
                                          .withValues(alpha: .05),
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
                                        color:
                                            Colors.black.withValues(alpha: .10),
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
                          minLines: 1,
                          maxLines: 3,
                          textInputAction: TextInputAction.done,
                          maxLength: kInfoUiMax,
                          maxLengthEnforcement: MaxLengthEnforcement.enforced,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(kInfoUiMax),
                            const _MaxLinesInputFormatter(3),
                          ],
                          // แสดงตัวนับทั้งจำนวนตัวอักษรและจำนวนบรรทัด
                          buildCounter: (
                            BuildContext context, {
                            required int currentLength,
                            required bool isFocused,
                            int? maxLength,
                          }) {
                            final lines = _infoCtrl.text.split('\n').length;
                            return Text(
                              '$currentLength/${maxLength ?? kInfoUiMax} • $lines/3 บรรทัด',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: Theme.of(context).hintColor),
                            );
                          },
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

// ★ Formatter: บล็อกไม่ให้เกินจำนวนบรรทัดที่กำหนด
class _MaxLinesInputFormatter extends TextInputFormatter {
  final int maxLines;
  const _MaxLinesInputFormatter(this.maxLines);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final lines = '\n'.allMatches(text).length + 1;
    if (lines > maxLines) {
      // ป้องกันการพิมพ์ขึ้นบรรทัดใหม่เกินที่กำหนด: ปัดตกอักขระล่าสุด
      return oldValue;
    }
    return newValue;
  }
}

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
