// lib/screens/ingredient_photo_screen.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import 'ingredient_prediction_result_screen.dart';

/// ------------------------------------------------------------
/// เรียกใช้จากภายนอก
///   - กดยกเลิก → []
///   - เลือกผลลัพธ์ → รายการชื่อที่เลือก
/// ------------------------------------------------------------
Future<List<String>> scanIngredient(BuildContext ctx) async {
  final res = await Navigator.push<List<String>>(
    ctx,
    MaterialPageRoute(builder: (_) => const IngredientPhotoScreen()),
  );
  return res ?? const <String>[];
}

/// ------------------------------------------------------------
/// หน้าสแกน (ล็อคแนวตั้ง)
/// ------------------------------------------------------------
class IngredientPhotoScreen extends StatelessWidget {
  const IngredientPhotoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    return const _IngredientPhotoScreenStateful();
  }
}

class _IngredientPhotoScreenStateful extends StatefulWidget {
  const _IngredientPhotoScreenStateful();

  @override
  State<_IngredientPhotoScreenStateful> createState() =>
      _IngredientPhotoScreenState();
}

class _IngredientPhotoScreenState
    extends State<_IngredientPhotoScreenStateful> {
  // ───────── Orchestrators
  late final _CameraHelper _cameraHelper;
  late final _ModelHelper _modelHelper;
  late final _ImageHelper _imageHelper;
  late final Future<void> _initFuture;

  bool _isBusy = false;

  // ★ กรอบสแกน (1:1)
  static const double _kFrameFraction = 0.80; // 80% ของด้านสั้น

  // Heuristic
  static const int _kMaxBytes = 10 * 1024 * 1024;
  static const int _kMinDim = 224;
  static const double _kGapTop2 = 0.10;
  static const double _kSecondMin = 0.50;

  // ★ Zoom & Torch
  double _zoom = 1.0;
  double _baseZoom = 1.0;
  bool _torchOn = false;

  // ★ ขนาด “กล่องพรีวิวจริง” (พื้นที่ของ body ใต้ AppBar)
  Size? _previewBoxSize;

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
      _zoom = 1.0;
      _baseZoom = 1.0;
      await _cameraHelper.setZoom(_zoom);
      await _cameraHelper.setTorch(false);
    } catch (e) {
      if (mounted) _showSnack('เกิดข้อผิดพลาดในการเริ่มต้น: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _cameraHelper.dispose();
    _modelHelper.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  // ───────── Actions

  Future<void> _onShutterPressed() async {
    if (_isBusy) return;
    try {
      setState(() => _isBusy = true);
      final rawFile = await _cameraHelper.takePicture();
      if (rawFile == null) return;

      //   ใช้ “ขนาดกล่องพรีวิวจริง” แทน MediaQuery.size
      final pvSize = _previewBoxSize ?? MediaQuery.of(context).size;

      final cropped = await _imageHelper.cropImageFromCoverPreview(
        rawFile,
        pvSize,
        _kFrameFraction,
      );

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
                  child: const Text('ยกเลิก')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('ครอบ/ถ่ายใหม่')),
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

  Future<bool> _enforceImageConstraints(File f) async {
    const maxBytes = _kMaxBytes;

    Uint8List bytes = await f.readAsBytes();
    img.Image? im0 = img.decodeImage(bytes);
    if (im0 == null) {
      _showSnack('ไฟล์รูปภาพไม่ถูกต้อง');
      return false;
    }
    var im = img.bakeOrientation(im0);

    for (final q in [85, 75, 65, 55, 45, 35]) {
      final jpg = img.encodeJpg(im, quality: q);
      if (jpg.lengthInBytes <= maxBytes) {
        await f.writeAsBytes(jpg, flush: true);
        return _checkMinDim(f);
      }
    }

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

  // ───────── UI

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

          // ★ ใช้ LayoutBuilder เพื่อได้ “ขนาดพื้นที่จริงของพรีวิว/overlay”
          return LayoutBuilder(
            builder: (ctx, cons) {
              _previewBoxSize = Size(cons.maxWidth, cons.maxHeight);

              return GestureDetector(
                onScaleStart: (d) => _baseZoom = _zoom,
                onScaleUpdate: (d) async {
                  final next = (_baseZoom * d.scale)
                      .clamp(_cameraHelper.minZoom, _cameraHelper.maxZoom);
                  if ((next - _zoom).abs() > 0.01) {
                    _zoom = next;
                    await _cameraHelper.setZoom(_zoom);
                    if (mounted) setState(() {});
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // ───────── ส่วนพรีวิว (cover)
                    _cameraHelper.buildPreview(),

                    // ───────── ส่วน Overlay (cutout)
                    const _CameraOverlay(), // ไม่กำหนด size → เต็ม Stack

                    // ───────── ส่วนปุ่ม/คอนโทรล
                    _buildControls(
                      theme: theme,
                      onShutter: _onShutterPressed,
                      onGallery: _onGalleryPressed,
                    ),

                    if (_isBusy)
                      Container(
                        color: Colors.black45,
                        child: const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white)),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: const Color.fromARGB(255, 251, 182, 126),
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Text('ถ่ายรูปวัตถุดิบ'),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => !_isBusy ? Navigator.pop(context) : null,
      ),
      actions: [
        IconButton(
          icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
          tooltip: 'ไฟฉาย',
          onPressed: () async {
            _torchOn = !_torchOn;
            await _cameraHelper.setTorch(_torchOn);
            if (mounted) setState(() {});
          },
        ),
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
                    bullet('จัดวางวัตถุดิบให้อยู่ในกรอบสี่เหลี่ยม (1:1)'),
                    bullet('พื้นหลังเรียบ แสงสว่างพอ ไม่ย้อนแสง'),
                    bullet('ถ้ามีหลายวัตถุดิบ ให้ครอบให้เหลือชิ้นเดียว'),
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

  Widget _buildControls({
    required ThemeData theme,
    required VoidCallback onShutter,
    required VoidCallback onGallery,
  }) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        // ───────── ส่วนปุ่ม
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'จัดวางวัตถุดิบให้อยู่ในกรอบ',
                style: TextStyle(
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ปุ่มแกลเลอรี
                  IconButton(
                    onPressed: onGallery,
                    icon: const Icon(Icons.photo_library_outlined, size: 32),
                    color: Colors.white,
                  ),

                  // ปุ่มชัตเตอร์
                  GestureDetector(
                    onTap: onShutter,
                    child: Container(
                      width: 76,
                      height: 76,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white70, width: 2),
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // ตัวบอกระดับซูม
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: Text(
                        '${_zoom.toStringAsFixed(1)}x',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────── Helpers: TFLite
class _ModelHelper {
  late tfl.Interpreter _interpreter;
  late List<String> _labels;
  bool isReady = false;

  Future<void> load(BuildContext context) async {
    try {
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

    final decoded = img.bakeOrientation(decoded0);
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

// ───────── Helpers: Camera + Preview
class _CameraHelper {
  CameraController? _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  double minZoom = 1.0;
  double maxZoom = 1.0;

  double get aspectRatio => _controller?.value.aspectRatio ?? 1.0;

  Future<void> initialize() async {
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

    try {
      minZoom = await _controller!.getMinZoomLevel();
      maxZoom = await _controller!.getMaxZoomLevel();
    } catch (_) {
      minZoom = 1.0;
      maxZoom = 4.0;
    }
  }

  Widget buildPreview() {
    if (!isInitialized) return const SizedBox.shrink();

    // ───────── ส่วนพรีวิว (cover เต็มกล่อง)
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _controller!.value.previewSize!.height,
        height: _controller!.value.previewSize!.width,
        child: CameraPreview(_controller!),
      ),
    );
  }

  Future<void> setZoom(double level) async {
    if (!isInitialized) return;
    try {
      await _controller!.setZoomLevel(level.clamp(minZoom, maxZoom));
    } catch (_) {}
  }

  Future<void> setTorch(bool on) async {
    if (!isInitialized) return;
    try {
      await _controller!.setFlashMode(on ? FlashMode.torch : FlashMode.off);
    } catch (_) {}
  }

  Future<File?> takePicture() async {
    if (!isInitialized) return null;
    final x = await _controller!.takePicture();
    return File(x.path);
  }

  void dispose() => _controller?.dispose();
}

// ───────── Helpers: Image Picker/Cropper/Perms + “ครอปตามกรอบ”
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

  ///   ครอปตามกรอบ 1:1 บน **พื้นที่พรีวิวจริง (previewBoxSize)** ที่แสดงแบบ cover
  Future<File> cropImageFromCoverPreview(
    File file,
    Size previewBoxSize,
    double frameFraction,
  ) async {
    final bytes = await file.readAsBytes();
    final original0 = img.decodeImage(bytes);
    if (original0 == null) return file;

    final original = img.bakeOrientation(original0);
    final imgW = original.width.toDouble();
    final imgH = original.height.toDouble();

    // พรีวิวถูกวาดแบบ cover → scale คือ max สองด้าน
    final pvW = previewBoxSize.width;
    final pvH = previewBoxSize.height;
    final scale = math.max(imgW / pvW, imgH / pvH);

    // ระยะกินขอบที่โดนตัดทิ้งหลัง cover
    final offsetX = (imgW - pvW * scale) / 2.0;
    final offsetY = (imgH - pvH * scale) / 2.0;

    // กรอบสแกนบนหน้าจอ (สี่เหลี่ยมจัตุรัสกลางจอ)
    final frameScreenSize = math.min(pvW, pvH) * frameFraction;
    final frameScreenX = (pvW - frameScreenSize) / 2.0;
    final frameScreenY = (pvH - frameScreenSize) / 2.0;

    // แปลงพิกัดจาก preview-space → image-space
    final cropX = offsetX + frameScreenX * scale;
    final cropY = offsetY + frameScreenY * scale;
    final cropSize = frameScreenSize * scale;

    final cropped = img.copyCrop(
      original,
      x: cropX.round().clamp(0, imgW.toInt() - 1),
      y: cropY.round().clamp(0, imgH.toInt() - 1),
      width: cropSize.round().clamp(1, imgW.toInt()),
      height: cropSize.round().clamp(1, imgH.toInt()),
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
    if (info.version.sdkInt >= 33) return true;
    return _requestPermission(Permission.storage);
  }

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
  }

  void _showSnack(String m) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }
}

// ───────── Overlay (cutout 1:1)
class _CameraOverlay extends StatelessWidget {
  const _CameraOverlay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ไม่กำหนด size ให้ CustomPaint → เต็ม Stack (พื้นที่เดียวกับพรีวิว)
    return CustomPaint(
      painter: _CutoutOverlayPainter(
        frameFraction: 0.8,
        borderColor: Colors.white,
        borderWidth: 3.0,
        cornerRadius: 24.0,
      ),
    );
  }
}

class _CutoutOverlayPainter extends CustomPainter {
  _CutoutOverlayPainter({
    required this.frameFraction,
    required this.borderColor,
    required this.borderWidth,
    required this.cornerRadius,
  });

  final double frameFraction;
  final Color borderColor;
  final double borderWidth;
  final double cornerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final screenW = size.width;
    final screenH = size.height;
    final frameSize = math.min(screenW, screenH) * frameFraction;
    final frameRadius = Radius.circular(cornerRadius);

    final fullScreenPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, screenW, screenH));
    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(screenW / 2, screenH / 2),
            width: frameSize,
            height: frameSize,
          ),
          frameRadius,
        ),
      );

    final overlayPath =
        Path.combine(PathOperation.difference, fullScreenPath, cutoutPath);

    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.5);
    canvas.drawPath(overlayPath, overlayPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(screenW / 2, screenH / 2),
          width: frameSize,
          height: frameSize,
        ),
        frameRadius,
      ),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
