// lib/screens/step_detail_screen.dart
//
// 2025-08-10 – hardened TTS + UX polish
// - Guard steps empty → แจ้งเตือนแล้วปิดหน้า
// - รอ _ttsInitFuture เสมอ + awaitSpeakCompletion(true)
// - Handlers: start/completion/cancel/error → sync _isSpeaking
// - Voice selection heuristic (Thai female/male) + fallback
// - Auto-continue: ถ้ากำลังอ่านอยู่แล้วกด “ถัดไป/กลับ” จะอ่านขั้นตอนใหม่ต่อทันที
// - ใช้ textTheme.titleMedium แบบน้ำหนักปกติให้สอดคล้องหน้าที่เหลือ

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
    super.key,
    required this.steps,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<StepDetailScreen> createState() => _StepDetailScreenState();
}

class _StepDetailScreenState extends State<StepDetailScreen> {
  // TTS & State
  late final FlutterTts _tts;
  late int _currentIndex;
  bool _isSpeaking = false;
  bool _hasSpoken = false;

  // Voice Settings
  bool _isFemaleVoice = true; // true = female, false = male
  List<Map> _thaiVoices = [];
  double _speechRate = 0.5; // 0.1–1.0 (flutter_tts)
  double _pitch = 1.0; // 0.5–2.0

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
          builder: (_) => AlertDialog(
            title: const Text('ไม่มีขั้นตอน'),
            content: const Text('เมนูนี้ยังไม่มีขั้นตอนวิธีทำ'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ตกลง'),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context);
      });
      // ค่าเริ่มต้นแบบปลอดภัย ไม่ได้ใช้อยู่ดีเพราะจะ pop ทันที
      _currentIndex = 0;
    } else {
      _currentIndex = widget.initialIndex.clamp(0, widget.steps.length - 1);
    }

    _ttsInitFuture = _initializeTts();
  }

  Future<void> _initializeTts() async {
    _tts = FlutterTts();

    // ขอให้ await การอ่านจนจบ เพื่อให้ completion handler ทำงานคาดเดาได้
    await _tts.awaitSpeakCompletion(true);

    // Handlers เพื่อ sync UI state
    _tts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
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

    // โหลด voices ภาษาไทย (ถ้ามี)
    try {
      final voicesRaw = await _tts.getVoices; // dynamic
      final voicesList = (voicesRaw as List).cast<Map>();
      _thaiVoices = voicesList.where((v) {
        final loc = (v['locale'] ?? '').toString().toLowerCase();
        return loc.startsWith('th'); // 'th-TH' หรือรูปแบบย่อย
      }).toList();
    } catch (e) {
      _thaiVoices = [];
      _showSnack('ไม่สามารถโหลดเสียงภาษาไทยจากอุปกรณ์ได้');
    }
  }

  @override
  void dispose() {
    // หยุดเสียงก่อนออก
    _tts.stop();
    super.dispose();
  }

  /* ────────────────────────── Actions ────────────────────────── */

  Future<void> _speakCurrentStep() async {
    await _ttsInitFuture; // รอให้พร้อมก่อน

    if (_isSpeaking) {
      await _tts.stop();
      if (mounted) setState(() => _isSpeaking = false);
      return;
    }

    // ป้องกันกรณี steps ว่าง (เผื่อโดนเรียกขณะกำลังปิดหน้า)
    if (widget.steps.isEmpty ||
        _currentIndex < 0 ||
        _currentIndex >= widget.steps.length) {
      _showSnack('ไม่มีข้อความสำหรับอ่าน');
      return;
    }

    final textToSpeak = widget.steps[_currentIndex].description.trim();
    if (textToSpeak.isEmpty) {
      _showSnack('ไม่มีข้อความสำหรับอ่าน');
      return;
    }

    setState(() {
      _isSpeaking = true;
      _hasSpoken = true;
    });

    try {
      await _tts.stop();
      await _tts.setLanguage('th-TH');
      await _tts.setSpeechRate(_speechRate);
      await _tts.setPitch(_pitch);

      // เลือกเสียงไทยตามเพศแบบ heuristic + fallback
      if (_thaiVoices.isNotEmpty) {
        final voice = _pickThaiVoice(_thaiVoices, female: _isFemaleVoice);
        await _tts.setVoice({
          'name': voice['name'],
          'locale': (voice['locale'] ?? 'th-TH'),
        });
      } else {
        // ไม่มี voices ไทย → ให้ระบบพยายามอ่านด้วย language อย่างเดียว
      }

      await _tts.speak(textToSpeak);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
      _showSnack('เกิดข้อผิดพลาดในการอ่าน: $e');
    }
  }

  /// เลือกเสียงไทยตามเพศแบบหยาบ ๆ ให้ครอบคลุมหลายยี่ห้อ/แพลตฟอร์ม
  Map _pickThaiVoice(List<Map> voices, {required bool female}) {
    bool isFemale(Map v) {
      final name = (v['name'] ?? '').toString().toLowerCase();
      // keyword ที่พบได้บ่อยใน Android/iOS/Google TTS
      return name.contains('female') ||
          name.contains('f_') ||
          name.contains('#female') ||
          name.contains('-thf') ||
          name.contains('sfg') || // ชุดโค้ดเพศหญิงในบางดีไวซ์
          name.contains('thc'); // บางโค้ดที่มัก map ไปหญิง
    }

    bool isMale(Map v) {
      final name = (v['name'] ?? '').toString().toLowerCase();
      return name.contains('male') ||
          name.contains('m_') ||
          name.contains('#male') ||
          name.contains('-thm') ||
          name.contains('smd') || // เพศชายในบางดีไวซ์
          name.contains('thd');
    }

    final preferred = voices.where(female ? isFemale : isMale).toList();
    return (preferred.isNotEmpty ? preferred : voices).first;
  }

  Future<void> _goToStep(int index) async {
    if (index < 0) {
      // ไม่มี “ก่อนหน้า” แล้ว
      return;
    }
    if (index >= widget.steps.length) {
      // จบขั้นตอน → ปิดหน้า
      await _tts.stop();
      if (mounted) Navigator.pop(context);
      return;
    }

    final wasSpeaking = _isSpeaking;

    await _tts.stop();
    if (!mounted) return;

    setState(() {
      _currentIndex = index;
      _isSpeaking = false;
      // อย่าล้าง _hasSpoken เพื่อให้ปุ่มยังขึ้น “อ่านซ้ำ” หลังเคยกดมาแล้ว
    });

    // Auto-continue: ถ้ากำลังอ่านอยู่ แล้วผู้ใช้กด “ถัดไป/กลับ” ให้เริ่มอ่านขั้นตอนใหม่ทันที
    if (wasSpeaking) {
      // หน่วงสั้น ๆ ให้ UI เปลี่ยน index แล้วค่อยสั่งอ่าน
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

  /* ────────────────────────── Build UI ────────────────────────── */

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final TextStyle? medium =
        textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w400);

    // ถ้ากำลังจะปิดหน้าเพราะ steps ว่าง ให้โชว์โครงนิดนึง
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
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                  )
                : _buildPlaceholderImage(),
          ),

          // --- Description Section ---
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                currentStep.description,
                style: medium?.copyWith(height: 1.5),
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
          const SizedBox(height: 24),

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
            onSelectionChanged: (sel) {
              setModalState(() => _isFemaleVoice = sel.first);
              setState(() {}); // sync state หลักให้ทันที
            },
          ),
          const SizedBox(height: 24),

          // Speech Rate
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
            onChanged: (v) {
              setModalState(() => _speechRate = v);
              setState(() {}); // sync
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
            onChanged: (v) {
              setModalState(() => _pitch = v);
              setState(() {}); // sync
            },
          ),
        ],
      ),
    );
  }
}

/// ปุ่มนำทาง Previous/Next
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
