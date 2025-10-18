// lib/screens/ingredient_photo_screen.dart
import 'dart:io';
import 'dart:math' as math;
// import 'dart:typed_data'; // ไม่จำเป็นอีกต่อไป
import 'dart:typed_data'; // ✅ ต้องใช้สำหรับ Float32List (เพิ่มเพื่อความชัดเจน)

import 'package:camera/camera.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
// import 'package:image_cropper/image_cropper.dart'; // ถูกแทนด้วยตัวครอปในแอป
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'crop_square_screen.dart';

import 'ingredient_prediction_result_screen.dart';

// ✅ Move enum outside of class
enum Norm { zeroOne, minusOneToOne } // สูตร normalize

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
  // Debug-only: bypass cover-crop step to verify if cropping causes mismatch
  bool _devBypassCoverCrop = false;

  // ★ AI Mode toggles (ซ่อนจาก UI แต่ยังทำงาน - เปิด TM N11)
  bool _aiEnhancementMode = false; // โหมดปรับปรุงภาพ (ปิด)
  bool _aiStretchResizeMode = true; // โหมด TM stretch resize (เปิด)
  bool _aiNormalizationMode = true; // โหมด [-1,1] normalization (เปิด)
  bool _aiDebugMode = false; // โหมด debug input dump (ปิด)

  @override
  void initState() {
    super.initState();

    // 🎯 System UI configuration
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    _cameraHelper = _CameraHelper();
    _modelHelper = _ModelHelper();
    _imageHelper = _ImageHelper(context: context);

    // ★ Sync initial AI mode states with ModelHelper
    _aiStretchResizeMode = _ModelHelper.kUseTmStretchResize;
    _aiNormalizationMode = _ModelHelper.kUseMinusOneToOneForFloat;
    // kUseEnhancement and kDebugDumpInput are const, so keep local tracking

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
      // ครอปภาพจากพรีวิวแบบ cover ด้วยกรอบสี่เหลี่ยมจัตุรัสตาม _kFrameFraction
      final cropped = _devBypassCoverCrop
          ? rawFile
          : await _imageHelper.cropImageFromCoverPreview(
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

  // ★ ซ่อนฟังก์ชัน AI Mode Selection (ยังคงไว้สำหรับใช้ในอนาคต)
  // ignore: unused_element
  void _handleAiModeSelection(String value) {
    setState(() {
      switch (value) {
        case 'enhancement':
          _aiEnhancementMode = !_aiEnhancementMode;
          // Note: kUseEnhancement is const, so we keep track locally
          break;
        case 'stretch':
          _aiStretchResizeMode = !_aiStretchResizeMode;
          // Update ModelHelper stretch resize mode
          _ModelHelper.kUseTmStretchResize = _aiStretchResizeMode;
          break;
        case 'normalize':
          _aiNormalizationMode = !_aiNormalizationMode;
          // Update ModelHelper normalization mode
          _ModelHelper.kUseMinusOneToOneForFloat = _aiNormalizationMode;
          break;
        case 'debug':
          _aiDebugMode = !_aiDebugMode;
          // Note: kDebugDumpInput is const, so we keep track locally
          break;
      }
    });

    // แสดงข้อความแจ้งเตือนการเปลี่ยนแปลง
    final modeNames = {
      'enhancement': 'ปรับปรุงภาพ AI',
      'stretch': 'TM Stretch Mode',
      'normalize': 'Normalization [-1,1]',
      'debug': 'Debug Input',
    };

    final isEnabled = {
          'enhancement': _aiEnhancementMode,
          'stretch': _aiStretchResizeMode,
          'normalize': _aiNormalizationMode,
          'debug': _aiDebugMode,
        }[value] ??
        false;

    _showSnack(
      '${modeNames[value]}: ${isEnabled ? "เปิด" : "ปิด"}',
      isError: false,
    );
  }

  Future<void> _processImage(File imageFile) async {
    if (!_modelHelper.isReady) {
      _showSnack('โมเดลยังไม่พร้อมใช้งาน');
      return;
    }

    final predictions = await _modelHelper.predict(imageFile);
    // หมายเหตุ: ตัดการแจ้งเตือน/overlay ออกเพื่อลดความกวนใจ

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
        // ★ ใช้ ctx ภายใน builder และหลีกเลี่ยงใช้ context ภายนอกใน callbacks
        if (!mounted) return;
        final goRecrop = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('ตรวจพบหลายวัตถุดิบในภาพ'),
            content: const Text(
                'โปรดครอบตัดให้ชัดเจนหรือถ่ายใหม่ โดยให้มีวัตถุดิบเดียวในภาพ'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('ยกเลิก')),
              FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('ครอบ/ถ่ายใหม่')),
            ],
          ),
        );
        if (!mounted) return;
        if (goRecrop == true) return;
      }
    }

    if (!mounted) return;
    // ★ จับ Navigator ก่อน await เพื่อนำทางอย่างปลอดภัย
    final nav = Navigator.of(context);
    final selected = await nav.push<List<String>>(
      MaterialPageRoute(
        builder: (_) => IngredientPredictionResultScreen(
          imageFile: imageFile,
          allPredictions: predictions,
        ),
      ),
    );

    if (selected != null && mounted) {
      nav.pop(selected);
    }
  }

  void _showSnack(String msg, {bool isError = true}) {
    if (!mounted) return;
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? theme.colorScheme.error : Colors.green[600],
      ),
    );
  }

  // ★ ซ่อนฟังก์ชันแสดงคำอธิบาย AI modes (ยังคงไว้สำหรับใช้ในอนาคต)
  // ignore: unused_element
  void _showAiModeGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.smart_toy, color: Colors.orange),
            SizedBox(width: 8),
            Text('คำอธิบายโหมด AI'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAiModeCard(
                '🤖 ปรับปรุงภาพ AI',
                'ปรับปรุงคุณภาพภาพก่อนส่งเข้าโมเดล AI เพื่อเพิ่มความแม่นยำ',
                [
                  '✨ ลดสัญญาณรบกวน (noise) จากภาพ',
                  '🔍 เพิ่มความคมชัดของขอบวัตถุ',
                  '🌈 ปรับสมดุลแสงและสีให้เหมาะสม',
                  '📸 ปรับปรุงภาพที่ถ่ายในแสงน้อย',
                  '⚡ อาจทำให้การประมวลผลช้าขึ้นเล็กน้อย'
                ],
                _aiEnhancementMode,
              ),
              _buildAiModeCard(
                '📐 TM Stretch Mode',
                'โหมดที่ทำให้ผลลัพธ์ตรงกับ Teachable Machine web preview 100%',
                [
                  '🎯 ปรับขนาดภาพแบบ stretch เป็น 224×224 พิกเซล',
                  '🌐 ใช้อัลกอริทึมเดียวกับ TM web preview',
                  '✅ ผลลัพธ์จะตรงกับการทดสอบในเว็บไซต์ TM',
                  '🔄 รองรับทั้งภาพสี่เหลี่ยมและสี่เหลี่ยมผืนผ้า',
                  '⭐ แนะนำให้เปิดไว้เสมอเพื่อความแม่นยำสูงสุด'
                ],
                _aiStretchResizeMode,
              ),
              _buildAiModeCard(
                '⚖️ Normalization [-1,1]',
                'เปลี่ยนวิธีการแปลงค่าสีให้เหมาะสมกับโมเดล AI บางประเภท',
                [
                  '📊 โหมดปกติ: ค่าสี 0-255 → 0.0 ถึง 1.0',
                  '🔄 โหมดนี้: ค่าสี 0-255 → -1.0 ถึง 1.0',
                  '🧮 สูตร: (pixel / 127.5) - 1.0',
                  '🤖 บางโมเดล AI ทำงานได้ดีกว่าในช่วงนี้',
                  '🧪 หากผลลัพธ์ไม่ดี ลองเปิด/ปิดโหมดนี้ดู',
                  '💡 แนะนำปิดไว้สำหรับโมเดลจาก TM'
                ],
                _aiNormalizationMode,
              ),
              _buildAiModeCard(
                '🐛 Debug Input (ปิดใช้งานชั่วคราว)',
                'เครื่องมือสำหรับนักพัฒนาและผู้ใช้ขั้นสูงเพื่อตรวจสอบการทำงาน',
                [
                  '💾 บันทึกภาพ 224×224 พิกเซลที่ป้อนเข้าโมเดล AI (ปิดใช้งาน)',
                  '📁 ไฟล์จะถูกบันทึกใน Pictures/tm_input_*.png (ปิดใช้งาน)',
                  '🔍 เปรียบเทียบกับภาพใน TM web preview',
                  '🔧 ช่วยแก้ไขปัญหาเมื่อผลลัพธ์ไม่ตรงกัน',
                  '📊 ดูข้อมูล RGB และ tensor input',
                  '⚠️ ฟีเจอร์บันทึกภาพถูกปิดใช้งานชั่วคราว'
                ],
                _aiDebugMode,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '💡 เคล็ดลับการใช้งาน',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '🚀 เริ่มต้น: ใช้ค่าเริ่มต้น (TM Stretch เปิด, อื่นๆ ปิด)\n'
                      '🎯 หากผลลัพธ์ไม่แม่นยำ: ลองเปิด "ปรับปรุงภาพ AI"\n'
                      '🔄 หากยังไม่ตรง: ลองสลับ "Normalization [-1,1]"\n'
                      '🐛 หากมีปัญหา: เปิด "Debug Input" และตรวจสอบไฟล์',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('เข้าใจแล้ว'),
          ),
        ],
      ),
    );
  }

  Widget _buildAiModeCard(
    String title,
    String description,
    List<String> features,
    bool isActive,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: isActive ? Colors.green.withOpacity(0.1) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'เปิด' : 'ปิด',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            ...features.map((feature) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    feature,
                    style: const TextStyle(fontSize: 13),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // ★ ซ่อนฟังก์ชันแสดงเคล็ดลับการถ่ายภาพ (ยังคงไว้สำหรับใช้ในอนาคต)
  // ignore: unused_element
  void _showCameraGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '📸 เคล็ดลับการถ่ายภาพให้แม่นยำ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildTipCard(
                        '🎯 จัดวางให้ดี',
                        [
                          'วางวัตถุดิบตรงกลางกรอบ',
                          'ใช้พื้นหลังสีเรียบ (ขาว/เทา)',
                          'วางชิ้นเดียวต่อรูป',
                          'แสดงลักษณะเด่นของวัตถุดิบ'
                        ],
                      ),
                      _buildTipCard(
                        '💡 แสงสว่าง',
                        [
                          'ถ่ายในที่แสงเพียงพอ',
                          'หลีกเลี่ยงเงาแรง',
                          'ใช้แสงธรรมชาติ (กลางวัน)',
                          'เปิดไฟฉายถ้าแสงไม่พอ'
                        ],
                      ),
                      _buildTipCard(
                        '📱 เทคนิคการถ่าย',
                        [
                          'ถือมือให้นิ่ง',
                          'ทำความสะอาดเลนส์',
                          'ถ่ายหลายมุม',
                          'ใช้กริดช่วยจัดวาง'
                        ],
                      ),
                      _buildTipCard(
                        '🌿 เฉพาะใบไผ่',
                        [
                          'กางใบให้เห็นรูปร่าง',
                          'เลือกใบสด ไม่เหี่ยว',
                          'หลีกเลี่ยงแสงแรงจัด',
                          'แสดงลายเส้นใบ'
                        ],
                      ),
                      _buildTipCard(
                        '🌶️ เฉพาะพริก',
                        [
                          'วางเรียงให้เห็นรูปร่าง',
                          'แสดงสีที่แท้จริง',
                          'วางห่างกันให้แยกได้',
                          'ถ่ายทั้งผลสดและแก่'
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('เข้าใจแล้ว'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTipCard(String title, List<String> tips) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            ...tips.map((tip) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: Colors.orange)),
                      Expanded(child: Text(tip)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
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

    // ★ ปรับปรุง: เริ่มจาก quality สูงกว่าเพื่อรักษาคุณภาพสำหรับ AI
    for (final q in [95, 90, 85, 80, 75, 70]) {
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
        interpolation: img.Interpolation
            .linear, // ✅ ใช้ bilinear ให้คงที่กับ TM (แทน average)
      );
      for (final q in [80, 70, 60, 50, 40]) {
        final jpg = img.encodeJpg(resized, quality: q);
        if (jpg.lengthInBytes <= maxBytes) {
          await f.writeAsBytes(jpg, flush: true);
          return _checkMinDim(f);
        }
      }
    }

    final tiny = img.copyResize(
      im,
      width: 1200,
      interpolation:
          img.Interpolation.linear, // ✅ ระบุให้ชัดเจน (bilinear) ตอนย่อ
    );
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
                    Builder(
                      builder: (context) {
                        final preview = _cameraHelper.buildPreview();
                        if (!kDebugMode) return preview;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onLongPress: () => _showDebugBottomSheet(),
                          child: preview,
                        );
                      },
                    ),

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
        // ★ ซ่อน AI Info Button, AI Mode Toggle และ เคล็ดลับการใช้งาน
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
              // ★ AI Status Indicators (ซ่อน)
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

                  // ★ ซ่อน Quick AI Toggle - แสดงเฉพาะ Zoom
                  Text(
                    '${_zoom.toStringAsFixed(1)}x',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
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

  // ★ ซ่อน AI Status Row (ยังคงไว้สำหรับใช้ในอนาคต)
  // ignore: unused_element
  Widget _buildAiStatusRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildAiStatusChip(
          'AI',
          _aiEnhancementMode,
          Colors.blue,
          Icons.auto_awesome,
        ),
        const SizedBox(width: 8),
        _buildAiStatusChip(
          'TM',
          _aiStretchResizeMode,
          Colors.green,
          Icons.aspect_ratio,
        ),
        const SizedBox(width: 8),
        _buildAiStatusChip(
          'N11',
          _aiNormalizationMode,
          Colors.purple,
          Icons.tune,
        ),
        const SizedBox(width: 8),
        _buildAiStatusChip(
          'DBG',
          _aiDebugMode,
          Colors.orange,
          Icons.bug_report,
        ),
      ],
    );
  }

  Widget _buildAiStatusChip(
    String label,
    bool isActive,
    Color activeColor,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? activeColor.withOpacity(0.8)
            : Colors.grey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? activeColor : Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: isActive ? Colors.white : Colors.grey[400],
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey[400],
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Developer-only bottom sheet (debug builds only)
  void _showDebugBottomSheet() async {
    if (!kDebugMode) return;
    final model = _modelHelper; // access for lastDumpPath and toggle
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      showDragHandle: true,
      builder: (ctx) {
        final dumpPath = model.lastDumpPath;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TM Debug Tools',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      color: Colors.black,
                      child: dumpPath != null
                          ? Image.file(File(dumpPath), fit: BoxFit.cover)
                          : const Center(
                              child: Text('no dump',
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 12))),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Resize policy: TM stretch = ${_ModelHelper.kUseTmStretchResize}',
                              style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 4),
                          Text(
                              'Float norm: [-1,1] = ${_ModelHelper.kUseMinusOneToOneForFloat}',
                              style: const TextStyle(color: Colors.white54)),
                          const SizedBox(height: 4),
                          Text(
                              'Tensor dtypes: inputFloat=${model._inputIsFloat}, outputFloat=${model._outputIsFloat}',
                              style: const TextStyle(color: Colors.white54)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () async {
                                  final dir = await getTemporaryDirectory();
                                  if (kDebugMode)
                                    debugPrint(
                                        '[TFLite] temp dir = ${dir.path}');
                                  if (mounted) Navigator.pop(ctx);
                                },
                                child: const Text('Open folder'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _devBypassCoverCrop = !_devBypassCoverCrop;
                                  });
                                  if (kDebugMode)
                                    debugPrint(
                                        '[Dev] Bypass cover-crop -> ${_devBypassCoverCrop}');
                                },
                                child: const Text('Bypass crop'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _ModelHelper.kUseTmStretchResize =
                                        !_ModelHelper.kUseTmStretchResize;
                                  });
                                  if (kDebugMode)
                                    debugPrint(
                                        '[TFLite] kUseTmStretchResize -> ${_ModelHelper.kUseTmStretchResize}');
                                },
                                child: const Text('Toggle stretch'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _ModelHelper.kUseMinusOneToOneForFloat =
                                        !_ModelHelper.kUseMinusOneToOneForFloat;
                                  });
                                  if (kDebugMode)
                                    debugPrint(
                                        '[TFLite] kUseMinusOneToOneForFloat -> ${_ModelHelper.kUseMinusOneToOneForFloat}');
                                },
                                child: const Text('Toggle [-1,1]'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _ModelHelper.kSwapRBForTest =
                                        !_ModelHelper.kSwapRBForTest;
                                  });
                                  if (kDebugMode)
                                    debugPrint(
                                        '[TFLite] kSwapRBForTest -> ${_ModelHelper.kSwapRBForTest}');
                                },
                                child: const Text('Swap R/B'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (dumpPath != null)
                  Text(dumpPath,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ───────── ตัวช่วย: TFLite
class _ModelHelper {
  late tfl.Interpreter _interpreter;
  late List<String> _labels;
  bool isReady = false;

  // ✅ สวิตช์สำคัญที่เพิ่ม - ตั้งค่าให้ตรงกับ Teachable Machine
  static const bool kUseEnhancement = false; // ไม่แต่งภาพเพื่อความแม่นยำ

  // --- TM compatibility knobs ---
  static bool kUseTmStretchResize =
      true; // set true to match TM preview exactly (debug-toggleable)
  // static const bool kDebugDumpInput =
  //     false; // save 224x224 input for side-by-side checks (ปิดใช้งาน)
  // Float normalization policy for float32 inputs:
  // false => [0,1] (v/255.0), true => [-1,1] (v/127.5 - 1)
  static bool kUseMinusOneToOneForFloat = false;
  // Debug-only: test channel order mismatch
  static bool kSwapRBForTest = false;

  // Last dumped 224x224 input path (debug only)
  String? lastDumpPath;

  // Cached tensor meta (inspect once during load)
  bool _inputIsFloat = true;
  bool _outputIsFloat = true;
  int _outputDim = 0;
  double _outScale = 1.0;
  int _outZeroPoint = 0;

  // ── helpers: convert flat buffers to 4D [1,224,224,3] without using reshape
  List to4DFromF32(Float32List flat) {
    var i = 0;
    return [
      List.generate(
          224,
          (y) => List.generate(224, (x) {
                final r = flat[i++], g = flat[i++], b = flat[i++];
                return [r, g, b];
              }))
    ];
  }

  List to4DFromU8(Uint8List flat) {
    var i = 0;
    return [
      List.generate(
          224,
          (y) => List.generate(224, (x) {
                final r = flat[i++], g = flat[i++], b = flat[i++];
                return [r, g, b];
              }))
    ];
  }

  Future<void> load(BuildContext context) async {
    try {
      // ★ ใช้ Interpreter options เพื่อเพิ่มประสิทธิภาพ
      final options = tfl.InterpreterOptions()
        ..threads = 2; // ใช้ 2 threads เพื่อประสิทธิภาพ

      _interpreter = await tfl.Interpreter.fromAsset(
        'assets/converted_tflite_quantized/model_unquant.tflite',
        options: options,
      );

      // Inspect tensors once (debug-only logs)
      final inT = _interpreter.getInputTensor(0);
      final outT = _interpreter.getOutputTensor(0);
      assert(inT.shape.length == 4, 'Expected NHWC input');
      final inputType = inT.type; // float32 or uint8
      final inputShape = inT.shape; // [1,224,224,3] expected
      final outputShape = outT.shape; // [1,numLabels]
      _inputIsFloat = inputType.toString().toLowerCase().contains('float');
      _outputIsFloat = outT.type.toString().toLowerCase().contains('float');
      _outputDim = outputShape.last;
      _outScale = outT.params.scale;
      _outZeroPoint = outT.params.zeroPoint;

      if (kDebugMode) {
        debugPrint('[TFLite] input=$inputType shape=$inputShape '
            'quant(s=${inT.params.scale}, z=${inT.params.zeroPoint})');
        debugPrint('[TFLite] output=${outT.type} shape=$outputShape '
            'quant(s=${outT.params.scale}, z=${outT.params.zeroPoint})');
      }

      // ใช้ rootBundle เพื่อหลีกเลี่ยงการถือ BuildContext ข้ามช่วง async
      final labelsString = await rootBundle
          .loadString('assets/converted_tflite_quantized/labels.txt');

      // ★ Parse labels โดยอิง index หน้า label เพื่อให้ตรงกับ output 100%
      final lines = labelsString
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final Map<int, String> byIndex = {};
      int maxIdx = -1;
      final re = RegExp(r'^(\d+)\s+(.+)$');
      for (final line in lines) {
        final m = re.firstMatch(line);
        if (m != null) {
          final idx = int.parse(m.group(1)!);
          final name = m.group(2)!.trim();
          byIndex[idx] = name;
          if (idx > maxIdx) maxIdx = idx;
        } else {
          maxIdx += 1;
          byIndex[maxIdx] = line; // fallback order
        }
      }
      _labels = List<String>.generate(maxIdx + 1, (i) => byIndex[i] ?? '');

      // Validate labels vs outputDim (hard fail)
      if (kDebugMode) {
        debugPrint('[TFLite] labels count = ${_labels.length}');
      }
      if (_labels.length != _outputDim) {
        throw StateError(
            'labels.txt (${_labels.length}) != model outDim (${_outputDim}). '
            'Ensure labels.txt matches TM export used for the .tflite');
      }

      // ★ Warm up โมเดลด้วยการรันครั้งแรก (dummy data) ตามชนิดอินพุต/เอาต์พุตจริง (ไม่ใช้ reshape)
      if (_inputIsFloat) {
        final dummyInput = Float32List(1 * 224 * 224 * 3);
        final dummyOutput = _outputIsFloat
            ? [List<double>.filled(_labels.length, 0.0)]
            : [List<int>.filled(_labels.length, 0)];
        _interpreter.run(to4DFromF32(dummyInput), dummyOutput);
      } else {
        final dummyInput = Uint8List(1 * 224 * 224 * 3);
        final dummyOutput = _outputIsFloat
            ? [List<double>.filled(_labels.length, 0.0)]
            : [List<int>.filled(_labels.length, 0)];
        _interpreter.run(to4DFromU8(dummyInput), dummyOutput);
      }

      isReady = true;
    } catch (e) {
      throw Exception('Failed to load TFLite model: $e');
    }
  }

  Future<List<Map<String, dynamic>>> predict(File imageFile) async {
    // Heavy preprocessing in isolate (no UI jank)
    // การเตรียม tempDirPath สำหรับบันทึกภาพ debug (ชั่วคราวปิดใช้งาน)
    // final tempDirPath = (kDebugMode && kDebugDumpInput)
    //     ? (await getTemporaryDirectory()).path
    //     : null;
    final packed = await compute(_preprocessAndPackIsolate, {
      'imagePath': imageFile.path,
      'useStretch': _ModelHelper.kUseTmStretchResize,
      'useEnhancement': kUseEnhancement,
      'isFloat': _inputIsFloat,
      'useMinusOneToOne': _ModelHelper.kUseMinusOneToOneForFloat,
      'swapRB': _ModelHelper.kSwapRBForTest,
      'debugDump': false, // kDebugMode && kDebugDumpInput, (ปิดใช้งาน)
      'tempDir': null, // tempDirPath, (ปิดใช้งาน)
    });
    if (packed == null) return [];

    // Update last dump path for debug UI (ชั่วคราวปิดใช้งาน)
    // if (kDebugMode && packed['dumpPath'] is String) {
    //   lastDumpPath = packed['dumpPath'] as String;
    //   debugPrint('[TFLite] dumped input224=$lastDumpPath');
    // }

    // Build model input from packed data
    final isFloatPacked = (packed['isFloat'] as bool?) ?? _inputIsFloat;
    final data = packed['packed'];
    dynamic modelInput; // [1,224,224,3]
    if (isFloatPacked && data is Float32List) {
      modelInput = to4DFromF32(data);
    } else if (!isFloatPacked && data is Uint8List) {
      modelInput = to4DFromU8(data);
    } else {
      if (kDebugMode) {
        debugPrint(
            '[TFLite] ⚠ Packed type mismatch: ${data.runtimeType} isFloat=$isFloatPacked');
      }
      return [];
    }

    // 5) เตรียม output container ตามชนิดเอาต์พุตจริง
    dynamic modelOutput;
    if (_outputIsFloat) {
      modelOutput = [List<double>.filled(_labels.length, 0.0)];
    } else {
      modelOutput = [List<int>.filled(_labels.length, 0)];
    }

    // Debug: โชว์ชนิดอินพุต/เอาต์พุต และขนาด
    if (kDebugMode) {
      debugPrint(
          '🔧 Tensor Debug: inputFloat=$_inputIsFloat, outputFloat=$_outputIsFloat, outDim=$_outputDim');
    }

    // รัน prediction
    _interpreter.run(modelInput, modelOutput);

    // ★ ปรับการแสดงผลให้ตรงกับ TM มากขึ้น
    // 4.1 เก็บค่าแบบเวคเตอร์เพื่อทำ softmax หากจำเป็น
    final rawVec = List<double>.generate(_labels.length, (i) {
      if (_outputIsFloat) {
        return (modelOutput[0][i] as num).toDouble();
      } else {
        final q = (modelOutput[0][i] as num).toInt();
        return _outScale * (q - _outZeroPoint);
      }
    });

    // 4.2 ถ้าไม่ใช่ probs (sum ไม่ใกล้ 1) ให้ทำ softmax แบบ stable
    double sum = 0;
    for (final v in rawVec) sum += v.isFinite ? v : 0.0;
    List<double> probs;
    if (!(sum > 0.9 && sum < 1.1)) {
      final maxLogit = rawVec.reduce((a, b) => a > b ? a : b);
      final exps = rawVec
          .map((v) => math.exp((v - maxLogit).clamp(-40.0, 40.0)))
          .toList();
      final exSum = exps.fold<double>(0.0, (acc, v) => acc + v);
      probs = exps.map((e) => (e / (exSum == 0 ? 1 : exSum))).toList();
    } else {
      // ข้อมูลเป็น probs อยู่แล้ว
      probs = rawVec.map((v) => v.clamp(0.0, 1.0)).toList();
    }

    final res = <Map<String, dynamic>>[];
    for (var idx = 0; idx < _labels.length; idx++) {
      final confidence = probs[idx];
      if (confidence > 0.01) {
        res.add({'label': _labels[idx], 'confidence': confidence});
      }
    }

    // ★ เรียงตามคะแนนสูงสุด
    res.sort((a, b) =>
        (b['confidence'] as double).compareTo(a['confidence'] as double));
    return res;
  }

  // Removed unused functions - moved to isolate versions

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
      ResolutionPreset.veryHigh, // ★ ใช้ resolution สูงสุดเพื่อคุณภาพดีที่สุด
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg, // ★ กำหนดฟอร์แมต JPEG
    );
    await _controller!.initialize();

    // ★ ตั้งค่าเพิ่มเติมสำหรับคุณภาพภาพ
    try {
      await _controller!.setExposureMode(ExposureMode.auto);
      await _controller!.setFocusMode(FocusMode.auto);
      await _controller!.setFlashMode(FlashMode.off);
    } catch (_) {
      // บางอุปกรณ์อาจไม่รองรับ
    }

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
  // ★ ลบตัวแปรที่ไม่ใช้แล้วเพื่อประหยัดหน่วยความจำ

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
      imageQuality: 85, // ★ ลดจาก 90 เป็น 85 เพื่อความเร็ว
      maxWidth: 1500, // ★ ลดจาก 2048 เป็น 1500
      maxHeight: 1500, // ★ ลดจาก 2048 เป็น 1500
    );
    if (picked == null) return null;
    // ★ วิเคราะห์คุณภาพแบบเร็ว (ข้ามการตรวจสอบความคมชัดเฉพาะ Gallery)
    try {
      final f = File(picked.path);
      final bytes = await f.readAsBytes();
      final decoded0 = img.decodeImage(bytes);
      if (decoded0 == null) {
        _showSnack('ไฟล์รูปภาพไม่ถูกต้อง');
        return null;
      }
      final im = img.bakeOrientation(decoded0);

      // ★ ข้ามการตรวจสอบความคมชัดสำหรับ Gallery (ประหยัดเวลา)
      // final sharp = _estimateSharpness(im);
      final fileSize = await f.length();
      final tooSmall = im.width < _kMinPickDim || im.height < _kMinPickDim;
      // ★ ข้ามการตรวจสอบความคมชัดสำหรับ Gallery images
      // final tooBlur = sharp < _kMinSharpness;

      // ★ Gallery images มักจะคุณภาพดี ตรวจแค่ขนาด (ข้ามการตรวจความคมชัด)
      if (!tooSmall) {
        return _cropImage(picked.path);
      }

      // ไม่ผ่าน → แสดงตัวเลือกสำหรับรูปเล็ก
      final decision = await _confirmPickedInfo(
        path: picked.path,
        width: im.width,
        height: im.height,
        bytes: fileSize,
        sharpness: 100.0, // ★ ใช้ค่าดัมมี่เพราะข้ามการตรวจ
        canProceed: !tooSmall, // ★ ตรวจแค่ขนาด
        reason: tooSmall
            ? 'รูปเล็กเกินไป (อย่างน้อย $_kMinPickDim×$_kMinPickDim พิกเซล)'
            : null,
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

  // ★ ลบฟังก์ชัน _estimateSharpness เพื่อลดความซับซ้อนและเพิ่มความเร็ว

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
      // ★ ใช้ค่าคงที่แทนตัวแปรที่ถูกลบ
      if (v >= 120.0) return 'คมชัดดี';
      if (v >= 60.0) return 'พอใช้';
      return 'ไม่คมชัด';
    }

    final theme = Theme.of(context);
    if (!context.mounted) return null;
    return showModalBottomSheet<_PickDecision>(
      context: context,
      showDragHandle: true,
      builder: (bctx) {
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
                            Chip(label: Text('ขนาด $width×$height px')),
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
                        onPressed: () => Navigator.pop(bctx, _chooseAgain),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('เลือกใหม่'),
                      ),
                      if (showUpscale)
                        TextButton.icon(
                          onPressed: () => Navigator.pop(bctx, _upscale),
                          icon: const Icon(Icons.trending_up),
                          label: Text('ขยายเป็น $_kMinPickDim แล้วครอบ'),
                        ),
                      if (canProceed)
                        FilledButton.icon(
                          onPressed: () => Navigator.pop(bctx, _proceed),
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('ไปครอบตัด'),
                        )
                      else
                        (showUpscale
                            ? TextButton.icon(
                                onPressed: () => Navigator.pop(bctx, _force),
                                icon: const Icon(Icons.trending_up),
                                label: const Text('ใช้ต่อ (จะขยายอัตโนมัติ)'),
                              )
                            : TextButton(
                                onPressed: () => Navigator.pop(bctx, _force),
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
      interpolation:
          img.Interpolation.linear, // ✅ ใช้ bilinear ตอนขยายเพื่อความสม่ำเสมอ
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

    // 🚀 ปรับปรุงการ crop ให้เร็วขึ้น
    final cropXInt = cropX.round().clamp(0, imgW.toInt() - 1);
    final cropYInt = cropY.round().clamp(0, imgH.toInt() - 1);
    final cropSizeInt = cropSize
        .round()
        .clamp(1, math.min(imgW.toInt() - cropXInt, imgH.toInt() - cropYInt))
        .toInt();

    final cropped = img.copyCrop(
      original,
      x: cropXInt,
      y: cropYInt,
      width: cropSizeInt,
      height: cropSizeInt,
    );

    final jpg = img.encodeJpg(cropped, quality: 90);
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    return File(path).writeAsBytes(jpg);
  }

  Future<File?> _cropImage(String filePath) async {
    if (!context.mounted) return null;
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
    if (!context.mounted) return;
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
const List<double> kMeasureLineMarkers = [0.2, 0.80];
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
      final bg = Paint()..color = Colors.black.withValues(alpha: 0.45);
      canvas.drawRRect(rect, bg);
      // เส้นขอบอ่อนๆ
      final br = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.6);
      canvas.drawRRect(rect, br);
      tp.paint(canvas, Offset(rect.left + padH, rect.top + padV));
    }
  }

  @override
  bool shouldRepaint(covariant _CutoutOverlayPainter oldDelegate) {
    return frameFraction != oldDelegate.frameFraction ||
        borderColor != oldDelegate.borderColor ||
        borderWidth != oldDelegate.borderWidth ||
        cornerRadius != oldDelegate.cornerRadius ||
        guideStyle != oldDelegate.guideStyle ||
        showLabel != oldDelegate.showLabel ||
        labelText != oldDelegate.labelText;
  }

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
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 2.0;
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
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
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 2.0;
    final paintTick = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
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
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 2.2;
    final centerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
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

img.Image _enhanceImageIsolate(img.Image original) {
  var adjusted = img.adjustColor(original,
      brightness: 1.05, contrast: 1.1, saturation: 1.02);
  return img.gaussianBlur(adjusted, radius: 1);
}

img.Image _resizeAndCropIsolate(img.Image original, int targetW, int targetH) {
  final aspectRatio = original.width / original.height;
  final targetAspectRatio = targetW / targetH;

  img.Image resized;
  if (aspectRatio > targetAspectRatio) {
    final newWidth = (original.height * targetAspectRatio).round();
    resized = img.copyResize(original, width: newWidth);
  } else {
    final newHeight = (original.width / targetAspectRatio).round();
    resized = img.copyResize(original, height: newHeight);
  }

  final x = ((resized.width - targetW) / 2).round();
  final y = ((resized.height - targetH) / 2).round();
  return img.copyCrop(resized, x: x, y: y, width: targetW, height: targetH);
}

// Isolate: decode, bake orientation, resize to 224x224, and pack to Float32List/Uint8List
Map<String, Object?>? _preprocessAndPackIsolate(Map<String, Object?> args) {
  try {
    final imagePath = args['imagePath'] as String;
    final useStretch = args['useStretch'] as bool? ?? true;
    final useEnh = args['useEnhancement'] as bool? ?? false;
    final isFloat = args['isFloat'] as bool? ?? true;
    final useMinusOneToOne = args['useMinusOneToOne'] as bool? ?? false;
    final swapRB = args['swapRB'] as bool? ?? false;
    // final debugDump = args['debugDump'] as bool? ?? false; // ชั่วคราวปิดใช้งาน
    // final tempDir = args['tempDir'] as String?; // ชั่วคราวปิดใช้งาน

    final bytes = File(imagePath).readAsBytesSync();
    final decoded0 = img.decodeImage(bytes);
    if (decoded0 == null) return null;
    final decoded = img.bakeOrientation(decoded0);
    final enhanced = useEnh ? _enhanceImageIsolate(decoded) : decoded;

    img.Image pre;
    if (useStretch) {
      pre = img.copyResize(enhanced,
          width: 224, height: 224, interpolation: img.Interpolation.linear);
    } else {
      pre = _resizeAndCropIsolate(enhanced, 224, 224);
    }

    String? dumpPath;
    // ฟังก์ชั่นบันทึกภาพ 224x224 พิกเซลลงเครื่องสำหรับ debug (ชั่วคราวปิดใช้งาน)
    // if (debugDump && tempDir != null) {
    //   dumpPath =
    //       '$tempDir/tm_input_${DateTime.now().millisecondsSinceEpoch}.png';
    //   File(dumpPath).writeAsBytesSync(img.encodePng(pre));
    // }

    if (isFloat) {
      final out = Float32List(1 * 224 * 224 * 3);
      var i = 0;
      for (var y = 0; y < 224; y++) {
        for (var x = 0; x < 224; x++) {
          final p = pre.getPixel(x, y);
          int r = p.r.toInt() & 0xFF;
          int g = p.g.toInt() & 0xFF;
          int b = p.b.toInt() & 0xFF;
          if (swapRB) {
            final tmp = r;
            r = b;
            b = tmp;
          }
          if (useMinusOneToOne) {
            // [-1, 1]
            out[i++] = (r / 127.5) - 1.0;
            out[i++] = (g / 127.5) - 1.0;
            out[i++] = (b / 127.5) - 1.0;
          } else {
            // [0, 1]
            out[i++] = r / 255.0;
            out[i++] = g / 255.0;
            out[i++] = b / 255.0;
          }
        }
      }
      return {
        'packed': out,
        'isFloat': true,
        'width': 224,
        'height': 224,
        'dumpPath': dumpPath,
      };
    } else {
      final out = Uint8List(1 * 224 * 224 * 3);
      var i = 0;
      for (var y = 0; y < 224; y++) {
        for (var x = 0; x < 224; x++) {
          final p = pre.getPixel(x, y);
          int r = p.r.toInt() & 0xFF;
          int g = p.g.toInt() & 0xFF;
          int b = p.b.toInt() & 0xFF;
          if (swapRB) {
            final tmp = r;
            r = b;
            b = tmp;
          }
          out[i++] = r;
          out[i++] = g;
          out[i++] = b;
        }
      }
      return {
        'packed': out,
        'isFloat': false,
        'width': 224,
        'height': 224,
        'dumpPath': dumpPath,
      };
    }
  } catch (e) {
    // Keep isolate silent but return null to indicate failure
    return null;
  }
}
