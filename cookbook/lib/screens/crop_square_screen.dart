// lib/screens/crop_square_screen.dart
// Custom square cropper with top/bottom guards and precise transform
// Inspired by CropAvatarScreen but uses a square overlay (rounded-rect)

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class CropSquareScreen extends StatefulWidget {
  final String sourcePath;
  const CropSquareScreen({super.key, required this.sourcePath});

  @override
  State<CropSquareScreen> createState() => _CropSquareScreenState();
}

class _CropSquareScreenState extends State<CropSquareScreen> {
  final _tc = TransformationController();

  late Future<void> _loadFuture;
  late img.Image _original;
  late Uint8List _previewBytes;

  int _srcW = 0, _srcH = 0;
  double _baseW = 0, _baseH = 0;
  double _cropSize = 0;
  int _rotQ = 0;

  bool _didInitTransform = false;
  double? _lastCropSize;
  bool _isClamping = false;
  bool _showGrid = true;
  bool _isSaving = false;

  static const double _prefMaxScale = 6.0;
  static const int _kMinOutDim = 224;

  int _projW = 0, _projH = 0; // projected output size (px)

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

    // preview (max 1600px)
    const maxPreviewSide = 1600;
    final longest = math.max(_srcW, _srcH);
    final preview = longest > maxPreviewSide
        ? img.copyResize(
            _original,
            width: (_srcW * (maxPreviewSide / longest)).round(),
            height: (_srcH * (maxPreviewSide / longest)).round(),
            interpolation: img.Interpolation.cubic,
          )
        : _original;
    _previewBytes = Uint8List.fromList(img.encodeJpg(preview, quality: 92));
  }

  // geometry helpers
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureCover();
      _recomputeProjectedSize();
      if (mounted) setState(() {});
    });
  }

  void _onTcChanged() {
    if (!mounted || _isClamping || !_didInitTransform) {
      if (mounted) setState(() {});
      return;
    }
    _isClamping = true;
    _ensureCover();
    _recomputeProjectedSize();
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

  void _rotateQuarter(int quarters) {
    final q = ((quarters % 4) + 4) % 4;
    if (q == 0) return;
    HapticFeedback.selectionClick();

    final m0 = _tc.value.clone();
    double s0 = m0
        .getMaxScaleOnAxis()
        .clamp(_coverMinScale, _dynamicMaxScale)
        .toDouble();
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
      _recomputeProjectedSize();
      if (mounted) setState(() {});
    });
  }

  void _setZoom(double newScale) {
    final coverMin = _coverMinScale;
    final target = newScale.clamp(coverMin, _dynamicMaxScale).toDouble();
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
    _recomputeProjectedSize();
    if (mounted) setState(() {});
  }

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

  void _recomputeProjectedSize() {
    if (_cropSize <= 0 || _baseW <= 0 || _baseH <= 0) return;
    final m = _tc.value;
    final s = m.getMaxScaleOnAxis();
    final tx = m.storage[12], ty = m.storage[13];
    final ix0 = (0 - tx) / s, iy0 = (0 - ty) / s;
    final ix1 = (_cropSize - tx) / s, iy1 = (_cropSize - ty) / s;
    final sx = _logicW / _baseW, sy = _logicH / _baseH;
    int rx = (ix0 * sx).floor();
    int ry = (iy0 * sy).floor();
    int rw = ((ix1 - ix0) * sx).round();
    int rh = ((iy1 - iy0) * sy).round();
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
    _projW = mapped.w;
    _projH = mapped.h;
  }

  bool get _isValidOut => _projW >= _kMinOutDim && _projH >= _kMinOutDim;

  Future<void> _doCrop() async {
    if (_isSaving) return;
    if (!_isValidOut) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('ขนาดผลลัพธ์เล็กเกินไป (อย่างน้อย 224x224 พิกเซล)')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final m = _tc.value;
      final s = m.getMaxScaleOnAxis();
      final tx = m.storage[12], ty = m.storage[13];

      // base-space rect (after rotation logic)
      final ix0 = (0 - tx) / s, iy0 = (0 - ty) / s;
      final ix1 = (_cropSize - tx) / s, iy1 = (_cropSize - ty) / s;
      final sx = _logicW / _baseW, sy = _logicH / _baseH;

      int rx = (ix0 * sx).floor();
      int ry = (iy0 * sy).floor();
      int rw = ((ix1 - ix0) * sx).round();
      int rh = ((iy1 - iy0) * sy).round();

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
          maxSide: 2048,
          quality: 90,
        ),
      );

      final dir = await getTemporaryDirectory();
      final f =
          File('${dir.path}/crop_${DateTime.now().millisecondsSinceEpoch}.jpg');
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
    x = x.clamp(0, origW - 1).toInt();
    y = y.clamp(0, origH - 1).toInt();
    w = w.clamp(1, origW - x).toInt();
    h = h.clamp(1, origH - y).toInt();
    return _RectI(x, y, w, h);
  }

  // UI
  Widget _buildCropper() {
    _initTransform();
    final baseImage = SizedBox(
      width: _baseW,
      height: _baseH,
      child: RotatedBox(
        quarterTurns: _rotQ,
        child: Image.memory(_previewBytes,
            fit: BoxFit.cover, gaplessPlayback: true),
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
              minScale: _coverMinScale,
              maxScale: _dynamicMaxScale,
              boundaryMargin: EdgeInsets.zero,
              constrained: false,
              child: baseImage,
            ),
          ),
          IgnorePointer(
            child: CustomPaint(
              size: Size(_cropSize, _cropSize),
              painter: _RectGridOverlayPainter(
                scrimColor: Colors.black.withOpacity(0.32),
                outlineColor: (_isValidOut ? Colors.white : Colors.redAccent)
                    .withOpacity(.95),
                outlineWidth: 1.5,
                showGrid: _showGrid,
                gridColor: Colors.white70,
                gridWidth: 0.9,
                cornerRadius: 16,
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _isValidOut ? Colors.white70 : Colors.redAccent,
                ),
              ),
              child: Text(
                '${_projW}×${_projH} px',
                style: TextStyle(
                  color: _isValidOut ? Colors.white : Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (!_isValidOut)
            Positioned(
              bottom: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.55),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'อย่างน้อย 224×224 พิกเซล',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
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

  Widget _controls() {
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
          Row(children: [
            const Icon(Icons.zoom_out, size: 20),
            Expanded(
              child: Slider(
                value: cur.clamp(coverMin, dynMax).toDouble(),
                min: coverMin,
                max: dynMax,
                onChanged: _setZoom,
              ),
            ),
            const Icon(Icons.zoom_in, size: 20),
          ]),
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

  @override
  Widget build(BuildContext context) {
    final vp = MediaQuery.viewPaddingOf(context);
    final double topGuard = vp.top < 8 ? 8.0 : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: EdgeInsets.only(top: topGuard),
          child: const Text('ครอบตัดรูปภาพ'),
        ),
        leading: Padding(
          padding: EdgeInsets.only(top: topGuard),
          child: IconButton(
            tooltip: 'ยกเลิก',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(top: topGuard),
            child: IconButton(
              tooltip: 'บันทึก',
              icon: const Icon(Icons.check),
              onPressed: _isSaving || !_isValidOut ? null : _doCrop,
            ),
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
            final usable = math.max(0.0, h - panel - 32);
            _cropSize = usable.clamp(220.0, w).toDouble();
            return Stack(children: [
              Column(children: [
                Expanded(child: Center(child: _buildCropper())),
                _controls(),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
    );
  }
}

class _RectI {
  final int x, y, w, h;
  const _RectI(this.x, this.y, this.w, this.h);
}

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

Uint8List _cropInIsolate(_CropJob job) {
  final raw = File(job.path).readAsBytesSync();
  final decoded0 = img.decodeImage(raw);
  if (decoded0 == null) throw Exception('อ่านไฟล์รูปภาพไม่สำเร็จ');
  img.Image src = img.bakeOrientation(decoded0);

  // rotate logical
  for (int i = 0; i < job.rotQ % 4; i++) {
    src = img.copyRotate(src, angle: 90);
  }

  final rx = job.rectX.clamp(0, src.width - 1);
  final ry = job.rectY.clamp(0, src.height - 1);
  final rw = job.rectW.clamp(1, src.width - rx);
  final rh = job.rectH.clamp(1, src.height - ry);

  img.Image cropped = img.copyCrop(src, x: rx, y: ry, width: rw, height: rh);

  // resize down if needed
  final longest = math.max(cropped.width, cropped.height);
  if (longest > job.maxSide) {
    final k = job.maxSide / longest;
    cropped = img.copyResize(
      cropped,
      width: (cropped.width * k).round(),
      height: (cropped.height * k).round(),
      interpolation: img.Interpolation.cubic,
    );
  }

  return Uint8List.fromList(img.encodeJpg(cropped, quality: job.quality));
}

class _RectGridOverlayPainter extends CustomPainter {
  final Color scrimColor;
  final Color outlineColor;
  final double outlineWidth;
  final bool showGrid;
  final Color gridColor;
  final double gridWidth;
  final double cornerRadius;

  const _RectGridOverlayPainter({
    required this.scrimColor,
    required this.outlineColor,
    this.outlineWidth = 2,
    this.showGrid = true,
    this.gridColor = Colors.white70,
    this.gridWidth = 1,
    this.cornerRadius = 16,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height);
    final frame = Rect.fromLTWH(
      (size.width - r) / 2,
      (size.height - r) / 2,
      r,
      r,
    );
    final rr = RRect.fromRectAndRadius(frame, Radius.circular(cornerRadius));

    // scrim with hole
    final layerBounds = Offset.zero & size;
    canvas.saveLayer(layerBounds, Paint());
    canvas.drawRect(layerBounds, Paint()..color = scrimColor);
    canvas.drawRRect(rr, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    if (showGrid) {
      final gridPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = gridWidth
        ..color = gridColor;
      canvas.save();
      final clip = Path()..addRRect(rr);
      canvas.clipPath(clip);
      for (int i = 1; i <= 2; i++) {
        final t = i / 3.0;
        final vx = frame.left + frame.width * t;
        final hy = frame.top + frame.height * t;
        canvas.drawLine(
            Offset(vx, frame.top), Offset(vx, frame.bottom), gridPaint);
        canvas.drawLine(
            Offset(frame.left, hy), Offset(frame.right, hy), gridPaint);
      }
      canvas.restore();
    }

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = outlineWidth
      ..color = outlineColor;
    canvas.drawRRect(rr, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
