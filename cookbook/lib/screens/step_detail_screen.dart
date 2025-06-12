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
  _StepDetailScreenState createState() => _StepDetailScreenState();
}

class _StepDetailScreenState extends State<StepDetailScreen> {
  late final FlutterTts _tts;
  late int _currentIndex;
  bool _hasSpoken = false;
  bool _isSpeaking = false;
  bool _isFemale = true;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _currentIndex = widget.initialIndex.clamp(0, widget.steps.length - 1);
    _isFemale = DateTime.now().millisecond % 2 == 0;

    _tts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
        _hasSpoken = true;
      });
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _playVoice() async {
    final text = widget.steps[_currentIndex].description;

    await _tts.stop();

    setState(() {
      _isSpeaking = true;
      _hasSpoken = false;
    });

    await _tts.setLanguage('th-TH');
    await _tts.setVoice({
      'name':
          _isFemale ? 'th-th-x-sfg#female_1-local' : 'th-th-x-sfg#male_1-local',
      'locale': 'th-TH',
    });

    await _tts.speak(text);
  }

  Future<void> _prevStep() async {
    if (_currentIndex > 0) {
      await _tts.stop();
      setState(() {
        _isSpeaking = false;
        _currentIndex--;
        _hasSpoken = false;
        _isFemale = DateTime.now().millisecond % 2 == 0;
      });
    }
  }

  Future<void> _nextStep() async {
    if (_currentIndex < widget.steps.length - 1) {
      await _tts.stop();
      setState(() {
        _isSpeaking = false;
        _currentIndex++;
        _hasSpoken = false;
        _isFemale = DateTime.now().millisecond % 2 == 0;
      });
    } else {
      await _tts.stop();
      setState(() => _isSpeaking = false);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFirst = _currentIndex == 0;
    final isLast = _currentIndex == widget.steps.length - 1;
    final step = widget.steps[_currentIndex];
    final imageUrl = widget.imageUrls.isNotEmpty
        ? widget.imageUrls.first
        : 'lib/assets/images/default_recipe.png';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF9B05),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 24, color: Colors.white),
          onPressed: () async {
            await _tts.stop();
            setState(() => _isSpeaking = false);
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          'ขั้นตอนที่ ${_currentIndex + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          // รูปภาพขั้นตอน
          SizedBox(
            height: 272.67,
            width: double.infinity,
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Image.asset(
                'lib/assets/images/default_recipe.png',
                fit: BoxFit.cover,
              ),
            ),
          ),

          // คำอธิบาย
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(
                step.description,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 20,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF000000),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ปุ่มฟังเสียง / เล่นซ้ำ
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton.icon(
                onPressed: _isSpeaking ? null : _playVoice,
                icon: Icon(
                  _isSpeaking
                      ? Icons.volume_up
                      : (_hasSpoken
                          ? Icons.replay_circle_filled
                          : Icons.play_circle_fill),
                  size: 40,
                  color: Colors.black,
                ),
                label: Text(
                  _isSpeaking
                      ? 'กำลังพูด...'
                      : (_hasSpoken ? 'เล่นซ้ำ' : 'ฟังเสียง'),
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    height: 1.2,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  side: const BorderSide(color: Color(0xFF828282), width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(38),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ปุ่ม กลับ และ ถัดไป
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // กลับ
                  Opacity(
                    opacity: isFirst ? 0.3 : 1.0,
                    child: Column(
                      children: [
                        IconButton(
                          icon: SvgPicture.asset(
                            'lib/assets/icons/play_previous.svg',
                            width: 40,
                            height: 40,
                            color: Colors.black,
                          ),
                          onPressed: isFirst ? null : _prevStep,
                        ),
                        const Text(
                          'กลับ',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ถัดไป
                  Opacity(
                    opacity: isLast ? 0.3 : 1.0,
                    child: Column(
                      children: [
                        IconButton(
                          icon: SvgPicture.asset(
                            'lib/assets/icons/play_next.svg',
                            width: 40,
                            height: 40,
                            color: Colors.black,
                          ),
                          onPressed: isLast ? null : _nextStep,
                        ),
                        Text(
                          isLast ? 'เสร็จสิ้น' : 'ถัดไป',
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
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
