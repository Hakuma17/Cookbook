// lib/screens/step_detail_screen.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../utils/safe_image.dart';
// import 'package:flutter/services.dart'; // ไม่ได้ใช้แล้ว ลบเพื่อลดลินต์
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_tts/flutter_tts.dart';

// ★ แนะนำให้เพิ่มแพ็กเกจนี้ใน pubspec (ดูบรรทัดบนสุด)
//   ถ้ายังไม่เพิ่ม จะ build ไม่ผ่าน ให้คอมเมนต์ import ด้านล่างชั่วคราว
import 'package:android_intent_plus/android_intent.dart';

// ★ ข้อ 2: จำค่าตั้งของผู้ใช้
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recipe_step.dart';

class StepDetailScreen extends StatefulWidget {
  final List<RecipeStep> steps;
  final List<String> imageUrls;
  final int initialIndex;

  const StepDetailScreen({
    super.key,
    required this.steps,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<StepDetailScreen> createState() => _StepDetailScreenState();
}

class _StepDetailScreenState extends State<StepDetailScreen> {
  // ─────────────── TTS & State ───────────────
  late final FlutterTts _tts;
  late int _currentIndex;
  bool _isSpeaking = false;
  bool _hasSpoken = false;

  // ─────────────── Voice Settings ───────────────
  bool _isFemaleVoice = true; // true = female, false = male
  List<Map> _thaiVoices = [];
  double _speechRate = 0.5; // 0.1–1.0 (flutter_tts)
  double _pitch = 1.0; // 0.5–2.0

  // ★ NEW: Availability flags
  bool _hasThai = false; // มีเสียงไทยใดๆ หรือไม่
  int _thaiFemaleCount = 0; // เจอเสียงไทยหญิงกี่ตัว
  int _thaiMaleCount = 0; // เจอเสียงไทยชายกี่ตัว
  bool get _supportsGenderToggle =>
      _thaiFemaleCount > 0 && _thaiMaleCount > 0; // ซ่อน/โชว์ปุ่มเลือกเพศ

  // ★ ข้อ 2: prefs
  SharedPreferences? _prefs;

  // ★ ข้อ 7: อ่านทีละประโยค (คงกลไกไว้ แม้ UI ไม่ไฮไลต์แล้ว)
  List<String> _sentences = [];
  int _currentSentenceIndex = -1;
  int _speakEpoch = 0; // ป้องกัน completion เก่ามาแทรกหลังเปลี่ยนสเต็ป

  // ★ NEW: เวลาหน่วงหลังแต่ละก้อนคำพูด (สอดคล้องกับ _sentences)
  List<int> _sentencePauseMs = [];

  // ★ พอสพื้นฐาน
  static const int _spacePauseMs = 120; // เว้นจังหวะเมื่อเจอช่องว่างธรรมดา
  static const int _sentenceBasePauseMs =
      180; // เว้นจังหวะเมื่อจบประโยค (ไม่มี \n)

  // Initialization
  late Future<void> _ttsInitFuture;

  @override
  void initState() {
    super.initState();

    // กัน steps ว่าง: แจ้งเตือนแล้วปิดหน้า
    if (widget.steps.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (_) => const AlertDialog(
            title: Text('ไม่มีขั้นตอน'),
            content: Text('เมนูนี้ยังไม่มีขั้นตอนวิธีทำ'),
          ),
        );
        if (mounted) Navigator.pop(context);
      });
      _currentIndex = 0;
    } else {
      _currentIndex = widget.initialIndex.clamp(0, widget.steps.length - 1);
    }

    _ttsInitFuture = _initializeTts();
  }

  Future<void> _initializeTts() async {
    _tts = FlutterTts();

    // ★ ข้อ 2: โหลด prefs
    _prefs = await SharedPreferences.getInstance();
    _speechRate = _prefs?.getDouble('tts_rate') ?? 0.5;
    _pitch = _prefs?.getDouble('tts_pitch') ?? 1.0;
    _isFemaleVoice = _prefs?.getBool('tts_female') ?? true;

    // ขอให้ await การอ่านจนจบ เพื่อให้ completion handler ทำงานคาดเดาได้
    await _tts.awaitSpeakCompletion(true);

    // ★ ข้อ 11: ตั้งค่าเสียงระบบ (iOS duck others)
    try {
      if (Platform.isIOS) {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.ambient,
          [IosTextToSpeechAudioCategoryOptions.duckOthers],
        );
      }
    } catch (_) {}

    // ★ ข้อ 1: เลือก Google TTS ถ้ามี (Android)
    await _ensureEngine();

    // Handlers เพื่อ sync UI state + ★ queue sentence-by-sentence
    _tts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });
    _tts.setCompletionHandler(() async {
      // ★ เมื่อพูดจบ 1 ก้อน → พักตามชนิดช่องว่าง/ย่อหน้า แล้วคิวก้อนถัดไป
      if (!mounted) return;
      if (!_isSpeaking) return; // ถูก cancel/stop
      final int epoch = _speakEpoch;
      final int prev = _currentSentenceIndex;

      if (_currentSentenceIndex >= 0 &&
          _currentSentenceIndex < _sentences.length - 1) {
        // เว้นจังหวะตามที่คิวกำหนด (จากการแตกตามช่องว่าง/บรรทัด)
        final pauseMs = (prev >= 0 && prev < _sentencePauseMs.length)
            ? _sentencePauseMs[prev]
            : 0;
        if (pauseMs > 0) {
          await Future.delayed(Duration(milliseconds: pauseMs));
          if (!mounted || epoch != _speakEpoch) return; // session เปลี่ยน
        }

        _currentSentenceIndex++;
        setState(() {}); // (ไม่มีไฮไลต์แล้ว แต่คง state ไว้)
        await _speakSentenceAt(_currentSentenceIndex, epoch);
      } else {
        // จบทั้งหมด
        setState(() {
          _isSpeaking = false;
          _currentSentenceIndex = -1;
        });
      }
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setErrorHandler((msg) {
      if (mounted) {
        setState(() => _isSpeaking = false);
        _showSnack('TTS ผิดพลาด: $msg');
      }
    });

    // โหลด voices ภาษาไทย (ถ้ามี) + คัดเพศ
    try {
      final voicesRaw = await _tts.getVoices; // dynamic
      final voicesList = (voicesRaw as List).cast<Map>();
      _thaiVoices = voicesList.where((v) {
        final loc = (v['locale'] ?? '').toString().toLowerCase();
        return loc.startsWith('th'); // เช่น 'th-TH'
      }).toList();

      _hasThai = _thaiVoices.isNotEmpty;
      _thaiFemaleCount = _thaiVoices.where(_isFemaleVoiceMap).length;
      _thaiMaleCount = _thaiVoices.where(_isMaleVoiceMap).length;

      if (!_supportsGenderToggle) {
        if (_thaiFemaleCount > 0 && _thaiMaleCount == 0) {
          _isFemaleVoice = true;
        } else if (_thaiMaleCount > 0 && _thaiFemaleCount == 0) {
          _isFemaleVoice = false;
        }
      }
    } catch (e) {
      _thaiVoices = [];
      _hasThai = false;
      _thaiFemaleCount = 0;
      _thaiMaleCount = 0;
      _showSnack('ไม่สามารถโหลดเสียงภาษาไทยจากอุปกรณ์ได้');
    }
  }

  // ★ ข้อ 1: ใช้ Google TTS ถ้ามี (best-effort)
  Future<void> _ensureEngine() async {
    if (!Platform.isAndroid) return;
    try {
      await _tts.setEngine('com.google.android.tts');
    } catch (_) {}
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  // ────────────────────────── Actions ──────────────────────────

  Future<void> _speakCurrentStep() async {
    await _ttsInitFuture;

    // toggle stop
    if (_isSpeaking) {
      _speakEpoch++; // invalidates any queued continuation
      await _tts.stop();
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _currentSentenceIndex = -1;
        });
      }
      return;
    }

    if (widget.steps.isEmpty ||
        _currentIndex < 0 ||
        _currentIndex >= widget.steps.length) {
      _showSnack('ไม่มีข้อความสำหรับอ่าน');
      return;
    }

    // เตรียมคิวประโยคจาก “ต้นฉบับ”
    final raw = widget.steps[_currentIndex].description.trim();
    if (raw.isEmpty) {
      _showSnack('ไม่มีข้อความสำหรับอ่าน');
      return;
    }

    // ★ NEW: สร้างคิวตามช่องว่าง/เลข/\n (แทนที่ _splitSentences เดิม)
    _prepareSpeechQueue(raw);
    if (_sentences.isEmpty) {
      _sentences = [raw];
      _sentencePauseMs = [0];
    }

    // เริ่ม session ใหม่
    _speakEpoch++;
    _currentSentenceIndex = 0;
    setState(() {
      _isSpeaking = true;
      _hasSpoken = true;
    });

    // ★ ข้อ 3: Pre-flight
    await _tts.stop();
    await _ensureEngine();
    await _tts.setLanguage(_hasThai ? 'th-TH' : 'en-US');
    await _tts.setPitch(_pitch);

    if (!_hasThai) {
      _showSnack('ไม่พบเสียงภาษาไทยในอุปกรณ์ — จะลองอ่านด้วยเสียงสากล');
    }

    await _speakSentenceAt(0, _speakEpoch);
  }

  // ★ ข้อ 7 + 9 + 10 + 4
  Future<void> _speakSentenceAt(int i, int epoch) async {
    if (!mounted) return;
    if (epoch != _speakEpoch) return;
    if (i < 0 || i >= _sentences.length) return;

    final cleaned = _sanitize(_sentences[i]);
    final normalized = _normalizeNumbersAndUnits(cleaned);

    final rate = _autoRate(normalized);
    await _tts.setSpeechRate(rate);

    if (_hasThai && _thaiVoices.isNotEmpty) {
      final voice = _pickThaiVoice(_thaiVoices, female: _isFemaleVoice);
      try {
        await _tts.setVoice({
          'name': voice['name'],
          'locale': (voice['locale'] ?? 'th-TH'),
        });
      } catch (_) {}
    }

    await _tts.speak(normalized);
  }

  Map _pickThaiVoice(List<Map> voices, {required bool female}) {
    final preferred =
        voices.where(female ? _isFemaleVoiceMap : _isMaleVoiceMap).toList();
    return (preferred.isNotEmpty ? preferred : voices).first;
  }

  bool _isFemaleVoiceMap(Map v) {
    final name = (v['name'] ?? '').toString().toLowerCase();
    return name.contains('female') ||
        name.contains('f_') ||
        name.contains('#female') ||
        name.contains('-thf') ||
        name.contains('sfg') ||
        name.contains('thc');
  }

  bool _isMaleVoiceMap(Map v) {
    final name = (v['name'] ?? '').toString().toLowerCase();
    return name.contains('male') ||
        name.contains('m_') ||
        name.contains('#male') ||
        name.contains('-thm') ||
        name.contains('smd') ||
        name.contains('thd');
  }

  Future<void> _goToStep(int index) async {
    if (index < 0) return;
    if (index >= widget.steps.length) {
      await _tts.stop();
      if (mounted) Navigator.pop(context);
      return;
    }

    final wasSpeaking = _isSpeaking;
    final movingForward =
        index > _currentIndex; // ★ ใช้รู้ว่าเป็น “ถัดไป” หรือไม่

    _speakEpoch++; // invalidate session
    await _tts.stop();
    if (!mounted) return;

    setState(() {
      _currentIndex = index;
      _isSpeaking = false;
      _hasSpoken = false;
      _currentSentenceIndex = -1;
      _sentences = [];
      _sentencePauseMs = [];
    });

    // ★ ใหม่: ถ้าเป็นการกด “ถัดไป” และ index > 0 → อ่านทันที
    // (ยังคงพฤติกรรมเดิม: ถ้าเดิมกำลังอ่านอยู่ ก็อ่านต่อทันทีอยู่แล้ว)
    if (movingForward && index > 0 || wasSpeaking) {
      await Future.delayed(const Duration(milliseconds: 80));
      if (mounted) await _speakCurrentStep();
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return FutureBuilder(
          future: _ttsInitFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                return _buildSettingsContent(context, setModalState);
              },
            );
          },
        );
      },
    );
  }

  // ────────────────────────── Build UI ──────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final TextStyle? medium =
        textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w400);

    if (widget.steps.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('ขั้นตอน', style: medium)),
        body: const SizedBox.shrink(),
      );
    }

    final currentStep = widget.steps[_currentIndex];

    final imageUrl = (widget.imageUrls.length > _currentIndex &&
            widget.imageUrls[_currentIndex].trim().isNotEmpty)
        ? widget.imageUrls[_currentIndex]
        : (widget.imageUrls.isNotEmpty ? widget.imageUrls.first : null);

    final isFirstStep = _currentIndex == 0;
    final isLastStep = _currentIndex == widget.steps.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text('ขั้นตอนที่ ${_currentIndex + 1}', style: medium),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'ตั้งค่าเสียง',
            onPressed: _showSettingsSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Image Section ---
          SizedBox(
            height: 250,
            width: double.infinity,
            child: imageUrl != null
                ? SafeImage(url: imageUrl, fit: BoxFit.cover)
                : _buildPlaceholderImage(),
          ),

          // --- Description Section ---
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              // ★ ไม่มีไฮไลต์แล้ว → ข้อความล้วน
              child: _buildHighlightedDescription(
                currentStep.description,
                textStyle: medium?.copyWith(height: 1.5),
              ),
            ),
          ),

          // --- Controls Section ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Semantics(
              button: true,
              label: _isSpeaking ? 'หยุดอ่าน' : 'อ่านขั้นตอน',
              child: ElevatedButton.icon(
                onPressed: _speakCurrentStep,
                icon: Icon(_isSpeaking
                    ? Icons.stop_circle_outlined
                    : Icons.play_circle_outline),
                label: Text(
                  _isSpeaking
                      ? 'กำลังอ่าน...'
                      : (_hasSpoken ? 'อ่านซ้ำ' : 'ฟังเสียง'),
                  style: medium,
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Navigation Section ---
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavButton(
                    enabled: !isFirstStep,
                    iconAsset: 'assets/icons/play_previous.svg',
                    label: 'กลับ',
                    onTap: () => _goToStep(_currentIndex - 1),
                  ),
                  _NavButton(
                    enabled: true,
                    iconAsset: 'assets/icons/play_next.svg',
                    label: isLastStep ? 'เสร็จสิ้น' : 'ถัดไป',
                    onTap: () => _goToStep(_currentIndex + 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helpers
  Widget _buildPlaceholderImage() {
    return Image.asset('assets/images/default_recipe.png', fit: BoxFit.cover);
  }

  Widget _buildSettingsContent(
      BuildContext context, StateSetter setModalState) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final TextStyle? medium =
        textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w400);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ตั้งค่าเสียงอ่าน', style: medium),
          const SizedBox(height: 16),

          //  ซ่อน/โชว์ตัวเลือกเพศตามความพร้อมของเสียงไทย (ไม่มีข้อความสรุปแล้ว)
          if (_supportsGenderToggle) ...[
            Text('เสียงพูด', style: medium),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: true, label: Text('หญิง'), icon: Icon(Icons.female)),
                ButtonSegment(
                    value: false, label: Text('ชาย'), icon: Icon(Icons.male)),
              ],
              selected: {_isFemaleVoice},
              onSelectionChanged: (sel) async {
                setModalState(() => _isFemaleVoice = sel.first);
                setState(() {}); // sync state หลักให้ทันที
                // ★ ข้อ 2: บันทึกค่า
                await _prefs?.setBool('tts_female', _isFemaleVoice);
              },
            ),
            const SizedBox(height: 24),
          ] else ...[
            // คำแนะนำไม่มีเสียงไทยครบ + ปุ่มเปิด Settings (Android)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                Platform.isAndroid
                    ? 'อุปกรณ์นี้ยังไม่มีชุดเสียงไทยครบ (หญิง/ชาย). คุณสามารถติดตั้งเพิ่มในหน้าการตั้งค่า TTS ของระบบได้'
                    : 'อุปกรณ์นี้ยังไม่มีชุดเสียงไทยครบ. ไปที่ Settings → Accessibility → Spoken Content → Voices เพื่อติดตั้ง',
                style: textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 12),
            if (Platform.isAndroid)
              OutlinedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('ติดตั้ง/อัปเดตเสียงไทย'),
                onPressed: _openAndroidTtsSettings,
              ),
            const SizedBox(height: 16),
          ],

          // ความเร็ว
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ความเร็วในการอ่าน:', style: medium),
              Text('${(_speechRate * 2).toStringAsFixed(1)}x', style: medium),
            ],
          ),
          Slider(
            value: _speechRate,
            min: 0.1,
            max: 1.0,
            divisions: 9,
            label: '${(_speechRate * 2).toStringAsFixed(1)}x',
            onChanged: (v) async {
              setModalState(() => _speechRate = v);
              setState(() {}); // sync
              await _prefs?.setDouble('tts_rate', _speechRate);
            },
          ),

          // Pitch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ระดับเสียง (Pitch):', style: medium),
              Text(_pitch.toStringAsFixed(1), style: medium),
            ],
          ),
          Slider(
            value: _pitch,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            label: _pitch.toStringAsFixed(1),
            onChanged: (v) async {
              setModalState(() => _pitch = v);
              setState(() {}); // sync
              await _prefs?.setDouble('tts_pitch', _pitch);
            },
          ),
        ],
      ),
    );
  }

  // ★ เปิดหน้า TTS Settings ของ Android (ติดตั้ง/อัปเดตเสียง)
  Future<void> _openAndroidTtsSettings() async {
    if (!Platform.isAndroid) return;
    try {
      final intent = AndroidIntent(action: 'android.settings.TTS_SETTINGS');
      await intent.launch();
    } catch (e) {
      _showSnack('ไม่สามารถเปิดหน้าตั้งค่า TTS ได้: $e');
    }
  }

  // ────────────────────────── ข้อ 7: (UI ไม่มีไฮไลต์แล้ว) ──────────────────
  Widget _buildHighlightedDescription(String raw, {TextStyle? textStyle}) {
    // ★ เปลี่ยนให้แสดงข้อความล้วน ไม่มีไฮไลต์
    return Text(raw, style: textStyle);
  }

  // ignore: unused_element
  List<String> _splitSentences(String text) {
    final pattern = RegExp(r'([^.!?ๆฯ]+[.!?ๆฯ]*)', multiLine: true);
    final matches = pattern.allMatches(text);
    final result = matches
        .map((m) => m.group(0)!.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (result.isEmpty) return [text];
    return result;
  }

  // ────────────────────────── ข้อ 9: Smart rate ──────────────────────────
  double _autoRate(String s) {
    final wc = s.trim().split(RegExp(r'\s+')).length;
    if (wc < 10) return (_speechRate + 0.1).clamp(0.1, 1.0);
    if (wc > 40) return (_speechRate - 0.1).clamp(0.1, 1.0);
    return _speechRate;
  }

  // ────────────────────────── ข้อ 4 + 10: Clean & Normalize ─────────────────
  String _sanitize(String s) {
    var t = s;
    t = t.replaceAll(RegExp(r'\(.*?\)'), ''); // ตัดข้อความในวงเล็บ
    t = t.replaceAll(
        RegExp(r'[\u{1F000}-\u{1FAFF}]', unicode: true), ''); // อีโมจิ
    t = t.replaceAll(RegExp(r'\s+'), ' '); // ยุบช่องว่าง
    return t.trim();
  }

  String _normalizeNumbersAndUnits(String s) {
    var t = s;

    // เศษส่วนยอดนิยม
    t = t.replaceAllMapped(RegExp(r'\b1/2\b'), (_) => 'หนึ่งส่วนสอง');
    t = t.replaceAllMapped(RegExp(r'\b1/3\b'), (_) => 'หนึ่งส่วนสาม');
    t = t.replaceAllMapped(RegExp(r'\b2/3\b'), (_) => 'สองส่วนสาม');
    t = t.replaceAllMapped(RegExp(r'\b1/4\b'), (_) => 'หนึ่งส่วนสี่');
    t = t.replaceAllMapped(RegExp(r'\b3/4\b'), (_) => 'สามส่วนสี่');

    // เศษส่วนทั่วไป x/y → x ส่วน y
    t = t.replaceAllMapped(RegExp(r'\b(\d+)\s*/\s*(\d+)\b'), (m) {
      return '${m[1]} ส่วน ${m[2]}';
    });

    // หน่วยทั่วไป
    final unitMap = <RegExp, String>{
      RegExp(r'°\s*C', caseSensitive: false): 'องศาเซลเซียส',
      RegExp(r'°\s*F', caseSensitive: false): 'องศาฟาเรนไฮต์',
      RegExp(r'\bkg\b', caseSensitive: false): 'กิโลกรัม',
      RegExp(r'\bg\b', caseSensitive: false): 'กรัม',
      RegExp(r'\bl\b', caseSensitive: false): 'ลิตร',
      RegExp(r'\bml\b', caseSensitive: false): 'มิลลิลิตร',
      RegExp(r'\btbsp\b', caseSensitive: false): 'ช้อนโต๊ะ',
      RegExp(r'\btsp\b', caseSensitive: false): 'ช้อนชา',
    };
    unitMap.forEach((re, thai) {
      t = t.replaceAll(re, thai);
    });

    return t;
  }

  // ────────────────────────── ★ NEW: คิวอ่านตามช่องว่าง/เลข/\n ─────────────
  /// สร้างคิวอ่านจาก raw
  /// - แตกตาม \n (ถ้ามี) → เติม pause 350/650ms ตามขึ้นบรรทัด/ย่อหน้า
  /// - แตกเป็นประโยค (ไทย/สากล) ภายในบรรทัด
  /// - แตกเป็น "phrase" ตามช่องว่าง แต่…
  ///   • ถ้าช่องว่างนั้นติด "ตัวเลข" ทั้งซ้ายหรือขวา → ไม่แบ่ง/ไม่พอส (อ่านต่อเนื่อง)
  /// - เติมไมโครพอส `_SPACE_PAUSE_MS` หลัง phrase ภายในบรรทัด
  /// - เติม `_SENTENCE_BASE_PAUSE_MS` เมื่อจบประโยค
  void _prepareSpeechQueue(String raw) {
    _sentences = [];
    _sentencePauseMs = [];

    // แยกตาม \n (นับจำนวน \n เพื่อตัดสินชนิด pause)
    final nlRegex = RegExp(r'\n+');
    final lines = <String>[];
    final nlCounts = <int>[];

    int last = 0;
    for (final m in nlRegex.allMatches(raw)) {
      final seg = raw.substring(last, m.start).trim();
      if (seg.isNotEmpty) {
        lines.add(seg);
        nlCounts.add(m.group(0)!.length);
      } else {
        if (nlCounts.isNotEmpty) {
          nlCounts[nlCounts.length - 1] += m.group(0)!.length;
        }
      }
      last = m.end;
    }
    final tail = raw.substring(last).trim();
    if (tail.isNotEmpty) {
      lines.add(tail);
      nlCounts.add(0);
    }

    // ถ้าไม่มี \n เลย ให้ถือว่าเป็น 1 บรรทัด
    if (lines.isEmpty) {
      lines.add(raw);
      nlCounts.add(0);
    }

    for (int li = 0; li < lines.length; li++) {
      final line = lines[li];
      // final nls = nlCounts[li];

      // แตกประโยคภายในบรรทัด
      final inline = _splitInlineSentences(line);

      for (int si = 0; si < inline.length; si++) {
        final sentence = inline[si];

        // แตกเป็น phrase ตามช่องว่าง โดย "เคารพตัวเลข" (เลขไม่ทำให้หยุด)
        final phrases = _splitBySpacesRespectNumbers(sentence);

        for (int pi = 0; pi < phrases.length; pi++) {
          final phrase = phrases[pi];
          _sentences.add(phrase);

          int pause = 0;

          final isLastPhraseInSentence = (pi == phrases.length - 1);
          // final isLastSentenceInLine = (si == inline.length - 1);

          // phrase ถัดไปภายในบรรทัด → ไมโครพอส
          if (!isLastPhraseInSentence) {
            pause += _spacePauseMs;
          }

          // จบประโยค → พอสพื้นฐาน
          if (isLastPhraseInSentence) {
            pause += _sentenceBasePauseMs;
          }

          // จบบรรทัด/ย่อหน้า → พอสเพิ่ม (350/650)
          // if (isLastPhraseInSentence && isLastSentenceInLine) {
          //   pause += _newlinePause(nls);
          // }

          _sentencePauseMs.add(pause);
        }
      }
    }
  }

  /// แตกข้อความเป็น phrase ตามช่องว่าง โดย "ไม่แบ่ง" ที่ติดตัวเลข
  ///   เช่น "... น้ำมัน 1 ช้อนโต๊ะ ..." → ทั้ง "น้ำมัน 1 ช้อนโต๊ะ" จะอยู่ก้อนเดียว
  List<String> _splitBySpacesRespectNumbers(String text) {
    final toks = text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (toks.length <= 1) return [text.trim()];

    bool hasDigit(String t) => RegExp(r'\d').hasMatch(t);

    final chunks = <String>[];
    var current = toks.first;

    for (int i = 1; i < toks.length; i++) {
      final prev = toks[i - 1];
      final cur = toks[i];

      final joinBecauseNumberBoundary = hasDigit(prev) || hasDigit(cur);

      if (joinBecauseNumberBoundary) {
        // ไม่แยก: ครอบกลุ่มเลขกับคำข้างเคียงให้ติดกัน
        current += ' $cur';
      } else {
        // แยก phrase ปกติ (จะมีไมโครพอสภายหลัง)
        chunks.add(current);
        current = cur;
      }
    }
    chunks.add(current);

    return chunks.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  /// แตก "ประโยค" ภายในบรรทัด (ไทย/สากล)
  List<String> _splitInlineSentences(String text) {
    final pattern = RegExp(r'([^.!?ๆฯ]+[.!?ๆฯ]*)', multiLine: true);
    final matches = pattern.allMatches(text);
    final result = matches
        .map((m) => m.group(0)!.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (result.isEmpty) return [text];
    return result;
  }

  /// ระยะพักเมื่อขึ้นบรรทัดใหม่/ย่อหน้า จากจำนวน \n ต่อเนื่อง
  // ignore: unused_element
  int _newlinePause(int nlCount) {
    if (nlCount >= 2) return 650; // ย่อหน้าใหม่
    if (nlCount == 1) return 350; // ขึ้นบรรทัด
    return 0;
  }
}

//// ปุ่มนำทาง Previous/Next
class _NavButton extends StatelessWidget {
  final bool enabled;
  final String iconAsset;
  final String label;
  final VoidCallback onTap;

  const _NavButton({
    required this.enabled,
    required this.iconAsset,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final TextStyle? medium =
        theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w400);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                iconAsset,
                width: 40,
                colorFilter: ColorFilter.mode(
                  theme.colorScheme.onSurface,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: medium),
            ],
          ),
        ),
      ),
    );
  }
}
