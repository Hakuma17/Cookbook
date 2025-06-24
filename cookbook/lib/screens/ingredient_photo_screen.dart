// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:flutter/services.dart';

import 'ingredient_prediction_result_screen.dart';

Future<List<String>?> scanIngredient(BuildContext context) =>
    Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (_) => const IngredientPhotoScreen()),
    );

class IngredientPhotoScreen extends StatefulWidget {
  const IngredientPhotoScreen({super.key});

  @override
  State<IngredientPhotoScreen> createState() => _IngredientPhotoScreenState();
}

class _IngredientPhotoScreenState extends State<IngredientPhotoScreen> {
  File? _imageFile;
  bool _busy = false;
  bool _detecting = false;
  List<Map<String, dynamic>> _results = const [];
  final _picker = ImagePicker();

  late tfl.Interpreter _interpreter;
  late List<String> _labels;
  bool _modelReady = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  @override
  void dispose() {
    _interpreter.close();
    super.dispose();
  }

  Future<void> _loadModel() async {
    try {
      // ไม่ต้อง prefix 'assets/'
      _interpreter = await tfl.Interpreter.fromAsset(
          'assets/converted_tflite_quantized/model_unquant.tflite');
      _interpreter.allocateTensors();

      _labels = (await rootBundle
              .loadString('assets/converted_tflite_quantized/labels.txt'))
          .split('\n')
          .where((e) => e.trim().isNotEmpty)
          .toList();

      setState(() => _modelReady = true);
    } catch (e) {
      _showSnack('โหลดโมเดลล้มเหลว: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _runModel(File file) async {
    // อ่านไฟล์รูป
    final bytes = await file.readAsBytes();
    final imgSrc = img.decodeImage(bytes);
    if (imgSrc == null) return [];

    // ย่อรูป
    final resized = img.copyResize(imgSrc, width: 224, height: 224);

    // ดึง raw bytes (RGB) → length = 224*224*3
    final rgb = resized.getBytes();

    // สร้าง input buffer [1,224,224,3]
    final input = Float32List(rgb.length);
    for (int i = 0; i < rgb.length; i++) {
      input[i] = rgb[i] / 255.0;
    }

    // เตรียม output buffer
    final output =
        List.filled(_labels.length, 0.0).reshape([1, _labels.length]);

    // รัน interpreter
    _interpreter.run(input.reshape([1, 224, 224, 3]), output);

    // เก็บผลลัพธ์ที่ confidence > 0.05
    final res = <Map<String, dynamic>>[];
    for (int i = 0; i < _labels.length; i++) {
      final score = output[0][i] as double;
      if (score > 0.05) {
        res.add({'label': _labels[i], 'confidence': score});
      }
    }
    res.sort((a, b) =>
        (b['confidence'] as double).compareTo(a['confidence'] as double));
    return res;
  }

  Future<void> _pickImage(ImageSource src) async {
    if (_busy || !_modelReady) return;
    setState(() => _busy = true);

    if (!await _requestPermission(src)) {
      _showSnack('ไม่อนุญาตให้เข้าถึงกล้อง/รูปภาพ');
      setState(() => _busy = false);
      return;
    }

    final picked = await _picker.pickImage(source: src, imageQuality: 85);
    if (picked == null) {
      setState(() => _busy = false);
      return;
    }
    final file = File(picked.path);

    setState(() {
      _imageFile = file;
      _detecting = true;
      _results = const [];
    });

    _results = await _runModel(file);

    if (mounted) setState(() => _detecting = false);
    setState(() => _busy = false);

    if (_results.isNotEmpty) {
      final top = _results.first;
      final selected = await Navigator.push<List<String>>(
        context,
        MaterialPageRoute(
          builder: (_) => IngredientPredictionResultScreen(
            imageFile: file,
            predictedName: top['label'] as String,
            confidence: top['confidence'] as double,
          ),
        ),
      );
      if (selected != null) Navigator.pop(context, selected);
    }
  }

  Future<bool> _requestPermission(ImageSource src) async {
    if (kIsWeb) return true;
    if (src == ImageSource.camera) {
      return (await Permission.camera.request()).isGranted;
    }
    final info = await DeviceInfoPlugin().androidInfo;
    if ((info.version.sdkInt ?? 0) >= 33) {
      return (await Permission.photos.request()).isGranted;
    }
    return (await Permission.storage.request()).isGranted;
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF9B05);
    return WillPopScope(
      onWillPop: () async {
        if (_imageFile != null || _results.isNotEmpty) {
          setState(() {
            _imageFile = null;
            _results = const [];
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFEED6),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(orange),
              const SizedBox(height: 12),
              _buildFrame(orange),
              const SizedBox(height: 24),
              if (_detecting) const CircularProgressIndicator(),
              if (!_detecting && _results.isNotEmpty) _buildResultCard(),
              const Spacer(),
              _buildBottomButtons(),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color o) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text('ยกเลิก',
                  style: TextStyle(
                      fontSize: 16, color: o, fontWeight: FontWeight.w700)),
            ),
            Text('Take Photo',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: o,
                    fontFamily: 'Josefin Sans')),
            const SizedBox(width: 56),
          ],
        ),
      );

  Widget _buildFrame(Color o) => AspectRatio(
        aspectRatio: 3 / 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white24,
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: _imageFile == null
                ? Center(child: Icon(Icons.camera_alt, size: 100, color: o))
                : Image.file(_imageFile!, fit: BoxFit.cover),
          ),
        ),
      );

  Widget _buildBottomButtons() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _iconButton('assets/icons/gallery_icon.png',
              () => _pickImage(ImageSource.gallery)),
          const SizedBox(width: 48),
          _shutterButton(() => _pickImage(ImageSource.camera)),
        ],
      );

  Widget _iconButton(String a, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Image.asset(a, width: 60, height: 60),
      );

  Widget _shutterButton(VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 1.4)),
          alignment: Alignment.center,
          child: const CircleAvatar(radius: 32, backgroundColor: Colors.black),
        ),
      );

  Widget _buildResultCard() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Card(
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ผลการตรวจจับ',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(),
                ..._results.take(3).map((e) => ListTile(
                      leading: Image.asset(
                        'assets/images/ingredients/${_sanitizeLabel(e['label'] as String)}.png',
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image),
                      ),
                      title: Text(e['label'] as String),
                      trailing: Text(
                          '${(e['confidence'] * 100).toStringAsFixed(1)}%'),
                    )),
              ],
            ),
          ),
        ),
      );

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _sanitizeLabel(String label) =>
      label.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
}
