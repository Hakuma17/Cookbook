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
  // Orchestrators
  late final _CameraHelper _cameraHelper;
  late final _ModelHelper _modelHelper;
  late final _ImageHelper _imageHelper;
  late final Future<void> _initFuture;

  bool _isBusy = false;

  // Scope rules + heuristic
  static const int _kMaxBytes = 10 * 1024 * 1024; // ≤ 10MB
  static const int _kMinDim = 224; // ≥ 224 px
  static const double _kGapTop2 = 0.10; // top1 - top2 < 0.10
  static const double _kSecondMin = 0.50; // and top2 ≥ 0.50

  @override
  void initState() {
    super.initState();
    _cameraHelper = _CameraHelper();
    _modelHelper = _ModelHelper();
    _imageHelper = _ImageHelper(context: context);
    _initFuture = _initialize();
  }

  Future<void> _initialize() async {
    try {
      await Future.wait([
        _cameraHelper.initialize(),
        _modelHelper.load(context),
      ]);
    } catch (e) {
      if (mounted) _showSnack('เกิดข้อผิดพลาดในการเริ่มต้น: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _cameraHelper.dispose();
    _modelHelper.dispose();
    super.dispose();
  }

  /* ───────────────── Actions ───────────────── */

  Future<void> _onShutterPressed(Size cameraPreviewSize) async {
    if (_isBusy) return;

    try {
      setState(() => _isBusy = true);
      final rawFile = await _cameraHelper.takePicture();
      if (rawFile == null) return;

      final cropped =
          await _imageHelper.cropPreviewFromCamera(rawFile, cameraPreviewSize);

      if (!await _enforceImageConstraints(cropped)) return;

      await _processImage(cropped);
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
      final cropped = await _imageHelper.pickAndCropFromGallery();
      if (cropped == null) return;

      if (!await _enforceImageConstraints(cropped)) return;

      await _processImage(cropped);
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

    // Heuristic เตือนรูปหลายวัตถุดิบ (ต่างกันน้อย + อันดับสองสูง)
    predictions.sort(
      (a, b) =>
          (b['confidence'] as double).compareTo(a['confidence'] as double),
    );
    if (predictions.length >= 2) {
      final c1 = predictions[0]['confidence'] as double;
      final c2 = predictions[1]['confidence'] as double;
      if ((c1 - c2) < _kGapTop2 && c2 >= _kSecondMin) {
        final goRecrop = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('ตรวจพบหลายวัตถุดิบในภาพ'),
            content: const Text(
                'โปรดครอบตัดให้ชัดเจนหรือถ่ายใหม่ โดยให้มีวัตถุดิบเดียวในภาพ'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ครอบ/ถ่ายใหม่'),
              ),
            ],
          ),
        );
        if (goRecrop == true) return;
      }
    }

    if (!mounted) return;
    final selected = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => IngredientPredictionResultScreen(
          imageFile: imageFile,
          allPredictions: predictions,
          // ถ้าอยากโชว์แบนเนอร์เตือน ให้เพิ่ม prop ทางฝั่งจอผลลัพธ์แล้วค่อยส่ง:
          // showAmbiguousBanner: (predictions.length >= 2 && (predictions[0]['confidence'] - predictions[1]['confidence']) < _kGapTop2 && (predictions[1]['confidence']) >= _kSecondMin),
        ),
      ),
    );

    if (selected != null && mounted) {
      Navigator.pop(context, selected);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // บังคับข้อกำหนดรูปภาพ: ≤10MB และอย่างน้อย 224×224
  Future<bool> _enforceImageConstraints(File f) async {
    const maxBytes = _kMaxBytes;

    Uint8List bytes = await f.readAsBytes();
    img.Image? im0 = img.decodeImage(bytes);
    if (im0 == null) {
      _showSnack('ไฟล์รูปภาพไม่ถูกต้อง');
      return false;
    }
    var im = img.bakeOrientation(im0);

    // 1) ลองบีบอัดก่อน
    for (final q in [85, 75, 65, 55, 45, 35]) {
      final jpg = img.encodeJpg(im, quality: q);
      if (jpg.lengthInBytes <= maxBytes) {
        await f.writeAsBytes(jpg, flush: true);
        return _checkMinDim(f);
      }
    }

    // 2) ค่อยๆ ลดด้านยาว + บีบซ้ำ
    for (final side in [4096, 3072, 2560, 2048, 1600, 1200]) {
      final resized = img.copyResize(
        im,
        width: im.width >= im.height ? side : null,
        height: im.height > im.width ? side : null,
        interpolation: img.Interpolation.average,
      );
      for (final q in [80, 70, 60, 50, 40]) {
        final jpg = img.encodeJpg(resized, quality: q);
        if (jpg.lengthInBytes <= maxBytes) {
          await f.writeAsBytes(jpg, flush: true);
          return _checkMinDim(f);
        }
      }
    }

    // 3) fallback สุดท้าย
    final tiny = img.copyResize(im, width: 1200);
    final jpg = img.encodeJpg(tiny, quality: 50);
    await f.writeAsBytes(jpg, flush: true);
    return _checkMinDim(f);
  }

  Future<bool> _checkMinDim(File f) async {
    final dec = img.decodeImage(await f.readAsBytes());
    if (dec == null) {
      _showSnack('อ่านรูปภาพไม่สำเร็จ');
      return false;
    }
    if (dec.width < _kMinDim || dec.height < _kMinDim) {
      _showSnack('รูปเล็กเกินไป (อย่างน้อย 224×224 พิกเซล)');
      return false;
    }
    return true;
  }

  /* ───────────────── UI ───────────────── */

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
          onPressed: () => showModalBottomSheet(
            context: context,
            builder: (ctx) {
              final t = Theme.of(ctx).textTheme;
              Widget bullet(String s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontSize: 16)),
                        Expanded(child: Text(s, style: t.bodyMedium)),
                      ],
                    ),
                  );
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📝 คำแนะนำการถ่าย/เลือกภาพ', style: t.titleLarge),
                    const SizedBox(height: 12),
                    bullet('รูปควรมี “วัตถุดิบเดียว” ชัด ๆ'),
                    bullet('พื้นหลังเรียบ แสงสว่างพอ ไม่ย้อนแสง'),
                    bullet('ครอบตัดให้วัตถุดิบเต็มกรอบพอดี'),
                    bullet('ไฟล์ไม่เกิน 10MB และขนาดอย่างน้อย 224×224 พิกเซล'),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMaskAndFrame(Size area, ThemeData theme) {
    final frameSize = area.width * 0.8;
    return IgnorePointer(
      child: ClipPath(
        clipper: _InvertedSquareClipper(frameSize: frameSize),
        child: Container(color: Colors.black.withOpacity(0.5)),
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
          IconButton(
            onPressed: onGallery,
            icon:
                const Icon(Icons.photo_library, color: Colors.white, size: 32),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              padding: const EdgeInsets.all(16),
            ),
          ),
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
          const SizedBox(width: 64, height: 64),
        ],
      ),
    );
  }
}

/* ──────────────── Helpers ──────────────── */

/// จัดการ TFLite Model
class _ModelHelper {
  late tfl.Interpreter _interpreter;
  late List<String> _labels;
  bool isReady = false;

  Future<void> load(BuildContext context) async {
    try {
      // ไม่ต้องใส่ 'assets/' นำหน้า
      _interpreter = await tfl.Interpreter.fromAsset(
        'assets/converted_tflite_quantized/model_unquant.tflite',
      );

      final labelsString = await DefaultAssetBundle.of(context)
          .loadString('assets/converted_tflite_quantized/labels.txt');

      _labels = labelsString
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map((e) => e.replaceFirst(RegExp(r'^\d+\s+'), ''))
          .toList();

      isReady = true;
    } catch (e) {
      throw Exception('Failed to load TFLite model: $e');
    }
  }

  Future<List<Map<String, dynamic>>> predict(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final decoded0 = img.decodeImage(bytes);
    if (decoded0 == null) return [];

    final decoded = img.bakeOrientation(decoded0); // ✅ ใช้ค่าที่ bake แล้ว
    final resized = img.copyResize(decoded, width: 224, height: 224);

    final input = Float32List(1 * 224 * 224 * 3);
    var i = 0;
    for (var y = 0; y < 224; y++) {
      for (var x = 0; x < 224; x++) {
        final p = resized.getPixel(x, y);
        input[i++] = p.r / 255.0;
        input[i++] = p.g / 255.0;
        input[i++] = p.b / 255.0;
      }
    }

    // ถ้าคุณไม่มี extension reshape ในโปรเจ็กต์
    // ให้แทนด้วย List 4 มิติเอง; แต่ที่นี่คงไว้ตามโปรเจ็กต์เดิม
    final output =
        List.filled(_labels.length, 0.0).reshape([1, _labels.length]);
    _interpreter.run(input.reshape([1, 224, 224, 3]), output);

    final res = <Map<String, dynamic>>[];
    for (var idx = 0; idx < _labels.length; idx++) {
      final score = (output[0][idx] as num).toDouble();
      if (score > 0.05) {
        res.add({'label': _labels[idx], 'confidence': score});
      }
    }
    res.sort((a, b) =>
        (b['confidence'] as double).compareTo(a['confidence'] as double));
    return res;
  }

  void dispose() {
    try {
      _interpreter.close();
    } catch (_) {}
  }
}

/// จัดการ Camera + Preview
class _CameraHelper {
  CameraController? _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  Future<void> initialize() async {
    // ขอสิทธิ์กล้องก่อน
    final granted = await Permission.camera.request().isGranted;
    if (!granted) throw Exception('ไม่ได้รับสิทธิ์กล้อง');

    final cams = await availableCameras();
    if (cams.isEmpty) throw Exception('ไม่พบกล้องในอุปกรณ์');

    _controller = CameraController(
      cams.first,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _controller!.initialize();
  }

  // Preview แบบ cover เต็มพื้นที่ (center-crop)
  Widget buildPreview() {
    if (!isInitialized) return const SizedBox.shrink();
    final ar = _controller!.value.aspectRatio;

    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth, h = c.maxHeight;
      final previewH = w / ar;
      final needCover = previewH < h;

      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: needCover ? h * ar : w,
          height: needCover ? h : previewH,
          child: CameraPreview(_controller!),
        ),
      );
    });
  }

  Future<File?> takePicture() async {
    if (!isInitialized) return null;
    final x = await _controller!.takePicture();
    return File(x.path);
  }

  void dispose() => _controller?.dispose();
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
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null) return null;
    return _cropImage(picked.path);
  }

  Future<File> cropPreviewFromCamera(File file, Size displayArea) async {
    final bytes = await file.readAsBytes();
    final original0 = img.decodeImage(bytes);
    if (original0 == null) return file;

    final original = img.bakeOrientation(original0);

    final imgW = original.width.toDouble();
    final imgH = original.height.toDouble();
    final scale = math.max(displayArea.width / imgW, displayArea.height / imgH);

    final frame = displayArea.width * 0.8;
    final cropSize = (frame / scale);

    final scaledW = imgW * scale;
    final scaledH = imgH * scale;
    double cx = ((scaledW - frame) / 2 / scale);
    double cy = ((scaledH - frame) / 2 / scale);

    // กันเลยขอบ
    cx = cx.clamp(0, imgW - cropSize);
    cy = cy.clamp(0, imgH - cropSize);

    final cropped = img.copyCrop(
      original,
      x: cx.round(),
      y: cy.round(),
      width: cropSize.round(),
      height: cropSize.round(),
    );

    final jpg = img.encodeJpg(cropped, quality: 90);
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    return File(path).writeAsBytes(jpg);
  }

  Future<File?> _cropImage(String filePath) async {
    final theme = Theme.of(context);
    final cropped = await ImageCropper().cropImage(
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
          lockAspectRatio: true,
        ),
        IOSUiSettings(title: 'ครอบตัดรูปภาพ', aspectRatioLockEnabled: true),
      ],
    );
    return cropped != null ? File(cropped.path) : null;
  }

  Future<bool> _ensurePhotosPermission() async {
    if (Platform.isIOS) return _requestPermission(Permission.photos);
    final info = await DeviceInfoPlugin().androidInfo;
    if (info.version.sdkInt >= 33) return true; // Android 13+ Photo Picker
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

  void _showSnack(String m) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }
}

// คลิปกรอบใสตรงกลางหน้ากล้อง
class _InvertedSquareClipper extends CustomClipper<Path> {
  final double frameSize;
  _InvertedSquareClipper({required this.frameSize});

  @override
  Path getClip(Size size) {
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
