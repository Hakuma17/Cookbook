// lib/screens/crop_avatar_screen.dart
//
// 2025-08-24 — Patch: precision & UX
// • แก้ clamp() → .toInt() สำหรับตัวแปร int (กัน analyzer เตือน/บั๊ก)
// • q==1 ใน _mapRectToOriginal() ใช้ขอบเขต clamp ที่ origW ถูกแกน
// • InteractiveViewer.minScale = _coverMinScale (ไม่เด้งกลับ/ไม่เห็นขอบดำ)
// • คำนวณ _cropSize แบบกันจอเตี้ย (usable = max(0, h - panel - 32))
//
// 2025-08-18 — Avatar Cropper (Android Only, simple & precise)
// • ใช้ “ภาพเดียว” (ไม่มี Transform ซ้ำ) → สี/สเกลใน-นอกวงกลมตรงกันเป๊ะ
// • ข้างนอกวงกลมจางด้วย overlay แบบมีรู (ไม่ทำภาพซีด)
// • pinch/zoom/pan + double-tap zoom, หมุน 90° แบบตรรกะ (ลื่น) และคงจุดกึ่งกลาง
// • Clamp ห้ามเลื่อนเกินภาพจริง, ครอป “ตรงตามที่เห็นบนเลย์เอาต์”
// • Save ทำใน isolate (compute) + มีหน้ากำลังบันทึก
// • ผลลัพธ์: สี่เหลี่ยมจัตุรัส, ยาวสุด 1024px, JPG q=90

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart'; // compute
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late img.Image _original; // baked EXIF (ยังไม่หมุนตามพรีวิว)
  late Uint8List _previewBytes; // พรีวิวแบบย่อ (ลื่นและประหยัดแรม)

  int _srcW = 0, _srcH = 0;
  double _baseW = 0, _baseH = 0; // ขนาดภาพฐานในกรอบครอป (หลังหมุนตรรกะ)
  double _cropSize = 0;
  int _rotQ = 0; // 0..3

  bool _didInitTransform = false;
  double? _lastCropSize;
  bool _isClamping = false;
  bool _showGrid = true;
  bool _isSaving = false;

  static const double _minScale = 1.0;
  static const double _prefMaxScale = 6.0;

  @override
  void initState() {
    super.initState();
    _tc.addListener(_onTcChanged);
    _loadFuture = _load();
  }

  @override
  void dispose() {
    _tc.removeListener(_onTcChanged);
    _tc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final raw = await File(widget.sourcePath).readAsBytes();
    final decoded = img.decodeImage(raw);
    if (decoded == null) throw Exception('อ่านรูปไม่สำเร็จ');

    _original = img.bakeOrientation(decoded);
    _srcW = _original.width;
    _srcH = _original.height;

    // ย่อเพื่อพรีวิว (ยาวสุด 1600px)
    const maxPreviewSide = 1600;
    final longest = math.max(_srcW, _srcH);
    img.Image preview = _original;
    if (longest > maxPreviewSide) {
      final k = maxPreviewSide / longest;
      preview = img.copyResize(
        _original,
        width: (_srcW * k).round(),
        height: (_srcH * k).round(),
        interpolation: img.Interpolation.cubic,
      );
    }
    _previewBytes = Uint8List.fromList(img.encodeJpg(preview, quality: 92));
  }

  // ───── Geometry ─────
  int get _logicW => (_rotQ % 2 == 0) ? _srcW : _srcH;
  int get _logicH => (_rotQ % 2 == 0) ? _srcH : _srcW;

  double get _coverMinScale => math.max(_cropSize / _baseW, _cropSize / _baseH);
  double get _dynamicMaxScale => math.max(_prefMaxScale, _coverMinScale + 2);

  void _computeBaseSize() {
    final w = _logicW.toDouble(), h = _logicH.toDouble();
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
      if (mounted) setState(() {});
      return;
    }
    _isClamping = true;
    _ensureCover();
    _isClamping = false;
    if (mounted) setState(() {});
  }

  void _resetAll() {
    HapticFeedback.selectionClick();
    _rotQ = 0;
    _didInitTransform = false;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureCover());
  }

  // หมุน 90° แบบตรรกะ + คงซูม/กึ่งกลาง
  void _rotateQuarter(int quarters) {
    final q = ((quarters % 4) + 4) % 4;
    if (q == 0) return;
    HapticFeedback.selectionClick();

    final m0 = _tc.value.clone();
    double s0 =
        m0.getMaxScaleOnAxis().clamp(_minScale, _dynamicMaxScale).toDouble();
    final tx0 = m0.storage[12], ty0 = m0.storage[13];
    final cx = _cropSize / 2, cy = _cropSize / 2;

    final relX = (cx - tx0) / (s0 * _baseW);
    final relY = (cy - ty0) / (s0 * _baseH);

    setState(() => _rotQ = (_rotQ + q) % 4);

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

      final tx = cx - nx * s0 * _baseW;
      final ty = cy - ny * s0 * _baseH;

      _tc.value = Matrix4.identity()
        ..translate(tx, ty)
        ..scale(s0);
      _ensureCover();
    });
  }

  void _setZoom(double newScale) {
    final coverMin = _coverMinScale;
    final target =
        newScale.clamp(coverMin, _dynamicMaxScale).toDouble(); // ← double
    final m = _tc.value.clone();
    final cur = m.getMaxScaleOnAxis();
    if (cur == 0) return;
    final factor = target / cur;
    m
      ..translate(_cropSize / 2, _cropSize / 2)
      ..scale(factor)
      ..translate(-_cropSize / 2, -_cropSize / 2);
    _tc.value = m;
    _ensureCover();
  }

  Offset? _lastTapPos;
  void _onDoubleTap() {
    final m = _tc.value.clone();
    final cur = m.getMaxScaleOnAxis();
    final coverMin = _coverMinScale;
    final target = (cur < coverMin * 1.5)
        ? math.min(coverMin * 2.0, _dynamicMaxScale)
        : coverMin;

    final focal = _lastTapPos ?? Offset(_cropSize / 2, _cropSize / 2);
    final factor = target / cur;

    m
      ..translate(focal.dx, focal.dy)
      ..scale(factor)
      ..translate(-focal.dx, -focal.dy);
    _tc.value = m;
    _ensureCover();
    HapticFeedback.lightImpact();
  }

  // ไม่ให้เลื่อนเกินภาพจริง
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
    m.storage[12] = m.storage[12].clamp(minTx - eps, maxTx + eps).toDouble();
    m.storage[13] = m.storage[13].clamp(minTy - eps, maxTy + eps).toDouble();

    _tc.value = m;
  }

  // ───── Save (isolate + loading) ─────
  Future<void> _doCrop() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final m = _tc.value;
      final s = m.getMaxScaleOnAxis();
      final tx = m.storage[12], ty = m.storage[13];

      // พิกัด base-space (หลังหมุนตรรกะ)
      final ix0 = (0 - tx) / s, iy0 = (0 - ty) / s;
      final ix1 = (_cropSize - tx) / s, iy1 = (_cropSize - ty) / s;

      // base -> logical
      final sx = _logicW / _baseW, sy = _logicH / _baseH;

      int rx = (ix0 * sx).floor();
      int ry = (iy0 * sy).floor();
      int rw = ((ix1 - ix0) * sx).round();
      int rh = ((iy1 - iy0) * sy).round();

      // ★ toInt() ให้เป็น int ชัดเจน
      rx = rx.clamp(0, _logicW - 1).toInt();
      ry = ry.clamp(0, _logicH - 1).toInt();
      rw = rw.clamp(1, _logicW - rx).toInt();
      rh = rh.clamp(1, _logicH - ry).toInt();

      final mapped = _mapRectToOriginal(
        rotQ: _rotQ,
        rx: rx,
        ry: ry,
        rw: rw,
        rh: rh,
        origW: _srcW,
        origH: _srcH,
      );

      final jpgBytes = await compute<_CropJob, Uint8List>(
        _cropInIsolate,
        _CropJob(
          path: widget.sourcePath,
          rectX: mapped.x,
          rectY: mapped.y,
          rectW: mapped.w,
          rectH: mapped.h,
          rotQ: _rotQ,
          maxSide: 1024,
          quality: 90,
        ),
      );

      final dir = await getTemporaryDirectory();
      final f = File(
          '${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await f.writeAsBytes(jpgBytes, flush: true);

      if (!mounted) return;
      Navigator.pop<File>(context, f);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('บันทึกล้มเหลว: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  _RectI _mapRectToOriginal({
    required int rotQ,
    required int rx,
    required int ry,
    required int rw,
    required int rh,
    required int origW,
    required int origH,
  }) {
    int x = 0, y = 0, w = 0, h = 0;
    final q = rotQ % 4;
    if (q == 0) {
      x = rx;
      y = ry;
      w = rw;
      h = rh;
    } else if (q == 1) {
      x = ry;
      // ★ ใช้ขอบเขต clamp เป็น origW และ .toInt()
      y = (origW - (rx + rw)).clamp(0, origW).toInt();
      w = rh;
      h = rw;
    } else if (q == 2) {
      x = (origW - (rx + rw)).clamp(0, origW).toInt();
      y = (origH - (ry + rh)).clamp(0, origH).toInt();
      w = rw;
      h = rh;
    } else {
      x = (origH - (ry + rh)).clamp(0, origW).toInt();
      y = rx;
      w = rh;
      h = rw;
    }
    // ★ สุดท้ายยืนยันขอบเขตด้วย .toInt()
    x = x.clamp(0, origW - 1).toInt();
    y = y.clamp(0, origH - 1).toInt();
    w = w.clamp(1, origW - x).toInt();
    h = h.clamp(1, origH - y).toInt();
    return _RectI(x, y, w, h);
  }

  // ───── UI ─────
  Widget _buildCropper() {
    _initTransform();

    // ภาพ “ชั้นเดียว” ให้ InteractiveViewer คุม transform
    final baseImage = SizedBox(
      width: _baseW,
      height: _baseH,
      child: RotatedBox(
        quarterTurns: _rotQ,
        child: Image.memory(
          _previewBytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      ),
    );

    return SizedBox(
      width: _cropSize,
      height: _cropSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onDoubleTapDown: (d) => _lastTapPos = d.localPosition,
            onDoubleTap: _onDoubleTap,
            child: InteractiveViewer(
              transformationController: _tc,
              // ★ ใช้ coverMin เป็น minScale เพื่อไม่ให้เด้งกลับ/เห็นขอบ
              minScale: _coverMinScale,
              maxScale: _dynamicMaxScale,
              boundaryMargin: EdgeInsets.zero,
              constrained: false,
              child: baseImage,
            ),
          ),
          // Overlay: ทำ “รูวงกลม” + กริด + เส้นขอบ (ไม่แตะภาพ → สีในวงกลมสด)
          IgnorePointer(
            child: CustomPaint(
              size: Size(_cropSize, _cropSize),
              painter: _HoleGridOverlayPainter(
                scrimColor: Colors.black.withOpacity(0.32),
                outlineColor: Colors.white.withOpacity(.95),
                outlineWidth: 1.5,
                showGrid: _showGrid,
                gridColor: Colors.white70,
                gridWidth: 0.9,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final cur = _tc.value.getMaxScaleOnAxis();
    final coverMin = _coverMinScale, dynMax = _dynamicMaxScale;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _iconBtn(Icons.rotate_left, 'หมุนซ้าย', () => _rotateQuarter(3)),
            const SizedBox(width: 22),
            _iconBtn(Icons.rotate_right, 'หมุนขวา', () => _rotateQuarter(1)),
            const SizedBox(width: 22),
            Column(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: Icon(_showGrid ? Icons.grid_on : Icons.grid_off),
                color: Theme.of(context).colorScheme.primary,
                onPressed: () {
                  setState(() => _showGrid = !_showGrid);
                  HapticFeedback.selectionClick();
                },
              ),
              Text('กริด', style: Theme.of(context).textTheme.bodySmall),
            ]),
          ]),
          const SizedBox(height: 8),
          _sliderRow(
            iconStart: Icons.zoom_out,
            iconEnd: Icons.zoom_in,
            child: Slider(
              value: cur.clamp(coverMin, dynMax).toDouble(), // ★ double
              min: coverMin,
              max: dynMax,
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

  Widget _iconBtn(IconData icon, String label, VoidCallback onPressed) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(icon),
            iconSize: 28,
            onPressed: onPressed,
            color: Theme.of(context).colorScheme.primary,
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );

  Widget _sliderRow({
    required IconData iconStart,
    required IconData iconEnd,
    required Widget child,
  }) =>
      Row(children: [
        Icon(iconStart, size: 20),
        Expanded(child: child),
        Icon(iconEnd, size: 20),
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
            onPressed: _isSaving ? null : _doCrop,
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
          return LayoutBuilder(builder: (_, cons) {
            final w = cons.maxWidth, h = cons.maxHeight;
            const panel = 200.0;
            // ★ กันจอเตี้ย: หัก panel + margin แล้วไม่ให้ติดลบ
            final usable = math.max(0.0, h - panel - 32);
            _cropSize = usable.clamp(220.0, w).toDouble();
            return Stack(children: [
              Column(children: [
                Expanded(child: Center(child: _buildCropper())),
                _buildControls(),
              ]),
              if (_isSaving)
                Container(
                  color: Colors.black.withOpacity(.35),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('กำลังบันทึก...',
                            style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
            ]);
          });
        },
      ),
      backgroundColor: Theme.of(context).colorScheme.background,
    );
  }
}

// ───── Painters ─────
class _HoleGridOverlayPainter extends CustomPainter {
  final Color scrimColor;
  final Color outlineColor;
  final double outlineWidth;
  final bool showGrid;
  final Color gridColor;
  final double gridWidth;

  const _HoleGridOverlayPainter({
    required this.scrimColor,
    required this.outlineColor,
    this.outlineWidth = 2,
    this.showGrid = true,
    this.gridColor = Colors.white70,
    this.gridWidth = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) / 2;
    final c = size.center(Offset.zero);

    // 1) วาดม่านจาง “ทั้งจอ” แล้วเจาะรูวงกลมให้ทะลุภาพชั้นล่าง
    final layerBounds = Offset.zero & size;
    canvas.saveLayer(layerBounds, Paint());
    canvas.drawRect(layerBounds, Paint()..color = scrimColor);
    // เจาะรู
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    canvas.drawCircle(c, r, clearPaint);
    canvas.restore();

    // 2) กริด 3x3 “เฉพาะในวงกลม”
    if (showGrid) {
      final gridPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = gridWidth
        ..color = gridColor;
      canvas.save();
      final clip = Path()..addOval(Rect.fromCircle(center: c, radius: r));
      canvas.clipPath(clip);
      for (int i = 1; i <= 2; i++) {
        final t = i / 3.0;
        final vx = size.width * t;
        final hy = size.height * t;
        canvas.drawLine(Offset(vx, 0), Offset(vx, size.height), gridPaint);
        canvas.drawLine(Offset(0, hy), Offset(size.width, hy), gridPaint);
      }
      canvas.restore();
    }

    // 3) เส้นขอบวงกลม
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = outlineWidth
      ..color = outlineColor;
    canvas.drawCircle(c, r - outlineWidth / 2, border);
  }

  @override
  bool shouldRepaint(covariant _HoleGridOverlayPainter old) =>
      old.scrimColor != scrimColor ||
      old.outlineColor != outlineColor ||
      old.outlineWidth != outlineWidth ||
      old.showGrid != showGrid ||
      old.gridColor != gridColor ||
      old.gridWidth != gridWidth;
}

class _RectI {
  final int x, y, w, h;
  const _RectI(this.x, this.y, this.w, this.h);
}

// ───── Isolate job ─────
class _CropJob {
  final String path;
  final int rectX, rectY, rectW, rectH;
  final int rotQ;
  final int maxSide;
  final int quality;
  const _CropJob({
    required this.path,
    required this.rectX,
    required this.rectY,
    required this.rectW,
    required this.rectH,
    required this.rotQ,
    required this.maxSide,
    required this.quality,
  });
}

Future<Uint8List> _cropInIsolate(_CropJob job) async {
  final bytes = await File(job.path).readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw Exception('decode fail');

  img.Image base = img.bakeOrientation(decoded);
  img.Image out = img.copyCrop(
    base,
    x: job.rectX,
    y: job.rectY,
    width: job.rectW,
    height: job.rectH,
  );

  if (job.rotQ == 1) {
    out = img.copyRotate(out, angle: 90);
  } else if (job.rotQ == 2) {
    out = img.copyRotate(out, angle: 180);
  } else if (job.rotQ == 3) {
    out = img.copyRotate(out, angle: -90);
  }

  if (out.width > job.maxSide || out.height > job.maxSide) {
    out = img.copyResize(
      out,
      width: out.width >= out.height ? job.maxSide : null,
      height: out.height > out.width ? job.maxSide : null,
      interpolation: img.Interpolation.cubic,
    );
  }
  return Uint8List.fromList(img.encodeJpg(out, quality: job.quality));
}
