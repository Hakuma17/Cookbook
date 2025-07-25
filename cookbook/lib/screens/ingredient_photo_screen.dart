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
  // ✅ 1. State หลักจะทำหน้าที่เป็น "ผู้ควบคุม" (Orchestrator) เท่านั้น
  late final _CameraHelper _cameraHelper;
  late final _ModelHelper _modelHelper;
  late final _ImageHelper _imageHelper;
  late final Future<void> _initFuture;

  bool _isBusy = false; // สถานะการประมวลผล

  @override
  void initState() {
    super.initState();
    // สร้าง instance ของ helpers
    _cameraHelper = _CameraHelper();
    _modelHelper = _ModelHelper();
    _imageHelper = _ImageHelper(context: context);

    // ใช้ Future เดียวในการ initialize ทุกอย่างพร้อมกัน
    _initFuture = _initialize();
  }

  Future<void> _initialize() async {
    try {
      await Future.wait([
        _cameraHelper.initialize(),
        _modelHelper.load(context),
      ]);
    } catch (e) {
      // ถ้าเกิดข้อผิดพลาดร้ายแรงระหว่าง init, แสดงผลใน UI
      if (mounted) _showSnack('เกิดข้อผิดพลาดในการเริ่มต้น: $e');
      rethrow; // โยน error ต่อเพื่อให้ FutureBuilder แสดงผล
    }
  }

  @override
  void dispose() {
    _cameraHelper.dispose();
    _modelHelper.dispose();
    super.dispose();
  }

  /* ─────────────────────────── Actions ────────────────────────── */

  Future<void> _onShutterPressed(Size cameraPreviewSize) async {
    if (_isBusy) return;

    try {
      setState(() => _isBusy = true);
      final rawFile = await _cameraHelper.takePicture();
      if (rawFile == null) return;

      final croppedFile =
          await _imageHelper.cropPreviewFromCamera(rawFile, cameraPreviewSize);
      await _processImage(croppedFile);
    } catch (e) {
      _showSnack('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _onGalleryPressed() async {
    if (_isBusy) return;

    try {
      setState(() => _isBusy = true);
      final croppedFile = await _imageHelper.pickAndCropFromGallery();
      if (croppedFile == null) return;

      await _processImage(croppedFile);
    } catch (e) {
      _showSnack('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _processImage(File imageFile) async {
    if (!_modelHelper.isReady) {
      _showSnack('โมเดลยังไม่พร้อมใช้งาน');
      return;
    }

    final predictions = await _modelHelper.predict(imageFile);
    if (predictions.isEmpty) {
      _showSnack('ไม่รู้จักวัตถุดิบในภาพ');
      return;
    }

    if (!mounted) return;
    final selectedIngredients = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => IngredientPredictionResultScreen(
          imageFile: imageFile,
          allPredictions: predictions,
        ),
      ),
    );

    if (selectedIngredients != null && mounted) {
      Navigator.pop(context, selectedIngredients);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /* ───────────────────────────── UI Build ──────────────────────── */

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(theme),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }
          if (snapshot.hasError || !_cameraHelper.isInitialized) {
            return Center(
              child: Text(
                'ไม่สามารถเปิดกล้องได้\n${snapshot.error ?? ''}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          return Stack(
            alignment: Alignment.center,
            children: [
              // Camera Preview
              LayoutBuilder(builder: (context, constraints) {
                final area = Size(constraints.maxWidth, constraints.maxHeight);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    _cameraHelper.buildPreview(),
                    _buildMaskAndFrame(area, theme),
                    _buildControls(
                      theme: theme,
                      onShutter: () => _onShutterPressed(area),
                      onGallery: _onGalleryPressed,
                    ),
                  ],
                );
              }),
              // Loading Overlay
              if (_isBusy)
                Container(
                  color: Colors.black54,
                  child: const Center(
                      child: CircularProgressIndicator(color: Colors.white)),
                ),
            ],
          );
        },
      ),
    );
  }

  // ✅ 2. UI ถูก Refactor และใช้ Theme ทั้งหมด
  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
      title: Text('ถ่ายรูปวัตถุดิบ',
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold)),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => !_isBusy ? Navigator.pop(context) : null,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline),
          onPressed: () {/* TODO: Implement help dialog */},
        ),
      ],
    );
  }

  Widget _buildMaskAndFrame(Size area, ThemeData theme) {
    final frameSize = area.width * 0.8;
    return IgnorePointer(
      child: ClipPath(
        clipper: _InvertedSquareClipper(frameSize: frameSize),
        child: Container(
          color: Colors.black.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildControls({
    required ThemeData theme,
    required VoidCallback onShutter,
    required VoidCallback onGallery,
  }) {
    return Positioned(
      bottom: 48,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Gallery Button
          IconButton(
            onPressed: onGallery,
            icon:
                const Icon(Icons.photo_library, color: Colors.white, size: 32),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              padding: const EdgeInsets.all(16),
            ),
          ),
          // Shutter Button
          GestureDetector(
            onTap: onShutter,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
            ),
          ),
          // Spacer to balance the layout
          const SizedBox(width: 64, height: 64),
        ],
      ),
    );
  }
}

/* ──────────────── Helper Classes ──────────────── */
// ✅ 3. แยก Logic ออกมาเป็นคลาสย่อยๆ เพื่อให้จัดการง่าย

/// จัดการ TFLite Model
class _ModelHelper {
  late tfl.Interpreter _interpreter;
  late List<String> _labels;
  bool isReady = false;

  Future<void> load(BuildContext context) async {
    try {
      _interpreter = await tfl.Interpreter.fromAsset(
          'assets/converted_tflite_quantized/model_unquant.tflite');
      final labelsString = await DefaultAssetBundle.of(context)
          .loadString('assets/converted_tflite_quantized/labels.txt');
      _labels =
          labelsString.split('\n').where((e) => e.trim().isNotEmpty).toList();
      isReady = true;
    } catch (e) {
      throw Exception('Failed to load TFLite model: $e');
    }
  }

  Future<List<Map<String, dynamic>>> predict(File imageFile) async {
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
    _interpreter.run(input.reshape([1, 224, 224, 3]), output);

    final res = <Map<String, dynamic>>[];
    for (var i = 0; i < _labels.length; i++) {
      final score = output[0][i] as double;
      if (score > 0.05) {
        // Confidence threshold
        res.add({'label': _labels[i], 'confidence': score});
      }
    }
    res.sort((a, b) =>
        (b['confidence'] as double).compareTo(a['confidence'] as double));
    return res;
  }

  void dispose() {
    _interpreter.close();
  }
}

/// จัดการ Camera
class _CameraHelper {
  CameraController? _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  Future<void> initialize() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception('ไม่พบกล้องในอุปกรณ์');
    _controller = CameraController(cameras.first, ResolutionPreset.high,
        enableAudio: false);
    await _controller!.initialize();
  }

  Widget buildPreview() {
    if (!isInitialized) return const SizedBox.shrink();
    // CameraPreview ต้องถูกห่อด้วย widget ที่กำหนดขนาดและอัตราส่วนให้ถูกต้อง
    // ในที่นี้เราใช้ FittedBox ใน parent แต่การคำนวณที่แม่นยำอาจจำเป็น
    return Transform.scale(
      scale: 1 /
          (_controller!.value.aspectRatio * (9 / 16)), // ปรับแก้ตามอัตราส่วนจอ
      child: Center(
        child: CameraPreview(_controller!),
      ),
    );
  }

  Future<File?> takePicture() async {
    if (!isInitialized) return null;
    final xfile = await _controller!.takePicture();
    return File(xfile.path);
  }

  void dispose() {
    _controller?.dispose();
  }
}

/// จัดการ Image Picker, Cropper, และ Permissions
class _ImageHelper {
  final BuildContext context;
  final ImagePicker _picker = ImagePicker();

  _ImageHelper({required this.context});

  Future<File?> pickAndCropFromGallery() async {
    if (!await _ensurePhotosPermission()) {
      _showSnack('ไม่ได้รับสิทธิ์เข้าถึงคลังภาพ');
      return null;
    }
    final pickedFile =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (pickedFile == null) return null;

    return _cropImage(pickedFile.path);
  }

  Future<File> cropPreviewFromCamera(File file, Size displayArea) async {
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

    final jpg = img.encodeJpg(croppedImage, quality: 90);
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    return await File(path).writeAsBytes(jpg);
  }

  Future<File?> _cropImage(String filePath) async {
    final theme = Theme.of(context);
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: filePath,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 80,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
            toolbarTitle: 'ครอบตัดรูปภาพ',
            toolbarColor: theme.colorScheme.primary,
            toolbarWidgetColor: theme.colorScheme.onPrimary,
            backgroundColor: Colors.black,
            activeControlsWidgetColor: theme.colorScheme.primary,
            lockAspectRatio: true),
        IOSUiSettings(
          title: 'ครอบตัดรูปภาพ',
          aspectRatioLockEnabled: true,
        ),
      ],
    );
    return croppedFile != null ? File(croppedFile.path) : null;
  }

  Future<bool> _ensurePhotosPermission() async {
    if (Platform.isIOS) return _requestPermission(Permission.photos);

    final info = await DeviceInfoPlugin().androidInfo;
    if (info.version.sdkInt >= 33) return true; // Android 13+ ไม่ต้องขอ

    return _requestPermission(Permission.storage);
  }

  // ignore: unused_element
  Future<bool> _ensureCameraPermission() =>
      _requestPermission(Permission.camera);

  Future<bool> _requestPermission(Permission permission) async {
    final status = await permission.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      _showOpenSettingsDialog();
      return false;
    }
    return await permission.request().isGranted;
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
            child: const Text('ยกเลิก'),
          ),
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
  }

  void _showSnack(String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// Helper Clipper สำหรับสร้างกรอบใส
class _InvertedSquareClipper extends CustomClipper<Path> {
  final double frameSize;
  _InvertedSquareClipper({required this.frameSize});

  @override
  Path getClip(Size size) {
    // สร้าง Path รูปสี่เหลี่ยมเต็มพื้นที่ แล้วเจาะรูตรงกลาง
    return Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(Rect.fromCenter(
        center: size.center(Offset.zero),
        width: frameSize,
        height: frameSize,
      ))
      ..fillType = PathFillType.evenOdd;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
