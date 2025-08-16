// lib/screens/crop_avatar_screen.dart
//
// ★ 2025-08-12 – Avatar Cropper (FB-like, save SQUARE; preview CIRCLE)
//   • พรีวิว: นอกวงกลม “จาง”, ในวงกลมสีปกติ
//   • Pinch-to-zoom / pan ปกติ, หมุน 90° แล้วยังคงซูมและจุดกึ่งกลาง
//   • บันทึก: ครอป “สี่เหลี่ยมจัตุรัส” จากพิกัดภาพจริง (ไม่ใช่วงกลม)
//   • ใช้คณิตจาก TransformationController → ตัดตรงจาก _original
//   • ออปชันย่อสูงสุด ~1024px และบันทึกเป็น JPG

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class CropAvatarScreen extends StatefulWidget {
  final String sourcePath;
  const CropAvatarScreen({super.key, required this.sourcePath});

  @override
  State<CropAvatarScreen> createState() => _CropAvatarScreenState();
}

class _CropAvatarScreenState extends State<CropAvatarScreen> {
  final _tc = TransformationController();

  late Future<void> _loadFuture;
  late img.Image _original; // รูปหลัง bake EXIF + หลังหมุน 90°
  late Uint8List _displayBytes; // ไบต์สำหรับแสดงผล

  int _srcW = 0, _srcH = 0; // ขนาดรูปปัจจุบัน
  double _baseW = 0, _baseH = 0; // ขนาดฐานที่วางในกรอบสี่เหลี่ยมครอป
  double _cropSize = 0; // ความกว้าง/สูงของกรอบครอป (จัตุรัส)

  bool _didInitTransform = false;
  double? _lastCropSize;
  bool _isClamping = false;

  static const double _minScale = 1.0;
  static const double _maxScale = 6.0;

  @override
  void initState() {
    super.initState();
    _tc.addListener(_onTcChanged);
    _loadFuture = _load();
  }

  Future<void> _load() async {
    final bytes = await File(widget.sourcePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('อ่านรูปไม่สำเร็จ');

    _original = img.bakeOrientation(decoded);
    _displayBytes = Uint8List.fromList(img.encodePng(_original));
    _srcW = _original.width;
    _srcH = _original.height;
  }

  @override
  void dispose() {
    _tc.removeListener(_onTcChanged);
    _tc.dispose();
    super.dispose();
  }

  double get _coverMinScale => math.max(_cropSize / _baseW, _cropSize / _baseH);

  void _computeBaseSize() {
    final w = _srcW.toDouble(), h = _srcH.toDouble();
    if (w >= h) {
      _baseH = _cropSize;
      _baseW = _cropSize * (w / h);
    } else {
      _baseW = _cropSize;
      _baseH = _cropSize * (h / w);
    }
  }

  void _initTransform() {
    if (_didInitTransform && _lastCropSize == _cropSize) return;

    _computeBaseSize();
    final tx = (_cropSize - _baseW) / 2;
    final ty = (_cropSize - _baseH) / 2;
    _tc.value = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(1.0);

    _didInitTransform = true;
    _lastCropSize = _cropSize;

    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureCover());
  }

  void _onTcChanged() {
    if (!mounted || _isClamping || !_didInitTransform) {
      if (mounted) setState(() {}); // sync slider
      return;
    }
    _isClamping = true;
    _ensureCover();
    _isClamping = false;
    if (mounted) setState(() {});
  }

  void _resetAll() {
    _didInitTransform = false;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureCover());
  }

  // หมุน 90° พร้อมรักษาซูมและจุดกึ่งกลางที่กำลังดูอยู่
  void _rotateQuarter(int quarters) {
    final q = ((quarters % 4) + 4) % 4;
    if (q == 0) return;

    final m0 = _tc.value.clone();
    final s0 = m0.getMaxScaleOnAxis().clamp(_minScale, _maxScale);
    final tx0 = m0.storage[12];
    final ty0 = m0.storage[13];
    final cx = _cropSize / 2, cy = _cropSize / 2;
    final relX = (cx - tx0) / (s0 * _baseW);
    final relY = (cy - ty0) / (s0 * _baseH);

    setState(() {
      img.Image cur = _original;
      if (q == 1)
        cur = img.copyRotate(cur, angle: 90);
      else if (q == 2)
        cur = img.copyRotate(cur, angle: 180);
      else if (q == 3) cur = img.copyRotate(cur, angle: -90);

      _original = cur;
      _displayBytes = Uint8List.fromList(img.encodePng(_original));
      _srcW = _original.width;
      _srcH = _original.height;
      _didInitTransform = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _computeBaseSize();
      double nx = relX, ny = relY;
      if (q == 1) {
        nx = relY;
        ny = 1 - relX;
      } else if (q == 2) {
        nx = 1 - relX;
        ny = 1 - relY;
      } else if (q == 3) {
        nx = 1 - relY;
        ny = relX;
      }

      final s = s0;
      final tx = cx - nx * s * _baseW;
      final ty = cy - ny * s * _baseH;

      _tc.value = Matrix4.identity()
        ..translate(tx, ty)
        ..scale(s);
      _ensureCover();
    });
  }

  void _setZoom(double newScale) {
    final coverMin = _coverMinScale;
    final target = newScale.clamp(coverMin, _maxScale);
    final m = _tc.value.clone();
    final cur = m.getMaxScaleOnAxis();
    if (cur == 0) return;
    final factor = target / cur;
    m
      ..translate(_cropSize / 2, _cropSize / 2)
      ..scale(factor)
      ..translate(-_cropSize / 2, -_cropSize / 2);
    _tc.value = m;
  }

  // ไม่ให้เห็นขอบว่าง: s >= coverMin และ tx/ty อยู่ในช่วงที่ครอบเต็ม
  void _ensureCover() {
    if (_cropSize <= 0) return;

    final m = _tc.value.clone();
    double s = m.getMaxScaleOnAxis();

    final minS = _coverMinScale;
    if (s < minS) {
      final f = minS / s;
      m
        ..translate(_cropSize / 2, _cropSize / 2)
        ..scale(f)
        ..translate(-_cropSize / 2, -_cropSize / 2);
      s = minS;
    }

    final minTx = _cropSize - s * _baseW;
    final maxTx = 0.0;
    final minTy = _cropSize - s * _baseH;
    final maxTy = 0.0;

    const eps = 0.001;
    final tx = m.storage[12].clamp(minTx - eps, maxTx + eps);
    final ty = m.storage[13].clamp(minTy - eps, maxTy + eps);
    m.storage[12] = tx.toDouble();
    m.storage[13] = ty.toDouble();

    _tc.value = m;
  }

  // ───── SAVE: ครอป "สี่เหลี่ยมจัตุรัส" จากภาพจริง ─────
  Future<void> _doCrop() async {
    try {
      // แปลง viewport → พิกัดใน _original
      final m = _tc.value;
      final s = m.getMaxScaleOnAxis();
      final tx = m.storage[12];
      final ty = m.storage[13];

      // พิกัดใน "base space"
      final ix0 = (0 - tx) / s; // x ที่ขอบซ้ายของกรอบครอป
      final iy0 = (0 - ty) / s; // y ที่ขอบบน
      final ix1 = (_cropSize - tx) / s;
      final iy1 = (_cropSize - ty) / s;

      // แปลง base → original
      final sx = _srcW / _baseW;
      final sy = _srcH / _baseH;

      int x = (ix0 * sx).floor();
      int y = (iy0 * sy).floor();
      int w = ((ix1 - ix0) * sx).round();
      int h = ((iy1 - iy0) * sy).round();

      // กันหลุดขอบ (ปกติ _ensureCover จะป้องกันไว้แล้ว)
      x = x.clamp(0, _srcW - 1);
      y = y.clamp(0, _srcH - 1);
      w = w.clamp(1, _srcW - x);
      h = h.clamp(1, _srcH - y);

      img.Image cropped =
          img.copyCrop(_original, x: x, y: y, width: w, height: h);

      // ย่อเพดาน 1024px
      const maxSide = 1024;
      if (cropped.width > maxSide || cropped.height > maxSide) {
        cropped = img.copyResize(
          cropped,
          width: cropped.width >= cropped.height ? maxSide : null,
          height: cropped.height > cropped.width ? maxSide : null,
          interpolation: img.Interpolation.average,
        );
      }

      // บันทึก JPG (ไม่มีโปร่งใส → ไฟล์เล็ก แสดงวงกลมด้วย UI แทน)
      final jpg = img.encodeJpg(cropped, quality: 90);

      final dir = await getTemporaryDirectory();
      final f = File(
          '${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await f.writeAsBytes(jpg, flush: true);

      if (!mounted) return;
      Navigator.pop<File>(context, f);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  // ───────── UI ─────────
  Widget _buildCropper() {
    _initTransform();

    final rawImage = SizedBox(
      width: _baseW,
      height: _baseH,
      child: Image.memory(_displayBytes, fit: BoxFit.cover),
    );

    return SizedBox(
      width: _cropSize,
      height: _cropSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ชั้นล่าง: ภาพ "จาง" ที่รับ gesture
          InteractiveViewer(
            transformationController: _tc,
            minScale: _minScale,
            maxScale: _maxScale,
            boundaryMargin: EdgeInsets.all(_cropSize * 2),
            constrained: false,
            child: ColorFiltered(
              colorFilter: ColorFilter.matrix(_saturationMatrix(0.35)),
              child: Opacity(opacity: 0.78, child: rawImage),
            ),
          ),

          // ชั้นบน: แสดงใน "วงกลม" สีปกติ (พรีวิวเท่านั้น)
          IgnorePointer(
            child: ClipOval(
              child: Transform(
                transform: _tc.value,
                child: SizedBox(width: _baseW, height: _baseH, child: rawImage),
              ),
            ),
          ),

          // วงเส้นขอบ
          IgnorePointer(
            child: CustomPaint(
              size: Size(_cropSize, _cropSize),
              painter: _CircleOutlinePainter(
                strokeColor: Colors.white.withOpacity(.9),
                strokeWidth: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final currentScale = _tc.value.getMaxScaleOnAxis();
    final coverMin = _coverMinScale.clamp(_minScale, _maxScale);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _iconBtn(Icons.rotate_left, 'หมุนซ้าย', () => _rotateQuarter(3)),
              const SizedBox(width: 28),
              _iconBtn(Icons.rotate_right, 'หมุนขวา', () => _rotateQuarter(1)),
            ],
          ),
          const SizedBox(height: 10),
          _sliderRow(
            iconStart: Icons.zoom_out,
            iconEnd: Icons.zoom_in,
            child: Slider(
              value: currentScale.clamp(coverMin, _maxScale),
              min: coverMin,
              max: _maxScale,
              onChanged: _setZoom,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _resetAll,
              icon: const Icon(Icons.refresh),
              label: const Text('คืนค่าทั้งหมด'),
            ),
          ),
        ],
      ),
    );
  }

  // UI helpers
  static List<double> _saturationMatrix(double s) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    final ir = (1 - s) * r, ig = (1 - s) * g, ib = (1 - s) * b;
    return <double>[
      ir + s,
      ig,
      ib,
      0,
      0,
      ir,
      ig + s,
      ib,
      0,
      0,
      ir,
      ig,
      ib + s,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  Widget _iconBtn(IconData icon, String label, VoidCallback onPressed) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
              icon: Icon(icon),
              iconSize: 28,
              onPressed: onPressed,
              color: Theme.of(context).colorScheme.primary),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );

  Widget _sliderRow(
          {required IconData iconStart,
          required IconData iconEnd,
          required Widget child}) =>
      Row(children: [
        Icon(iconStart, size: 20),
        Expanded(child: child),
        Icon(iconEnd, size: 20)
      ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ครอบตัดรูปโปรไฟล์'),
        leading: IconButton(
          tooltip: 'ยกเลิก',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'บันทึก',
            icon: const Icon(Icons.check),
            onPressed: _doCrop, // ← เซฟเป็น "สี่เหลี่ยม"
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('โหลดรูปไม่สำเร็จ: ${snap.error}'));
          }

          return LayoutBuilder(builder: (ctx, cons) {
            final screenW = cons.maxWidth, screenH = cons.maxHeight;
            const bottomPanel = 200.0;
            _cropSize = math.min(screenW, screenH - bottomPanel) - 32;
            _cropSize = _cropSize.clamp(220.0, screenW);

            return Column(
              children: [
                Expanded(child: Center(child: _buildCropper())),
                _buildControls(),
              ],
            );
          });
        },
      ),
      backgroundColor: Theme.of(context).colorScheme.background,
    );
  }
}

class _CircleOutlinePainter extends CustomPainter {
  final Color strokeColor;
  final double strokeWidth;
  const _CircleOutlinePainter(
      {required this.strokeColor, this.strokeWidth = 2});

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) / 2;
    final c = size.center(Offset.zero);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = strokeColor;
    canvas.drawCircle(c, r - strokeWidth / 2, paint);
  }

  @override
  bool shouldRepaint(covariant _CircleOutlinePainter old) =>
      old.strokeColor != strokeColor || old.strokeWidth != strokeWidth;
}
