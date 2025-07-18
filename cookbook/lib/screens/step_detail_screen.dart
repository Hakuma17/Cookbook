// lib/screens/step_detail_screen.dart (ฉบับ Final - เลือกเพศแบบฉลาด)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/recipe_step.dart';

class StepDetailScreen extends StatefulWidget {
  final List<RecipeStep> steps;
  final List<String> imageUrls;
  final int initialIndex;

  const StepDetailScreen({
    Key? key,
    required this.steps,
    required this.imageUrls,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<StepDetailScreen> createState() => _StepDetailScreenState();
}

class _StepDetailScreenState extends State<StepDetailScreen> {
  late final FlutterTts _tts;
  late int _idx;
  bool _busy = false;
  bool _spoken = false;

  // --- State สำหรับการตั้งค่าเสียง ---
  bool _isFemaleVoice = true; // ค่าเริ่มต้นเป็นเสียงผู้หญิง
  List<Map> _thaiVoices = [];
  double _speechRate = 0.5;
  double _pitch = 1.0;

  // Future สำหรับรอให้ init เสร็จ
  late Future<void> _ttsInitializationFuture;

  @override
  void initState() {
    super.initState();
    _idx = widget.initialIndex.clamp(0, widget.steps.length - 1);
    _ttsInitializationFuture = _initTts();
  }

  Future<void> _initTts() async {
    _tts = FlutterTts();
    _tts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _spoken = true;
      });
    });

    try {
      // ดึงเสียงทั้งหมดในเครื่องมาเก็บไว้
      final voices = List<Map>.from(await _tts.getVoices as List);
      if (mounted) {
        _thaiVoices = voices.where((v) => v['locale'] == 'th-TH').toList();
      }
    } catch (e) {
      debugPrint("Error initializing TTS voices: $e");
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

// แก้ไขเฉพาะฟังก์ชันนี้
  Future<void> _speak() async {
    if (_busy) return;
    final txt = widget.steps[_idx].description.trim();
    if (txt.isEmpty) {
      _showSnack('ไม่มีข้อความให้พูด');
      return;
    }

    // ★★★ แก้ไข Logic การค้นหาเสียงให้ตรงกับรหัส "thd" และ "thc" ★★★
    String? voiceNameToUse;
    if (_thaiVoices.isNotEmpty) {
      Map? foundVoice;
      if (_isFemaleVoice) {
        // หาเสียงผู้หญิง (thc) ก่อน
        foundVoice = _thaiVoices.firstWhere(
            (v) => v['name'].toString().contains('-thc-'),
            orElse: () => _thaiVoices.first);
      } else {
        // หาเสียงผู้ชาย (thd)
        foundVoice = _thaiVoices.firstWhere(
            (v) => v['name'].toString().contains('-thd-'),
            orElse: () => {});
      }

      if (foundVoice != null) {
        voiceNameToUse = foundVoice['name'];
      } else if (!_isFemaleVoice) {
        // ถ้าเลือกผู้ชาย แต่หาไม่เจอเลย ให้แจ้งผู้ใช้และใช้เสียง default แทน
        _showSnack('ไม่พบเสียงผู้ชาย, ใช้เสียงตั้งต้นแทน');
        voiceNameToUse = _thaiVoices.first['name'];
      }
    }

    if (voiceNameToUse == null && _thaiVoices.isNotEmpty) {
      // Fallback สุดท้ายถ้าเกิดกรณีแปลกๆ
      voiceNameToUse = _thaiVoices.first['name'];
    }

    if (voiceNameToUse == null) {
      _showSnack('ไม่พบเสียงอ่านภาษาไทยในเครื่องของคุณ');
    }

    setState(() => _busy = true);

    try {
      await _tts.stop();
      await _tts.setLanguage('th-TH');
      await _tts.setSpeechRate(_speechRate);
      await _tts.setPitch(_pitch);

      // ถ้าหา voice name เจอ ก็ให้ setVoice
      if (voiceNameToUse != null) {
        await _tts.setVoice({'name': voiceNameToUse, 'locale': 'th-TH'});
      }

      await _tts.speak(txt);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _showSnack('พูดไม่สำเร็จ: $e');
      }
    }
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));

  Future<void> _toPrev() async {
    if (_idx == 0) return;
    await _tts.stop();
    setState(() {
      _idx--;
      _busy = false;
      _spoken = false;
    });
  }

  Future<void> _toNext() async {
    if (_idx < widget.steps.length - 1) {
      await _tts.stop();
      setState(() {
        _idx++;
        _busy = false;
        _spoken = false;
      });
    } else {
      await _tts.stop();
      if (mounted) Navigator.pop(context);
    }
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return FutureBuilder(
            future: _ttsInitializationFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()));
              }

              return StatefulBuilder(
                builder: (BuildContext context, StateSetter setModalState) {
                  return Container(
                    padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ตั้งค่าเสียงอ่าน',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),

                        Text('เสียงพูด',
                            style: TextStyle(color: Colors.grey[700])),
                        const SizedBox(height: 8),
                        // ★★★ กลับมาใช้ปุ่มเลือก ชาย/หญิง ★★★
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                                value: true,
                                label: Text('หญิง'),
                                icon: Icon(Icons.female)),
                            ButtonSegment(
                                value: false,
                                label: Text('ชาย'),
                                icon: Icon(Icons.male)),
                          ],
                          selected: {_isFemaleVoice},
                          onSelectionChanged: (newSelection) {
                            setModalState(() => setState(
                                () => _isFemaleVoice = newSelection.first));
                          },
                        ),
                        const SizedBox(height: 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('ความเร็วในการอ่าน:',
                                style: TextStyle(color: Colors.grey[700])),
                            Text('${(_speechRate * 2).toStringAsFixed(1)}x',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Slider(
                          value: _speechRate,
                          min: 0.1,
                          max: 1.0,
                          divisions: 9,
                          label: '${(_speechRate * 2).toStringAsFixed(1)}x',
                          onChanged: (value) => setModalState(
                              () => setState(() => _speechRate = value)),
                        ),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('โทนเสียง (Pitch):',
                                style: TextStyle(color: Colors.grey[700])),
                            Text(_pitch.toStringAsFixed(1),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Slider(
                          value: _pitch,
                          min: 0.5,
                          max: 2.0,
                          divisions: 15,
                          label: _pitch.toStringAsFixed(1),
                          onChanged: (value) => setModalState(
                              () => setState(() => _pitch = value)),
                        ),
                      ],
                    ),
                  );
                },
              );
            });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... ส่วน build UI หลักที่เหลือเหมือนเดิมทั้งหมด ไม่มีการเปลี่ยนแปลง ...
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    double clamp(double v, double min, double max) =>
        v < min ? min : (v > max ? max : v);

    final imgH = clamp(h * 0.34, 200, 340);
    final descF = clamp(w * 0.05, 16, 22);
    final btnH = clamp(h * 0.085, 56, 72);
    final btnFont = clamp(w * 0.055, 18, 24);
    final btnIcon = btnH * 0.6;
    final navIcon = clamp(w * 0.1, 32, 48);
    final navFont = clamp(w * 0.04, 14, 18);
    final pagePad = clamp(w * 0.08, 24, 40);

    final step = widget.steps[_idx];
    final imgUrl = (widget.imageUrls.length > _idx &&
            widget.imageUrls[_idx].trim().isNotEmpty)
        ? widget.imageUrls[_idx]
        : (widget.imageUrls.isNotEmpty ? widget.imageUrls.first : null);

    final isFirst = _idx == 0;
    final isLast = _idx == widget.steps.length - 1;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF9B05),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () async {
            await _tts.stop();
            if (mounted) Navigator.pop(context);
          },
        ),
        title: Text('ขั้นตอนที่ ${_idx + 1}',
            style: const TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'ตั้งค่าเสียง',
            onPressed: _showSettingsSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: imgH,
            width: double.infinity,
            child: imgUrl != null
                ? Image.network(imgUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Image.asset(
                        'assets/images/default_recipe.png',
                        fit: BoxFit.cover))
                : Image.asset('assets/images/default_recipe.png',
                    fit: BoxFit.cover),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(pagePad * 0.8),
              child: Text(
                step.description,
                style: TextStyle(
                  fontSize: descF,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF3D3D3D),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: pagePad),
            child: SizedBox(
              width: double.infinity,
              height: btnH,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _speak,
                icon: Icon(
                  _busy
                      ? Icons.volume_up
                      : (_spoken
                          ? Icons.replay_circle_filled
                          : Icons.play_circle_fill_rounded),
                  size: btnIcon,
                  color: Colors.white,
                ),
                label: Text(
                  _busy ? 'กำลังพูด...' : (_spoken ? 'เล่นซ้ำ' : 'ฟังเสียง'),
                  style:
                      TextStyle(fontSize: btnFont, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9B05),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(btnH / 2)),
                ),
              ),
            ),
          ),
          SizedBox(height: pagePad * 0.5),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: pagePad, vertical: pagePad * 0.25),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavButton(
                    enabled: !isFirst,
                    icon: 'assets/icons/play_previous.svg',
                    label: 'กลับ',
                    iconSize: navIcon,
                    fontSize: navFont,
                    onTap: _toPrev,
                  ),
                  _NavButton(
                    enabled: true,
                    icon: 'assets/icons/play_next.svg',
                    label: isLast ? 'เสร็จสิ้น' : 'ถัดไป',
                    iconSize: navIcon,
                    fontSize: navFont,
                    onTap: _toNext,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/*───────────── widget ย่อย ─────────────*/
class _NavButton extends StatelessWidget {
  final bool enabled;
  final String icon;
  final String label;
  final VoidCallback onTap;
  final double iconSize;
  final double fontSize;
  const _NavButton({
    required this.enabled,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.iconSize,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: SvgPicture.asset(icon,
                width: iconSize,
                height: iconSize,
                colorFilter:
                    const ColorFilter.mode(Color(0xFF555555), BlendMode.srcIn)),
            onPressed: enabled ? onTap : null,
          ),
          Text(label,
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF555555))),
        ],
      ),
    );
  }
}
