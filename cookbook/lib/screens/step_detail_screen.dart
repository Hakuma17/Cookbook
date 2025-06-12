// lib/screens/step_detail_screen.dart

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

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _currentIndex = widget.initialIndex.clamp(0, widget.steps.length - 1);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  void _playVoice() {
    final text = widget.steps[_currentIndex].description;
    _tts.speak(text);
    setState(() => _hasSpoken = true);
  }

  void _prevStep() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _hasSpoken = false;
      });
    }
  }

  void _nextStep() {
    if (_currentIndex < widget.steps.length - 1) {
      setState(() {
        _currentIndex++;
        _hasSpoken = false;
      });
    } else {
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
          onPressed: () => Navigator.of(context).pop(),
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
          // รูปเมนู
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
                  height: 24 / 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF000000),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ปุ่มฟังเสียง / เล่นซ้ำ
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: _playVoice,
              icon: SvgPicture.asset(
                'lib/assets/icons/check_circle.svg',
                width: 24,
                height: 24,
                color: const Color(0xFF000000),
              ),
              label: Text(
                _hasSpoken ? 'เล่นซ้ำ' : 'ฟังเสียง',
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF000000),
                  height: 22 / 20,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF828282), width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(38),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ปุ่มกลับและถัดไป
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Opacity(
                    opacity: isFirst ? 0.3 : 1.0,
                    child: GestureDetector(
                      onTap: isFirst ? null : _prevStep,
                      child: SvgPicture.asset(
                        'lib/assets/icons/play_previous.svg',
                        width: 32,
                        height: 32,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: 1.0,
                    child: Text(
                      isLast ? 'เสร็จสิ้น' : 'ถัดไป',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF000000),
                        height: 22 / 24,
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: isLast ? 0.3 : 1.0,
                    child: GestureDetector(
                      onTap: isLast ? null : _nextStep,
                      child: SvgPicture.asset(
                        'lib/assets/icons/play_next.svg',
                        width: 32,
                        height: 32,
                        color: Colors.black,
                      ),
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
