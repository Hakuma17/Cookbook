// ignore_for_file: use_build_context_synchronously, constant_identifier_names

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import 'ingredient_photo_screen.dart';

/// ─── map label → ชื่อไทย ─────────────────────────────────────
const Map<String, String> _kLabelMap = {
  'garlic': 'กระเทียม',
  'lime': 'มะนาว',
  'long_bean': 'ถั่วฝักยาว',
  'chilli': 'พริก',
  'carrot': 'แครอท',
  'cabbage': 'กะหล่ำปลี',
  'egg': 'ไข่',
  'tomato': 'มะเขือเทศ',
  'onion': 'หัวหอม',
  'lemongrass': 'ตะไคร้',
};

const double _kAutoFillThreshold = 0.80;
const double contentWidth = 312.0;
const double imgHeight = 205.0;
const double listBoxHeight = 140.0;

class IngredientPredictionResultScreen extends StatefulWidget {
  final File imageFile;
  final String? predictedName;
  final double? confidence;

  const IngredientPredictionResultScreen({
    Key? key,
    required this.imageFile,
    this.predictedName,
    this.confidence,
  }) : super(key: key);

  @override
  _IngredientPredictionResultScreenState createState() =>
      _IngredientPredictionResultScreenState();
}

class _IngredientPredictionResultScreenState
    extends State<IngredientPredictionResultScreen> {
  late tfl.Interpreter _itp;
  late List<String> _labels;
  bool _modelReady = false, _running = false;

  final _inputCtrl = TextEditingController();
  final _selected = <String>{};

  List<_Pred> _preds = [];
  bool _showPreds = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
    if ((widget.confidence ?? 0) >= _kAutoFillThreshold &&
        widget.predictedName != null) {
      _inputCtrl.text = _map(widget.predictedName!);
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _itp.close();
    super.dispose();
  }

  Future<void> _loadModel() async {
    _itp = await tfl.Interpreter.fromAsset(
      'assets/converted_tflite_quantized/model_unquant.tflite',
    )
      ..allocateTensors();

    _labels = (await rootBundle
            .loadString('assets/converted_tflite_quantized/labels.txt'))
        .split('\n')
        .where((e) => e.trim().isNotEmpty)
        .toList();

    setState(() => _modelReady = true);
    _runInference();
  }

  Future<void> _runInference() async {
    if (!_modelReady || _running) return;
    _running = true;
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return;

      final resized = img.copyResize(decoded, width: 224, height: 224);
      final rgb = resized.getBytes();
      final input = Float32List(rgb.length);
      for (var i = 0; i < rgb.length; i++) input[i] = rgb[i] / 255.0;

      final output =
          List.filled(_labels.length, 0.0).reshape([1, _labels.length]);
      _itp.run(input.reshape([1, 224, 224, 3]), output);

      final all = <_Pred>[];
      for (var i = 0; i < _labels.length; i++) {
        final sc = output[0][i] as double;
        if (sc > 0) all.add(_Pred(_map(_labels[i]), sc));
      }
      all.sort((a, b) => b.score.compareTo(a.score));

      setState(() {
        _preds = all.take(3).toList();
      });

      if (_preds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่รู้จักวัตถุดิบ')),
        );
      }
    } finally {
      _running = false;
    }
  }

  String _map(String raw) => _kLabelMap[raw.toLowerCase()] ?? raw;

  void _addToList() {
    final v = _inputCtrl.text.trim();
    if (v.isNotEmpty) setState(() => _selected.add(v));
    _inputCtrl.clear();
  }

  void _remove(String n) => setState(() => _selected.remove(n));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE3B9),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Custom Header ─────────────────
            Container(
              width: double.infinity,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade400, width: 2),
                ),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(34)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 24,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'ยกเลิก',
                        style: TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF9B05),
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    'เพิ่มวัตถุดิบ',
                    style: TextStyle(
                      fontFamily: 'Josefin Sans',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF9B05),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Column(
                    children: [
                      // รูป
                      Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            widget.imageFile,
                            width: contentWidth,
                            height: imgHeight,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Image.asset(
                              'assets/images/default_ingredients.png',
                              width: contentWidth,
                              height: imgHeight,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ช่องกรอก + ปุ่ม +
                      SizedBox(
                        width: contentWidth,
                        child: _ManualInput(
                          controller: _inputCtrl,
                          onAdd: _addToList,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ผลทำนาย expandable
                      SizedBox(
                        width: contentWidth,
                        child: GestureDetector(
                          onTap: () => setState(() => _showPreds = !_showPreds),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ผลลัพธ์การทำนาย',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              Icon(
                                _showPreds
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: Colors.grey.shade800,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_showPreds && _preds.isNotEmpty)
                        SizedBox(
                          width: contentWidth,
                          child: Column(
                            children: List.generate(_preds.length, (i) {
                              return _buildPredictionBar(_preds[i], i);
                            }),
                          ),
                        ),
                      const SizedBox(height: 24),

                      // รายการวัตถุดิบ (fixed size, scroll inside)
                      if (_selected.isNotEmpty) ...[
                        SizedBox(
                          width: contentWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'รายการวัตถุดิบ',
                                style: TextStyle(
                                  fontFamily: 'Roboto Condensed',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: contentWidth,
                                height: listBoxHeight,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFBEEDC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.black12),
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: _selected.map((name) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(right: 12),
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Image.asset(
                                                    'assets/ingredients/${name.toLowerCase()}.png',
                                                    width: 78,
                                                    height: 78,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (_, __, ___) =>
                                                            Image.asset(
                                                      'assets/images/default_ingredients.png',
                                                      width: 78,
                                                      height: 78,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  name,
                                                  style: const TextStyle(
                                                    fontFamily: 'Montserrat',
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Positioned(
                                              right: -8,
                                              top: -8,
                                              child: GestureDetector(
                                                onTap: () => _remove(name),
                                                child: Container(
                                                  width: 24,
                                                  height: 24,
                                                  decoration:
                                                      const BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.redAccent,
                                                  ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    size: 16,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // ปุ่มหลัก
                      SizedBox(
                        width: contentWidth,
                        child: _PrimaryButton(
                          onTap: () =>
                              Navigator.pop(context, _selected.toList()),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // FAB สแกนซ้ำ
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: Colors.black87,
        onPressed: () async {
          final added = await Navigator.push<List<String>>(
            context,
            MaterialPageRoute(builder: (_) => const IngredientPhotoScreen()),
          );
          if (added != null && added.isNotEmpty) {
            setState(() => _selected.addAll(added));
          }
        },
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildPredictionBar(_Pred p, int index) {
    // สามสีสำหรับอันดับ 1–3
    final colors = [
      const Color(0xFFFF9B05),
      const Color(0xFFFF4081),
      const Color(0xFF7C4DFF),
    ];
    final fillColor = colors[index];
    final bgColor = fillColor.withOpacity(0.2);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        width: contentWidth,
        height: 32,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            // เติมสีเข้มตามเปอร์เซ็นต์
            FractionallySizedBox(
              widthFactor: p.score.clamp(0.0, 1.0),
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            // แสดงชื่อและเปอร์เซ็นต์ด้านใน
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      p.label,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${(p.score * 100).toInt()}%',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pred {
  final String label;
  final double score;
  _Pred(this.label, this.score);
}

class _PrimaryButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PrimaryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFFF00F7),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
                color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))
          ],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.search, size: 28, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'ดูสูตรอาหาร',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onAdd;
  const _ManualInput({
    required this.controller,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
              decoration: const InputDecoration(
                hintText: 'พิมพ์ชื่อวัตถุดิบ',
                border: InputBorder.none,
              ),
            ),
          ),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFF9B05),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}
