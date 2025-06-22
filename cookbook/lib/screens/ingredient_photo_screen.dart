import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ingredient_prediction_result_screen.dart';

class IngredientPhotoScreen extends StatefulWidget {
  const IngredientPhotoScreen({Key? key}) : super(key: key);

  @override
  State<IngredientPhotoScreen> createState() => _IngredientPhotoScreenState();
}

class _IngredientPhotoScreenState extends State<IngredientPhotoScreen> {
  File? _imageFile;
  final _picker = ImagePicker();
  bool _picking = false; // กันเปิด picker ซ้ำ

  /* ────────────────── main pick fn ────────────────── */
  Future<void> _pickImage(ImageSource source) async {
    if (_picking) return; // ยังเปิดค้างอยู่
    _picking = true;

    try {
      // 1) ขอ permission
      if (!await _requestPermission(source)) {
        _showSnack('จำเป็นต้องอนุญาตเพื่อใช้งาน');
        return;
      }

      // 2) เปิด picker (เผื่อค้างเกิน 30 วิ)
      final XFile? picked = await _picker
          .pickImage(source: source, imageQuality: 85)
          .timeout(const Duration(seconds: 30));

      if (picked == null) return; // ยกเลิก

      final file = File(picked.path);
      if (!file.existsSync()) {
        _showSnack('ไม่พบไฟล์รูปภาพ');
        return;
      }

      if (!mounted) return;
      setState(() => _imageFile = file);

      // 3) → ไปหน้าผลลัพธ์ (สมมติว่าชื่อวัตถุดิบ = fileName โดยคร่าว ๆ)
      final basename = file.path.split('/').last.split('.').first;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IngredientPredictionResultScreen(
            imageFile: file,
            predictedName: basename,
          ),
        ),
      );
    } on TimeoutException {
      _showSnack('เปิดกล้อง/แกลอรีไม่สำเร็จ ลองใหม่อีกครั้ง');
    } on Exception catch (e) {
      if (e.toString().contains('already_active')) {
        // กรณี platformException
        _showSnack('กำลังเลือกภาพอยู่แล้ว');
      } else {
        _showSnack('เกิดข้อผิดพลาด: $e');
      }
    } finally {
      _picking = false;
    }
  }

  /* ────────────────── permission ────────────────── */
  Future<bool> _requestPermission(ImageSource src) async {
    if (kIsWeb) return true; // web ไม่ต้อง
    if (src == ImageSource.camera) {
      final cam = await Permission.camera.request();
      return cam.isGranted;
    } else {
      final storage = await Permission.photos.request();
      return storage.isGranted;
    }
  }

  /* ────────────────── helpers ────────────────── */
  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /* ────────────────── UI ────────────────── */
  @override
  Widget build(BuildContext context) {
    const brandOrange = Color(0xFFFF9B05);

    return Scaffold(
      backgroundColor: const Color(0xFFFFE3B9),
      body: SafeArea(
        child: Column(
          children: [
            /* — header — */
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade400)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ยกเลิก',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: brandOrange)),
                  ),
                  const Text('Take Photo',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: brandOrange)),
                  const SizedBox(width: 56), // balance
                ],
              ),
            ),

            /* — preview zone — */
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black, width: 4),
                    ),
                    child: _imageFile == null
                        ? const Icon(Icons.camera_alt,
                            size: 120, color: brandOrange)
                        : Image.file(_imageFile!, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),

            /* — buttons — */
            Padding(
              padding: const EdgeInsets.only(bottom: 40, top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _roundIconButton(
                    iconPath: 'assets/icons/gallery_icon.png',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                  const SizedBox(width: 40),
                  _shutterButton(onTap: () => _pickImage(ImageSource.camera)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ────────────────── small widgets ────────────────── */

  Widget _roundIconButton(
      {required String iconPath, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Image.asset(iconPath, width: 60, height: 60),
    );
  }

  Widget _shutterButton({required VoidCallback onTap}) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black, width: 1.2),
          ),
          alignment: Alignment.center,
          child: const CircleAvatar(radius: 30, backgroundColor: Colors.black),
        ),
      );
}
