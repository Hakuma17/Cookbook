// lib/debug/tm_selfcheck.dart
// Debug-only utility to validate TM parity on-device.
// How to use (debug mode only):
// 1) Put a test image under assets/test_samples/sample.jpg and add it to pubspec.yaml assets.
// 2) From anywhere in your app (debug build), call: await runTmSelfCheck('sample.jpg');
// 3) Observe logs: dumped 224×224 path, first 10 normalized floats, and top-3 predictions.
// 4) Compare with TM web preview by uploading the SAME image; top-1 label and probability
//    should match within ±3% when resize and normalization match.

// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

Future<void> runTmSelfCheck(String assetFileName) async {
  assert(kDebugMode, 'tm_selfcheck is intended for debug builds only');

  // Load bytes from assets/test_samples/<assetFileName>
  final bytes = await rootBundle.load('assets/test_samples/$assetFileName');
  final data = bytes.buffer.asUint8List();
  final dec0 = img.decodeImage(data);
  if (dec0 == null) {
    print('[TM-SelfCheck] Failed to decode image');
    return;
  }
  final dec = img.bakeOrientation(dec0);
  // STRETCH to 224×224 (TM preview policy)
  final pre = img.copyResize(dec,
      width: 224, height: 224, interpolation: img.Interpolation.linear);

  // Dump preprocessed input
  final dir = await getTemporaryDirectory();
  final dumpPath =
      '${dir.path}/tm_input_${DateTime.now().millisecondsSinceEpoch}.png';
  await File(dumpPath).writeAsBytes(img.encodePng(pre));
  print('[TM-SelfCheck] dumped input224=$dumpPath');

  // Load interpreter
  final options = tfl.InterpreterOptions()..threads = 2;
  final interpreter = await tfl.Interpreter.fromAsset(
    'assets/converted_tflite_quantized/model_unquant.tflite',
    options: options,
  );
  final inT = interpreter.getInputTensor(0);
  final outT = interpreter.getOutputTensor(0);
  final inputIsFloat = inT.type.toString().toLowerCase().contains('float');
  final outputIsFloat = outT.type.toString().toLowerCase().contains('float');
  print('[TM-SelfCheck] input=$inputIsFloat shape=${inT.shape}');
  print('[TM-SelfCheck] output=$outputIsFloat shape=${outT.shape}');

  // Pack input (default [0,1] for float32)
  dynamic modelInput;
  if (inputIsFloat) {
    final flat = Float32List(1 * 224 * 224 * 3);
    var i = 0;
    for (var y = 0; y < 224; y++) {
      for (var x = 0; x < 224; x++) {
        final p = pre.getPixel(x, y);
        flat[i++] = (p.r.toInt() & 0xFF) / 255.0;
        flat[i++] = (p.g.toInt() & 0xFF) / 255.0;
        flat[i++] = (p.b.toInt() & 0xFF) / 255.0;
      }
    }
    modelInput = [
      List.generate(
          224,
          (y) => List.generate(224, (x) {
                final base = (y * 224 + x) * 3;
                return [flat[base + 0], flat[base + 1], flat[base + 2]];
              }))
    ];
    // print first 10 floats
    print('[TM-SelfCheck] first 10 floats: ' +
        List<double>.generate(10, (k) => flat[k]).toString());
  } else {
    final flat = Uint8List(1 * 224 * 224 * 3);
    var i = 0;
    for (var y = 0; y < 224; y++) {
      for (var x = 0; x < 224; x++) {
        final p = pre.getPixel(x, y);
        flat[i++] = p.r.toInt();
        flat[i++] = p.g.toInt();
        flat[i++] = p.b.toInt();
      }
    }
    modelInput = [
      List.generate(
          224,
          (y) => List.generate(224, (x) {
                final base = (y * 224 + x) * 3;
                return [flat[base + 0], flat[base + 1], flat[base + 2]];
              }))
    ];
    print('[TM-SelfCheck] first 10 bytes: ' +
        List<int>.generate(10, (k) => flat[k]).toString());
  }

  // Prepare output
  final labelStr = await rootBundle
      .loadString('assets/converted_tflite_quantized/labels.txt');
  final lines = labelStr
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  final byIdx = <int, String>{};
  int maxIdx = -1;
  final re = RegExp(r'^(\d+)\s+(.+)$');
  for (final line in lines) {
    final m = re.firstMatch(line);
    if (m != null) {
      final idx = int.parse(m.group(1)!);
      byIdx[idx] = m.group(2)!.trim();
      if (idx > maxIdx) maxIdx = idx;
    } else {
      maxIdx += 1;
      byIdx[maxIdx] = line;
    }
  }
  final labels = List<String>.generate(maxIdx + 1, (i) => byIdx[i] ?? '');
  if (labels.length != outT.shape.last) {
    print(
        '[TM-SelfCheck] ERROR: labels(${labels.length}) != outDim(${outT.shape.last})');
    return;
  }

  dynamic modelOutput = outputIsFloat
      ? [List<double>.filled(labels.length, 0.0)]
      : [List<int>.filled(labels.length, 0)];
  interpreter.run(modelInput, modelOutput);

  // Dequantize if required and softmax if needed
  final raw = List<double>.generate(labels.length, (i) {
    if (outputIsFloat) return (modelOutput[0][i] as num).toDouble();
    final q = (modelOutput[0][i] as num).toInt();
    return outT.params.scale * (q - outT.params.zeroPoint);
  });
  final s = raw.fold<double>(0, (a, b) => a + (b.isFinite ? b : 0.0));
  List<double> probs;
  if (s < 0.9 || s > 1.1) {
    final maxL = raw.reduce((a, b) => a > b ? a : b);
    final exps = raw
        .map((v) => (v - maxL).clamp(-40.0, 40.0))
        .map((z) => math.exp(z))
        .toList();
    final sumEx = exps.fold<double>(0.0, (a, b) => a + b);
    probs = exps.map((e) => e / (sumEx == 0 ? 1 : sumEx)).toList();
  } else {
    probs = raw.map((v) => v.clamp(0.0, 1.0)).toList();
  }

  final idxs = List<int>.generate(labels.length, (i) => i);
  idxs.sort((a, b) => probs[b].compareTo(probs[a]));
  for (int k = 0; k < (labels.length < 3 ? labels.length : 3); k++) {
    final i = idxs[k];
    print(
        '[TM-SelfCheck] top${k + 1}: ${labels[i]} ${(probs[i] * 100).toStringAsFixed(1)}%');
  }
}
