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
  bool _isFemaleVoice = true; // true for female, false for male
  List<Map> _thaiVoices = [];
  double _speechRate = 0.5;
  double _pitch = 1.0;

  // Future for TTS initialization
  late Future<void> _ttsInitFuture;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.steps.length - 1);
    _ttsInitFuture = _initializeTts();
  }

  Future<void> _initializeTts() async {
    _tts = FlutterTts();
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });

    try {
      final voices = List<Map>.from(await _tts.getVoices as List);
      if (mounted) {
        _thaiVoices = voices.where((v) => v['locale'] == 'th-TH').toList();
      }
    } catch (e) {
      debugPrint("Error initializing TTS voices: $e");
      if (mounted) _showSnack('ไม่สามารถโหลดเสียงอ่านได้');
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  /* ────────────────────────── Actions ────────────────────────── */

  Future<void> _speakCurrentStep() async {
    if (_isSpeaking) {
      await _tts.stop();
      setState(() => _isSpeaking = false);
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

      if (_thaiVoices.isNotEmpty) {
        final preferredVoice = _thaiVoices.firstWhere(
          (v) =>
              v['name'].toString().contains(_isFemaleVoice ? '-thc-' : '-thd-'),
          orElse: () => _thaiVoices.first,
        );
        await _tts
            .setVoice({'name': preferredVoice['name'], 'locale': 'th-TH'});
      } else {
        _showSnack('ไม่พบเสียงภาษาไทยในอุปกรณ์');
      }

      await _tts.speak(textToSpeak);
    } catch (e) {
      if (mounted) {
        setState(() => _isSpeaking = false);
        _showSnack('เกิดข้อผิดพลาดในการอ่าน: $e');
      }
    }
  }

  Future<void> _goToStep(int index) async {
    if (index < 0) return;
    if (index >= widget.steps.length) {
      await _tts.stop();
      if (mounted) Navigator.pop(context);
      return;
    }

    await _tts.stop();
    setState(() {
      _currentIndex = index;
      _isSpeaking = false;
      _hasSpoken = false;
    });
  }

  void _showSnack(String msg) {
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

    // ✨ สไตล์ “มีเดียมแต่ไม่หนา” ไว้ใช้ซ้ำ
    final TextStyle? medium =
        textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w400);

    final currentStep = widget.steps[_currentIndex];

    final imageUrl = (widget.imageUrls.length > _currentIndex &&
            widget.imageUrls[_currentIndex].trim().isNotEmpty)
        ? widget.imageUrls[_currentIndex]
        : (widget.imageUrls.isNotEmpty ? widget.imageUrls.first : null);

    final isFirstStep = _currentIndex == 0;
    final isLastStep = _currentIndex == widget.steps.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text('ขั้นตอนที่ ${_currentIndex + 1}', style: medium), // ✨
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
                // ✨ เปลี่ยนเป็น titleMedium (มีเดียม) + ไม่หนา
                style: medium?.copyWith(height: 1.5),
              ),
            ),
          ),

          // --- Controls Section ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ElevatedButton.icon(
              onPressed: _speakCurrentStep,
              icon: Icon(_isSpeaking
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline),
              label: Text(
                _isSpeaking
                    ? 'กำลังอ่าน...'
                    : (_hasSpoken ? 'อ่านซ้ำ' : 'ฟังเสียง'),
                style: medium, // ✨
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
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
        textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w400); // ✨

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✨ หัวข้อใช้มีเดียม ไม่หนา
          Text('ตั้งค่าเสียงอ่าน', style: medium),
          const SizedBox(height: 24),

          Text('เสียงพูด', style: medium), // ✨
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                  value: true, label: Text('หญิง'), icon: Icon(Icons.female)),
              ButtonSegment(
                  value: false, label: Text('ชาย'), icon: Icon(Icons.male)),
            ],
            selected: {_isFemaleVoice},
            onSelectionChanged: (newSelection) {
              setModalState(
                  () => setState(() => _isFemaleVoice = newSelection.first));
            },
          ),
          const SizedBox(height: 24),

          // --- Speech Rate Slider ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ความเร็วในการอ่าน:', style: medium), // ✨
              Text('${(_speechRate * 2).toStringAsFixed(1)}x',
                  style: medium), // ✨
            ],
          ),
          Slider(
            value: _speechRate,
            min: 0.1,
            max: 1.0,
            divisions: 9,
            label: '${(_speechRate * 2).toStringAsFixed(1)}x',
            onChanged: (value) =>
                setModalState(() => setState(() => _speechRate = value)),
          ),

          // --- Pitch Slider ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ระดับเสียง (Pitch):', style: medium), // ✨
              Text(_pitch.toStringAsFixed(1), style: medium), // ✨
            ],
          ),
          Slider(
            value: _pitch,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            label: _pitch.toStringAsFixed(1),
            onChanged: (value) =>
                setModalState(() => setState(() => _pitch = value)),
          ),
        ],
      ),
    );
  }
}

/// Widget สำหรับปุ่ม Previous/Next
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
        theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w400); // ✨

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
                    theme.colorScheme.onSurface, BlendMode.srcIn),
              ),
              const SizedBox(height: 4),
              Text(label, style: medium), // ✨ ใช้มีเดียม ไม่หนา
            ],
          ),
        ),
      ),
    );
  }
}
