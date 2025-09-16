// lib/screens/ingredient_photo_screen.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data'; // used

import 'package:camera/camera.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
// import 'package:image_cropper/image_cropper.dart'; // replaced by custom in-app cropper
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'crop_square_screen.dart';

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
      if (!mounted) return;
      final pvSize = _previewBoxSize ?? MediaQuery.of(context).size;

      final cropped = await _imageHelper.cropImageFromCoverPreview(
        rawFile,
        pvSize,
        _kFrameFraction,
      );

      if (!await _enforceImageConstraints(cropped)) return;

      await _processImage(cropped);
    } catch (e) {
      if (mounted) _showSnack('เกิดข้อผิดพลาด: $e');
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
      if (mounted) _showSnack('เกิดข้อผิดพลาด: $e');
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
    // เพิ่ม top-guard เล็กน้อยเฉพาะเครื่องที่ไม่มี safe-area บนเลย (inset < 8)
    final vp = MediaQuery.viewPaddingOf(context);
    final double topGuard = vp.top < 8 ? 8.0 : 0.0;
    return AppBar(
      backgroundColor: const Color.fromARGB(255, 251, 182, 126),
      foregroundColor: Colors.white,
      elevation: 0,
      title: Padding(
        padding: EdgeInsets.only(top: topGuard),
        child: const Text('ถ่ายรูปวัตถุดิบ'),
      ),
      leading: Padding(
        padding: EdgeInsets.only(top: topGuard),
        child: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => !_isBusy ? Navigator.pop(context) : null,
        ),
      ),
      actions: [
        Padding(
            padding: EdgeInsets.only(top: topGuard),
            child: IconButton(
              icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
              tooltip: 'ไฟฉาย',
              onPressed: () async {
                _torchOn = !_torchOn;
                await _cameraHelper.setTorch(_torchOn);
                if (mounted) setState(() {});
              },
            )),
        Padding(
          padding: EdgeInsets.only(top: topGuard),
          child: IconButton(
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
                      bullet(
                          'ไฟล์ไม่เกิน 10MB และขนาดอย่างน้อย 224×224 พิกเซล'),
                    ],
                  ),
                );
              },
            ),
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
    // บางอุปกรณ์ไม่มี safe-area ด้านล่าง (bottom inset = 0)
    // ทำให้ปุ่มไปชิดขอบและกดยาก เพราะติดขอบจอ/โซน gesture ของระบบ
    // → เพิ่ม "edge guard" ขั้นต่ำให้เสมอเมื่อ bottom inset เล็กมาก
    final viewPad = MediaQuery.viewPaddingOf(context);
    final extraBottomGuard =
        viewPad.bottom < 8.0 ? 16.0 : 0.0; // อย่างน้อยดันขึ้นอีกนิด

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
        padding: EdgeInsets.fromLTRB(24, 24, 24, 16 + extraBottomGuard),
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

  // Minimum acceptable width/height for a picked image (pre-crop)
  static const int _kMinPickDim = 224; // keep consistent with pipeline
  // Downscaled analysis size for sharpness check (longest side)
  static const int _kAnalysisSide = 640;
  // Empirical threshold for variance of Laplacian; tune if needed
  static const double _kMinSharpness = 60.0;

  // Decision for picked image confirmation flow
  static const _PickDecision _proceed = _PickDecision.proceed;
  static const _PickDecision _chooseAgain = _PickDecision.chooseAgain;
  static const _PickDecision _upscale = _PickDecision.upscale;
  static const _PickDecision _force = _PickDecision.force;

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
    // วิเคราะห์คุณภาพ ถ้าผ่านให้เข้าไปครอปทันที ถ้าไม่ผ่านให้แสดงตัวเลือก
    try {
      final f = File(picked.path);
      final bytes = await f.readAsBytes();
      final decoded0 = img.decodeImage(bytes);
      if (decoded0 == null) {
        _showSnack('ไฟล์รูปภาพไม่ถูกต้อง');
        return null;
      }
      final im = img.bakeOrientation(decoded0);
      final sharp = _estimateSharpness(im);
      final fileSize = await f.length();

      final tooSmall = im.width < _kMinPickDim || im.height < _kMinPickDim;
      final tooBlur = sharp < _kMinSharpness;

      // ถ้าผ่านเงื่อนไขทั้งหมด → ไปครอบตัดทันที (ไม่ต้องถาม)
      if (!tooSmall && !tooBlur) {
        return _cropImage(picked.path);
      }

      // ไม่ผ่าน → แสดงตัวเลือก
      final decision = await _confirmPickedInfo(
        path: picked.path,
        width: im.width,
        height: im.height,
        bytes: fileSize,
        sharpness: sharp,
        canProceed: !tooSmall && !tooBlur,
        reason: tooSmall
            ? 'รูปเล็กเกินไป (อย่างน้อย ${_kMinPickDim}×${_kMinPickDim} พิกเซล)'
            : (tooBlur
                ? 'รูปไม่คมชัด (อาจเบลอ/แตก) กรุณาเลือกรูปที่คมชัดกว่าเดิม'
                : null),
        showUpscale: tooSmall,
      );
      if (decision == _chooseAgain || decision == null) return null;
      if (decision == _proceed) {
        return _cropImage(picked.path);
      }
      if (decision == _force) {
        // ถ้าเล็กเกินไป ให้ขยายเป็นขั้นต่ำก่อน แล้วค่อยไปครอป
        if (tooSmall) {
          final up = await _upscaleToMin(im);
          return _cropImage(up.path);
        }
        return _cropImage(picked.path);
      }
      if (decision == _upscale) {
        final up = await _upscaleToMin(im);
        return _cropImage(up.path);
      }
      return null;
    } catch (_) {
      // ถ้าวิเคราะห์ไม่ได้ แสดงหน้าครอปต่อไปตามปกติ
    }
    return _cropImage(picked.path);
  }

  double _estimateSharpness(img.Image im) {
    // Downscale to normalize scale
    final longest = math.max(im.width, im.height);
    final src = longest > _kAnalysisSide
        ? img.copyResize(
            im,
            width: im.width >= im.height ? _kAnalysisSide : null,
            height: im.height > im.width ? _kAnalysisSide : null,
            interpolation: img.Interpolation.cubic,
          )
        : im;

    // Compute variance of 4-neighbor Laplacian over luminance
    double sum = 0.0, sum2 = 0.0;
    int count = 0;
    // Precompute luminance map to speed up
    final w = src.width, h = src.height;
    final lums = List<double>.filled(w * h, 0.0, growable: false);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final px = src.getPixel(x, y); // Pixel object in image v4
        final r = px.r.toDouble();
        final g = px.g.toDouble();
        final b = px.b.toDouble();
        lums[y * w + x] = 0.299 * r + 0.587 * g + 0.114 * b;
      }
    }
    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final c = lums[y * w + x];
        final l = lums[y * w + (x - 1)];
        final r = lums[y * w + (x + 1)];
        final u = lums[(y - 1) * w + x];
        final d = lums[(y + 1) * w + x];
        final lap = 4 * c - (l + r + u + d);
        sum += lap;
        sum2 += lap * lap;
        count++;
      }
    }
    if (count == 0) return 0.0;
    final mean = sum / count;
    final variance = sum2 / count - mean * mean;
    return variance.abs();
  }

  Future<_PickDecision?> _confirmPickedInfo({
    required String path,
    required int width,
    required int height,
    required int bytes,
    required double sharpness,
    required bool canProceed,
    String? reason,
    bool showUpscale = false,
  }) async {
    String humanSize(int b) {
      const units = ['B', 'KB', 'MB', 'GB'];
      double s = b.toDouble();
      int i = 0;
      while (s >= 1024 && i < units.length - 1) {
        s /= 1024;
        i++;
      }
      return '${s.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
    }

    String sharpLabel(double v) {
      if (v >= _kMinSharpness * 2) return 'คมชัดดี';
      if (v >= _kMinSharpness) return 'พอใช้';
      return 'ไม่คมชัด';
    }

    final theme = Theme.of(context);
    return showModalBottomSheet<_PickDecision>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        File(path),
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                canProceed ? Icons.check_circle : Icons.error,
                                color: canProceed
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.error,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                canProceed ? 'รูปพร้อมใช้งาน' : 'เลือกรูปใหม่',
                                style: theme.textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(spacing: 10, runSpacing: 6, children: [
                            Chip(label: Text('ขนาด ${width}×${height} px')),
                            Chip(label: Text('ไฟล์ ${humanSize(bytes)}')),
                            Chip(
                                label: Text(
                                    'ความคมชัด: ${sharpLabel(sharpness)}')),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
                if (reason != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    reason,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                LayoutBuilder(builder: (context, cts) {
                  // Use Wrap to avoid overflow on narrow screens
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context, _chooseAgain),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('เลือกใหม่'),
                      ),
                      if (showUpscale)
                        TextButton.icon(
                          onPressed: () => Navigator.pop(context, _upscale),
                          icon: const Icon(Icons.trending_up),
                          label: Text('ขยายเป็น ${_kMinPickDim} แล้วครอบ'),
                        ),
                      if (canProceed)
                        FilledButton.icon(
                          onPressed: () => Navigator.pop(context, _proceed),
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('ไปครอบตัด'),
                        )
                      else
                        (showUpscale
                            ? TextButton.icon(
                                onPressed: () => Navigator.pop(context, _force),
                                icon: const Icon(Icons.trending_up),
                                label: const Text('ใช้ต่อ (จะขยายอัตโนมัติ)'),
                              )
                            : TextButton(
                                onPressed: () => Navigator.pop(context, _force),
                                child: const Text('ใช้ต่อ (ไม่แนะนำ)'),
                              )),
                    ],
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<File> _upscaleToMin(img.Image im) async {
    final minSide = math.min(im.width, im.height);
    if (minSide >= _kMinPickDim) {
      // Already OK, return as temp file
      final dir = await getTemporaryDirectory();
      final file =
          File('${dir.path}/pass_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(img.encodeJpg(im, quality: 90), flush: true);
      return file;
    }
    final k = _kMinPickDim / minSide;
    final newW = (im.width * k).round();
    final newH = (im.height * k).round();
    final up = img.copyResize(
      im,
      width: newW,
      height: newH,
      interpolation: img.Interpolation.cubic,
    );
    final dir = await getTemporaryDirectory();
    final file =
        File('${dir.path}/up_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(img.encodeJpg(up, quality: 92), flush: true);
    return file;
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
    return Navigator.push<File?>(
      context,
      MaterialPageRoute(
        builder: (_) => CropSquareScreen(sourcePath: filePath),
        fullscreenDialog: true,
      ),
    );
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

  void _showSnack(String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }
}

enum _PickDecision {
  proceed, // go to crop normally
  chooseAgain, // re-pick from gallery
  upscale, // upscale to minimum then proceed
  force, // proceed even if not recommended
}

// ───────── Overlay (cutout 1:1)
// เลือกแนวเส้นไกด์ภายในกรอบ เพื่อช่วยจัดวางวัตถุดิบให้คงที่และมีสเกลใกล้เคียงกันทุกครั้ง
// หมายเหตุ: คอมเมนต์ไว้ 2 แบบ เปิดใช้งานได้ทีละแบบ (ปรับค่า kActiveGuideStyle)

enum GuideStyle {
  ruleOfThirds, // เส้นแบ่ง 3x3 + จุดกึ่งกลาง + มุม L-brackets — อเนกประสงค์
  dualRails, // รางคู่แนวนอน + ขีด tick ทุก 10% — เหมาะกับวัตถุดิบทรงยาว เช่น พริก
  concentricCircles, // วงแหวน 25/50/75% — เหมาะกับวัตถุดิบทรงกลม/รี ให้คุมสเกล
  measureLine, // ★ ใหม่: เส้นตั้งกลาง + ขีด marker ที่ระดับ 2/3 จากด้านบน เพื่อวัดสัดส่วนความสูง
  measureDouble, // ★★ ใหม่: เส้นแนวนอน 2 เส้น (กำหนดเปอร์เซ็นต์ได้) เพื่อเทียบระดับความสูง
}

// เลือกใช้งานหนึ่งสไตล์ (เปิด 1 บรรทัดเท่านั้น)
//const GuideStyle kActiveGuideStyle = GuideStyle.ruleOfThirds;      // เส้นแบ่ง 3x3
//const GuideStyle kActiveGuideStyle = GuideStyle.dualRails;         // เส้นรางคู่
//const GuideStyle kActiveGuideStyle = GuideStyle.concentricCircles; // วงแหวน
//const GuideStyle kActiveGuideStyle = GuideStyle.measureLine;       // เส้นวัด (หลาย marker ได้)
//const GuideStyle kActiveGuideStyle = GuideStyle.measureDouble; // สองเส้นเปอร์เซ็นต์
const GuideStyle kActiveGuideStyle =
    GuideStyle.measureLine; // <- เลือกสไตล์ที่ใช้ปัจจุบัน

// ────────────────────────────────────────────────────────────────
// ปรับตำแหน่ง marker (แนวนอน) สำหรับสไตล์ measureLine
// ค่า = สัดส่วนจากด้านบนของกรอบ (0.0 = ขอบบน, 1.0 = ขอบล่าง)
// ตัวอย่าง:
//   [0.66]                   → แสดงเฉพาะ 2/3 (ค่าเดิม)
//   [0.50, 0.66]             → เส้นที่ 50% และ 66%
//   [0.33, 0.50, 0.66]       → สามเส้น 1/3, 1/2, 2/3
// เพิ่ม/ลบค่าได้อิสระ (ค่าต้องอยู่ระหว่าง 0–1 ไม่รวมปลาย) และเรียงลำดับเองเพื่อความสวยงาม
const List<double> kMeasureLineMarkers = [0.1, 0.90];
// ความยาวขีดสั้นของ marker (พาดขวางเส้นตั้งกลาง)
const double kMeasureMarkerLen = 18.0;
// ระยะ tolerance สำหรับจับคู่ label พิเศษ (เช่น 2/3) หน่วยเป็นสัดส่วนของกรอบ
const double kLabelSnapTolerance = 0.005; // ≈0.5%
// ถ้าอยากโชว์ข้อความพิเศษแทนเปอร์เซ็นต์ ใส่ใน map นี้
final Map<double, String> kMeasureLineCustomLabels = {
  2 / 3: '2/3',
};

class _CameraOverlay extends StatelessWidget {
  const _CameraOverlay();

  @override
  Widget build(BuildContext context) {
    // ไม่กำหนด size ให้ CustomPaint → เต็ม Stack (พื้นที่เดียวกับพรีวิว)
    return CustomPaint(
      painter: _CutoutOverlayPainter(
        frameFraction: 0.8, // ใช้ค่าเดียวกับที่นำไปครอปจริง
        borderColor: Colors.white,
        borderWidth: 3.0,
        cornerRadius: 24.0,
        guideStyle: kActiveGuideStyle,
        showLabel: true,
        labelText: '', //แก้ไขข้อความแสดงบนกรอบที่นี่
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
    required this.guideStyle,
    this.showLabel = false,
    this.labelText = '',
  });

  final double frameFraction;
  final Color borderColor;
  final double borderWidth;
  final double cornerRadius;
  final GuideStyle guideStyle;
  final bool showLabel;
  final String labelText;

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

    // วาดไกด์ภายในกรอบ (clip ให้เห็นเฉพาะใน cutout)
    final frameRect = Rect.fromCenter(
      center: Offset(screenW / 2, screenH / 2),
      width: frameSize,
      height: frameSize,
    );
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(frameRect, frameRadius));

    switch (guideStyle) {
      case GuideStyle.measureLine:
        _drawMeasureLine(canvas, frameRect);
        break;
      case GuideStyle.measureDouble:
        _drawMeasureDouble(canvas, frameRect);
        break;
      case GuideStyle.ruleOfThirds:
        _drawRuleOfThirds(canvas, frameRect);
        break;
      case GuideStyle.dualRails:
        _drawDualRails(canvas, frameRect);
        break;
      case GuideStyle.concentricCircles:
        _drawConcentric(canvas, frameRect);
        break;
    }
    // วาดมุม L-brackets ให้เห็นกรอบชัดเจนทุกสไตล์
    _drawCornerBrackets(canvas, frameRect);
    canvas.restore();

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, frameRadius),
      borderPaint,
    );

    // ป้ายบอกว่า "ใช้กรอบนี้ทำนาย" ที่มุมขวาบนของกรอบ
    if (showLabel && labelText.isNotEmpty) {
      const padH = 8.0, padV = 4.0;
      final tp = TextPainter(
        text: TextSpan(
          text: labelText,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: frameRect.width - 16);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          frameRect.right - tp.width - padH * 2 - 8,
          frameRect.top + 8,
          tp.width + padH * 2,
          tp.height + padV * 2,
        ),
        const Radius.circular(8),
      );
      // พื้นหลังโปร่งดำ
      final bg = Paint()..color = Colors.black.withOpacity(0.45);
      canvas.drawRRect(rect, bg);
      // เส้นขอบอ่อนๆ
      final br = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withOpacity(0.6);
      canvas.drawRRect(rect, br);
      tp.paint(canvas, Offset(rect.left + padH, rect.top + padV));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;

  // ───────── guides ─────────
  void _drawRuleOfThirds(Canvas canvas, Rect r) {
    final paintLine = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 1.2;

    // 2 เส้นแนวตั้ง + 2 เส้นแนวนอน (แบ่ง 3 ส่วน)
    final dx = r.width / 3;
    final dy = r.height / 3;
    // แนวตั้ง
    canvas.drawLine(
        Offset(r.left + dx, r.top), Offset(r.left + dx, r.bottom), paintLine);
    canvas.drawLine(Offset(r.left + 2 * dx, r.top),
        Offset(r.left + 2 * dx, r.bottom), paintLine);
    // แนวนอน
    canvas.drawLine(
        Offset(r.left, r.top + dy), Offset(r.right, r.top + dy), paintLine);
    canvas.drawLine(Offset(r.left, r.top + 2 * dy),
        Offset(r.right, r.top + 2 * dy), paintLine);

    // จุดกึ่งกลางเล็ก ๆ
    final center = r.center;
    canvas.drawCircle(
        center, 2.0, Paint()..color = Colors.white.withOpacity(0.9));

    // มุม L-brackets เล็กน้อยช่วยกะขอบ
    final notch = 12.0;
    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    // ซ้ายบน
    canvas.drawLine(
        Offset(r.left, r.top + notch), Offset(r.left, r.top), cornerPaint);
    canvas.drawLine(
        Offset(r.left, r.top), Offset(r.left + notch, r.top), cornerPaint);
    // ขวาบน
    canvas.drawLine(
        Offset(r.right - notch, r.top), Offset(r.right, r.top), cornerPaint);
    canvas.drawLine(
        Offset(r.right, r.top), Offset(r.right, r.top + notch), cornerPaint);
    // ซ้ายล่าง
    canvas.drawLine(Offset(r.left, r.bottom - notch), Offset(r.left, r.bottom),
        cornerPaint);
    canvas.drawLine(Offset(r.left, r.bottom), Offset(r.left + notch, r.bottom),
        cornerPaint);
    // ขวาล่าง
    canvas.drawLine(Offset(r.right - notch, r.bottom),
        Offset(r.right, r.bottom), cornerPaint);
    canvas.drawLine(Offset(r.right, r.bottom - notch),
        Offset(r.right, r.bottom), cornerPaint);
  }

  void _drawDualRails(Canvas canvas, Rect r) {
    // รางคู่แนวนอน (ให้วัตถุดิบทรงยาววางขนานราง) + tick ทุก 10%
    final railPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 2.0;
    final tickPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 1.5;

    final offsetY = r.height * 0.18; // ระยะห่างรางจากกึ่งกลาง ~18% สูงพอคุมสเกล
    final y1 = r.center.dy - offsetY;
    final y2 = r.center.dy + offsetY;
    canvas.drawLine(Offset(r.left, y1), Offset(r.right, y1), railPaint);
    canvas.drawLine(Offset(r.left, y2), Offset(r.right, y2), railPaint);

    // tick ทุก 10% เพื่อกะความยาว/สเกลคงที่เวลาเปลี่ยนวัตถุดิบ
    for (int i = 1; i < 10; i++) {
      final x = r.left + r.width * (i / 10);
      canvas.drawLine(Offset(x, y1 - 6), Offset(x, y1 + 6), tickPaint);
      canvas.drawLine(Offset(x, y2 - 6), Offset(x, y2 + 6), tickPaint);
    }

    // เส้นกึ่งกลางบาง ๆ ช่วยตั้งศูนย์และวัดความยาวรวม
    final midPaint = Paint()..color = Colors.white.withOpacity(0.35);
    canvas.drawLine(
        Offset(r.left, r.center.dy), Offset(r.right, r.center.dy), midPaint);
  }

  void _drawConcentric(Canvas canvas, Rect r) {
    final center = r.center;
    final maxRadius = r.width * 0.5;
    final radii = [0.25, 0.5, 0.75].map((e) => maxRadius * e).toList();
    for (final rad in radii) {
      canvas.drawCircle(
        center,
        rad,
        Paint()
          ..color = Colors.white.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    // กากบาทเล็กที่จุดศูนย์กลาง
    final crossPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 1.0;
    const cross = 8.0;
    canvas.drawLine(Offset(center.dx - cross, center.dy),
        Offset(center.dx + cross, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy - cross),
        Offset(center.dx, center.dy + cross), crossPaint);
  }

  void _drawCornerBrackets(Canvas canvas, Rect r) {
    final notch = 14.0;
    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    // ซ้ายบน
    canvas.drawLine(
        Offset(r.left, r.top + notch), Offset(r.left, r.top), cornerPaint);
    canvas.drawLine(
        Offset(r.left, r.top), Offset(r.left + notch, r.top), cornerPaint);
    // ขวาบน
    canvas.drawLine(
        Offset(r.right - notch, r.top), Offset(r.right, r.top), cornerPaint);
    canvas.drawLine(
        Offset(r.right, r.top), Offset(r.right, r.top + notch), cornerPaint);
    // ซ้ายล่าง
    canvas.drawLine(Offset(r.left, r.bottom - notch), Offset(r.left, r.bottom),
        cornerPaint);
    canvas.drawLine(Offset(r.left, r.bottom), Offset(r.left + notch, r.bottom),
        cornerPaint);
    // ขวาล่าง
    canvas.drawLine(Offset(r.right - notch, r.bottom),
        Offset(r.right, r.bottom), cornerPaint);
    canvas.drawLine(Offset(r.right, r.bottom - notch),
        Offset(r.right, r.bottom), cornerPaint);
  }

  // ───────── measure line (ใหม่) ─────────
  // เส้นตั้งตรงกลางกรอบ + ขีด tick เล็กทุก 10% + ขีดยาวพิเศษที่ระดับ 2/3 ( ~66.67% ) จากด้านบน
  void _drawMeasureLine(Canvas canvas, Rect r) {
    final centerX = r.center.dx;
    final paintMain = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..strokeWidth = 2.0;
    final paintTick = Paint()
      ..color = Colors.white.withOpacity(0.75)
      ..strokeWidth = 1.2;
    final paintMajor = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.4;

    // เส้นหลักกลางกรอบ
    canvas.drawLine(
        Offset(centerX, r.top), Offset(centerX, r.bottom), paintMain);

    // tick ทุก 10% (สั้น ๆ) ทั้งสองฝั่ง
    for (int i = 1; i < 10; i++) {
      final y = r.top + r.height * (i / 10.0);
      final tickHalf =
          (i % 2 == 0) ? 6.0 : 4.0; // สลับความยาวเล็กน้อยให้อ่านง่าย
      canvas.drawLine(Offset(centerX - tickHalf, y),
          Offset(centerX + tickHalf, y), paintTick);
    }

    // วาด markers ตามรายการ kMeasureLineMarkers (เส้นสั้นพาดกลาง + ป้ายทางขวา)
    for (final frac in kMeasureLineMarkers) {
      if (frac <= 0 || frac >= 1) continue; // ข้ามค่าที่ผิดขอบเขต
      final y = r.top + r.height * frac;
      // ขีดยาวสั้น ๆ พาดขวางเส้นตั้ง
      canvas.drawLine(
        Offset(centerX - kMeasureMarkerLen, y),
        Offset(centerX + kMeasureMarkerLen, y),
        paintMajor,
      );

      // ป้ายอิง custom label หากระยะใกล้เคียง (±0.5%) ไม่งั้นแสดงเป็นเปอร์เซ็นต์
      String label = '${(frac * 100).round()}';
      for (final e in kMeasureLineCustomLabels.entries) {
        if ((frac - e.key).abs() <= kLabelSnapTolerance) {
          label = e.value;
          break;
        }
      }
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(centerX + kMeasureMarkerLen + 4, y - tp.height / 2),
      );
    }
  }

  // ───────── measure double (ใช้ list markers เดียวกัน แต่เส้นแนวนอนเต็มกรอบ) ─────────
  void _drawMeasureDouble(Canvas canvas, Rect r) {
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..strokeWidth = 2.2;
    final centerPaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 1.2;
    // เส้นตั้งกลางช่วยจัดตำแหน่ง
    canvas.drawLine(
        Offset(r.center.dx, r.top), Offset(r.center.dx, r.bottom), centerPaint);

    final labelStyle = const TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );
    for (final frac in kMeasureLineMarkers) {
      if (frac <= 0 || frac >= 1) continue;
      final y = r.top + r.height * frac;
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), linePaint);
      final tp = TextPainter(
        text: TextSpan(text: '${(frac * 100).round()}%', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: r.width * 0.25);
      double dy = y - tp.height - 2;
      if (dy < r.top + 4) dy = y + 4;
      if (dy + tp.height > r.bottom - 4) dy = y - tp.height - 2;
      tp.paint(canvas, Offset(r.left + 8, dy));
    }
  }
}
