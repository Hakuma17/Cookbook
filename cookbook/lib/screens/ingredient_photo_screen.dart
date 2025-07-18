// lib/screens/ingredient_photo_screen.dart

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import 'ingredient_prediction_result_screen.dart';

/// เรียกใช้หน้าสแกนจากภายนอก
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
  /* ─── theme ─── */
  static const _ACCENT = Color(0xFFFF9B05);

  /* ─── runtime ─── */
  bool _busy = false, _modelReady = false;

  /* ─── helpers ─── */
  final _picker = ImagePicker();
  late tfl.Interpreter _itp;
  late List<String> _labels;

  /* ─── camera ─── */
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

  /* ───────────────────────────── Model ───────────────────────────── */

  Future<void> _loadModel() async {
    try {
      _itp = await tfl.Interpreter.fromAsset(
        'assets/converted_tflite_quantized/model_unquant.tflite',
      );
      _labels = (await DefaultAssetBundle.of(context)
              .loadString('assets/converted_tflite_quantized/labels.txt'))
          .split('\n')
          .where((e) => e.trim().isNotEmpty)
          .toList();
      if (mounted) setState(() => _modelReady = true);
    } catch (e) {
      _showSnack('โหลดโมเดลล้มเหลว: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _runModel(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return [];

    img.bakeOrientation(decoded);
    final resized = img.copyResize(decoded, width: 224, height: 224);

    final input = Float32List(1 * 224 * 224 * 3);
    var bufferIndex = 0;
    for (var y = 0; y < 224; y++) {
      for (var x = 0; x < 224; x++) {
        var pixel = resized.getPixel(x, y);
        input[bufferIndex++] = pixel.r / 255.0;
        input[bufferIndex++] = pixel.g / 255.0;
        input[bufferIndex++] = pixel.b / 255.0;
      }
    }

    final output =
        List.filled(_labels.length, 0.0).reshape([1, _labels.length]);
    _itp.run(input.reshape([1, 224, 224, 3]), output);

    final res = <Map<String, dynamic>>[];
    for (var i = 0; i < _labels.length; i++) {
      final sc = output[0][i] as double;
      if (sc > 0.05) {
        res.add({'label': _labels[i], 'confidence': sc});
      }
    }
    res.sort((a, b) =>
        (b['confidence'] as double).compareTo(a['confidence'] as double));
    return res;
  }

  /* ───────────────────────────── Camera ───────────────────────────── */

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) throw 'ไม่พบกล้อง';
      _cam = CameraController(cams.first, ResolutionPreset.high,
          enableAudio: false);
      _camInit = _cam!.initialize();
      await _camInit;
      if (mounted) setState(() {});
    } catch (e) {
      _showSnack('กล้องโหลดไม่สำเร็จ: $e');
    }
  }

  /* ──────────────────────── Gallery + Crop ───────────────────────── */

  /// ครอปภาพแบบ interactive (ใช้ image_cropper)
  Future<File?> _pickAndCropImage() async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return null;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'เลือกส่วนที่ต้องการ',
          toolbarColor: Colors.white,
          toolbarWidgetColor: _ACCENT,
          activeControlsWidgetColor: _ACCENT,
          hideBottomControls: true,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'เลือกส่วนที่ต้องการ',
          aspectRatioLockEnabled: true,
        ),
      ],
    );

    return cropped != null ? File(cropped.path) : null;
  }

  /* ─────────────────────────── Processing ────────────────────────── */

  Future<void> _processPhoto(
    File rawFile, {
    Size? displayArea, // null = already-cropped
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final imgFile = displayArea == null
          ? rawFile
          : await _cropSquareLikePreview(rawFile, displayArea);

      final res = await _runModel(imgFile);

      if (res.isEmpty) {
        _showSnack('ไม่รู้จักวัตถุดิบในภาพ');
        return;
      }

      // ignore: use_build_context_synchronously
      final sel = await Navigator.push<List<String>>(
        context,
        MaterialPageRoute(
          builder: (_) => IngredientPredictionResultScreen(
            imageFile: imgFile,
            allPredictions: res,
          ),
        ),
      );
      if (sel != null && mounted) Navigator.pop(context, sel);
    } catch (e) {
      _showSnack('ประมวลผลภาพไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /* ──────────────────────── Permission ───────────────────────────── */

  Future<bool> _requestPermission(ImageSource src) async {
    if (kIsWeb) return true;
    if (src == ImageSource.camera) {
      return (await Permission.camera.request()).isGranted;
    }
    final info = await DeviceInfoPlugin().androidInfo;
    if ((info.version.sdkInt) >= 33) {
      return (await Permission.photos.request()).isGranted;
    }
    return (await Permission.storage.request()).isGranted;
  }

  /* ───────────────────────────── Crop (auto) ─────────────────────── */

  Future<File> _cropSquareLikePreview(File file, Size displayArea) async {
    final bytes = await file.readAsBytes();
    final originalImage = img.decodeImage(bytes);
    if (originalImage == null) return file;

    img.bakeOrientation(originalImage);

    final imgW = originalImage.width.toDouble();
    final imgH = originalImage.height.toDouble();
    final scale = math.max(displayArea.width / imgW, displayArea.height / imgH);

    final frameSize = displayArea.width * 0.8;
    final cropSize = (frameSize / scale);

    final scaledW = imgW * scale;
    final scaledH = imgH * scale;
    final cropX = ((scaledW - frameSize) / 2 / scale);
    final cropY = ((scaledH - frameSize) / 2 / scale);

    final croppedImage = img.copyCrop(
      originalImage,
      x: cropX.round(),
      y: cropY.round(),
      width: cropSize.round(),
      height: cropSize.round(),
    );

    return File(await _writeTempJpg(croppedImage));
  }

  Future<String> _writeTempJpg(img.Image i) async {
    final jpg = img.encodeJpg(i, quality: 90);
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(path).writeAsBytes(jpg);
    return path;
  }

  /* ───────────────────────────── UI ──────────────────────────────── */

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
            _bullet('กดไอคอนรูปภาพเพื่อเลือกรูปในเครื่อง'),
            _bullet('กรอบสี่เหลี่ยมคือพื้นที่ที่จะถูกสแกน'),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _bullet(String text) =>
      Row(children: [const Text('• '), Expanded(child: Text(text))]);

  Widget _buildCameraPreview() {
    if (_cam == null || !_cam!.value.isInitialized) {
      return Container(color: Colors.black);
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _cam!.value.previewSize!.height,
        height: _cam!.value.previewSize!.width,
        child: CameraPreview(_cam!),
      ),
    );
  }

  Widget _buildMaskAndFrame(double frame, Size area) {
    final top = (area.height - frame) / 2;
    final left = (area.width - frame) / 2;
    return Stack(
      children: [
        IgnorePointer(
          child: Stack(children: [
            Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: top,
                child: Container(color: Colors.black45)),
            Positioned(
                top: top + frame,
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(color: Colors.black45)),
            Positioned(
                top: top,
                left: 0,
                width: left,
                height: frame,
                child: Container(color: Colors.black45)),
            Positioned(
                top: top,
                right: 0,
                width: left,
                height: frame,
                child: Container(color: Colors.black45)),
          ]),
        ),
        Positioned(
          top: top,
          left: left,
          child: Container(
            width: frame,
            height: frame,
            decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(children: [
        /* ───────── Header ───────── */
        Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          color: Colors.white,
          child: SizedBox(
            height: 88,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: TextButton(
                    onPressed: () => !_busy ? Navigator.pop(context) : null,
                    child: const Text('ยกเลิก',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _ACCENT)),
                  ),
                ),
                const Text('ถ่ายรูปวัตถุดิบ',
                    style: TextStyle(
                        fontFamily: 'Josefin Sans',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: _ACCENT)),
                IconButton(
                  icon: const Icon(Icons.help_outline, color: _ACCENT),
                  tooltip: 'วิธีใช้งาน',
                  onPressed: _showHelpSheet,
                ),
              ],
            ),
          ),
        ),

        /* ───────── Camera + Controls ───────── */
        Expanded(
          child: FutureBuilder<void>(
            future: _camInit,
            builder: (_, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              return LayoutBuilder(builder: (_, cst) {
                final area = Size(cst.maxWidth, cst.maxHeight);
                final frame = area.width * 0.8;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildCameraPreview(),
                    _buildMaskAndFrame(frame, area),

                    /* ───── Controls ───── */
                    Positioned(
                      bottom: 48,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          /* ── Gallery button ── */
                          GestureDetector(
                            onTap: () async {
                              if (_busy) return;
                              if (!await _requestPermission(
                                  ImageSource.gallery)) {
                                _showSnack('ต้องการสิทธิ์เข้าถึงรูปภาพ');
                                return;
                              }
                              final file = await _pickAndCropImage();
                              if (file != null) {
                                await _processPhoto(file); // already-cropped
                              }
                            },
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(
                                  color: Colors.white24,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.photo_library,
                                  color: Colors.white, size: 32),
                            ),
                          ),
                          /* ── Shutter button ── */
                          GestureDetector(
                            onTap: () async {
                              if (_busy ||
                                  _cam == null ||
                                  !_cam!.value.isInitialized) return;
                              if (!await _requestPermission(
                                  ImageSource.camera)) {
                                _showSnack('ต้องการสิทธิ์ใช้กล้อง');
                                return;
                              }
                              final raw = await _cam!.takePicture();
                              await _processPhoto(File(raw.path),
                                  displayArea: area); // auto-crop
                            },
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 64, height: 64), // spacer
                        ],
                      ),
                    ),
                    if (_busy)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white)),
                      ),
                  ],
                );
              });
            },
          ),
        ),
      ]),
    );
  }

  /* ─── snackbar helper ─── */
  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
