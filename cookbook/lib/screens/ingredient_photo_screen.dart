// lib/screens/ingredient_photo_screen.dart
// ©2025  – เวอร์ชันปรับปรุงตาม mock-up + ครอปรูปเป็นสี่เหลี่ยมจัตุรัสก่อนส่งเข้าโมเดล

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:path_provider/path_provider.dart';

import 'ingredient_prediction_result_screen.dart';

// เรียกใช้หน้าสแกนวัตถุดิบจากที่อื่น
Future<List<String>?> scanIngredient(BuildContext ctx) =>
    Navigator.push<List<String>>(
      ctx,
      MaterialPageRoute(builder: (_) => const IngredientPhotoScreen()),
    );

class IngredientPhotoScreen extends StatefulWidget {
  const IngredientPhotoScreen({super.key});

  @override
  State<IngredientPhotoScreen> createState() => _IngredientPhotoScreenState();
}

class _IngredientPhotoScreenState extends State<IngredientPhotoScreen> {
  //─── สีและอัตราส่วน ───────────────────────────────
  static const _BG = Color(0xFFFFEED6);
  static const _ACCENT = Color(0xFFFF9B05);
  static const double _FRAME_RATIO = 1; // 1:1

  //─── สถานะ runtime ───────────────────────────────
  bool _busy = false;
  bool _modelReady = false;

  //─── helpers ────────────────────────────────────────
  final _picker = ImagePicker();
  late tfl.Interpreter _itp;
  late List<String> _labels;

  //─── กล้อง ───────────────────────────────────────────
  CameraController? _cam;
  late Future<void> _camInit;

  @override
  void initState() {
    super.initState();
    _loadModel();
    _initCamera();
  }

  @override
  void dispose() {
    _itp.close();
    _cam?.dispose();
    super.dispose();
  }

  /// โหลดโมเดลและ labels จาก assets
  Future<void> _loadModel() async {
    try {
      _itp = await tfl.Interpreter.fromAsset(
          'assets/converted_tflite_quantized/model_unquant.tflite')
        ..allocateTensors();
      _labels = (await rootBundle
              .loadString('assets/converted_tflite_quantized/labels.txt'))
          .split('\n')
          .where((e) => e.trim().isNotEmpty)
          .toList();
      setState(() => _modelReady = true);
    } catch (e) {
      _showSnack('โหลดโมเดลล้มเหลว: $e');
    }
  }

  /// ประมวลผลภาพด้วย TFLite → คืน list ของ { label, confidence }
  Future<List<Map<String, dynamic>>> _runModel(File imgFile) async {
    final bytes = await imgFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return [];
    final resized = img.copyResize(decoded, width: 224, height: 224);
    final rgb = resized.getBytes();
    final input = Float32List(rgb.length)..setAll(0, rgb.map((e) => e / 255.0));
    final output =
        List.filled(_labels.length, 0.0).reshape([1, _labels.length]);
    _itp.run(input.reshape([1, 224, 224, 3]), output);
    final res = <Map<String, dynamic>>[];
    for (var i = 0; i < _labels.length; i++) {
      final scr = output[0][i] as double;
      if (scr > 0.05) res.add({'label': _labels[i], 'confidence': scr});
    }
    res.sort((a, b) =>
        (b['confidence'] as double).compareTo(a['confidence'] as double));
    return res;
  }

  /// เตรียมกล้องและตั้ง aspect ratio ให้ตรงกับ preview
  Future<void> _initCamera() async {
    final cams = await availableCameras();
    final cam = cams.first;
    _cam = CameraController(cam, ResolutionPreset.medium);
    _camInit = _cam!.initialize();
    await _camInit;
    if (mounted) setState(() {});
  }

  /// ถ่ายภาพ, ครอปเป็นสี่เหลี่ยมจัตุรัส แล้วรันโมเดล
  Future<void> _takePicture() async {
    if (!_modelReady || _cam == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _camInit;
      final raw = await _cam!.takePicture();
      final sq = await _centerCropSquare(File(raw.path));
      final res = await _runModel(sq);
      if (res.isEmpty) {
        setState(() => _busy = false);
        return;
      }
      final top = res.first;
      final sel = await Navigator.push<List<String>>(
        context,
        MaterialPageRoute(
          builder: (_) => IngredientPredictionResultScreen(
            imageFile: sq,
            predictedName: top['label'] as String,
            confidence: top['confidence'] as double,
          ),
        ),
      );
      if (sel != null) Navigator.pop(context, sel);
    } catch (e) {
      _showSnack('ถ่ายภาพไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// เลือกรูปจาก gallery แล้วประมวลผลเหมือนกับกล้อง
  Future<void> _pickImage(ImageSource src) async {
    if (_busy || !_modelReady) return;
    setState(() => _busy = true);
    if (!await _requestPermission(src)) {
      _showSnack('ไม่ได้รับสิทธิ์เข้าถึง');
      setState(() => _busy = false);
      return;
    }
    final picked = await _picker.pickImage(source: src, imageQuality: 85);
    if (picked == null) {
      setState(() => _busy = false);
      return;
    }
    final sq = await _centerCropSquare(File(picked.path));
    final res = await _runModel(sq);
    setState(() => _busy = false);
    if (res.isEmpty) return;
    final top = res.first;
    final sel = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => IngredientPredictionResultScreen(
          imageFile: sq,
          predictedName: top['label'] as String,
          confidence: top['confidence'] as double,
        ),
      ),
    );
    if (sel != null) Navigator.pop(context, sel);
  }

  /// ขอสิทธิ์กล้อง/รูปภาพ
  Future<bool> _requestPermission(ImageSource src) async {
    if (kIsWeb) return true;
    if (src == ImageSource.camera) {
      return (await Permission.camera.request()).isGranted;
    }
    final info = await DeviceInfoPlugin().androidInfo;
    if ((info.version.sdkInt ?? 0) >= 33) {
      return (await Permission.photos.request()).isGranted;
    }
    return (await Permission.storage.request()).isGranted;
  }

  /// ครอปรูป “ตรงกลาง” เป็นสี่เหลี่ยมจัตุรัส
  Future<File> _centerCropSquare(File file) async {
    final bytes = await file.readAsBytes();
    final origin = img.decodeImage(bytes);
    if (origin == null) return file;
    final size = origin.width < origin.height ? origin.width : origin.height;
    final offX = (origin.width - size) ~/ 2;
    final offY = (origin.height - size) ~/ 2;
    final cropped =
        img.copyCrop(origin, x: offX, y: offY, width: size, height: size);
    final jpg = img.encodeJpg(cropped, quality: 90);
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    return File(path)..writeAsBytesSync(jpg);
  }

  /// แสดงคำแนะนำเล็ก ๆ บนหน้า Scan
  void _showHelpSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📸 วิธีใช้หน้านี้',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            _bullet('กดปุ่มชัตเตอร์ (วงกลม) เพื่อถ่ายรูป'),
            _bullet('กดไอคอนรูป 📷 เพื่อเลือกรูปในเครื่อง'),
            _bullet('กรอบสี่เหลี่ยมคือพื้นที่ที่จะถูกสแกน'),
            _bullet('รอผลทำนายแล้วเลือกชื่อที่ถูกต้อง'),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _bullet(String text) =>
      Row(children: [const Text('• '), Expanded(child: Text(text))]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _BG,
      body: Stack(
        children: [
          // กล้องสด
          if (_cam != null)
            FutureBuilder(
              future: _camInit,
              builder: (_, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Center(
                  child: AspectRatio(
                    aspectRatio: _cam!.value.aspectRatio,
                    child: CameraPreview(_cam!),
                  ),
                );
              },
            ),

          // overlay กรอบ 1:1
          Align(
            alignment: Alignment.center,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.width * 0.8 / _FRAME_RATIO,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
              ),
            ),
          ),

          // header
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ปุ่มยกเลิก
                  GestureDetector(
                    onTap: () {
                      if (!_busy) Navigator.pop(context);
                    },
                    child: const Text(
                      'ยกเลิก',
                      style: TextStyle(
                        fontSize: 18,
                        color: _ACCENT,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // ชื่อหน้าจอ
                  Text(
                    'ถ่ายรูปวัตถุดิบ',
                    style: TextStyle(
                      fontFamily: 'Josefin Sans',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: _ACCENT,
                    ),
                  ),
                  // ปุ่มช่วยเหลือ
                  IconButton(
                    icon: const Icon(Icons.help_outline, color: _ACCENT),
                    tooltip: 'วิธีใช้งาน',
                    onPressed: _showHelpSheet,
                  ),
                ],
              ),
            ),
          ),

          // controls (gallery + shutter)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // gallery
                  GestureDetector(
                    onTap: () => _pickImage(ImageSource.gallery),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 3)
                        ],
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Image.asset(
                        'assets/icons/gallery_icon.png',
                        width: 52,
                        height: 52,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                  // shutter
                  GestureDetector(
                    onTap: _takePicture,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black,
                        border: Border.all(color: Colors.black, width: 1.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
