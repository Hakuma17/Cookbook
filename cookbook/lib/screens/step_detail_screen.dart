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
  bool _busy = false; // true ระหว่าง speak
  bool _spoken = false; // เคยพูด step นี้แล้ว
  late bool _female; // สลับชาย/หญิงเพื่อความหลากหลาย
  // Removed _errSub as FlutterTts does not provide onError stream

  @override
  void initState() {
    super.initState();
    _idx = widget.initialIndex.clamp(0, widget.steps.length - 1);
    _female = DateTime.now().millisecond.isEven;

    _tts = FlutterTts();
    // handler เสร็จเสียง
    _tts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _spoken = true;
      });
    });
    // FlutterTts does not provide an onError stream; errors are handled in try-catch blocks
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  /* ───────────────────── helpers ───────────────────── */
  Future<void> _speak() async {
    if (_busy) return; // กันกดรัว
    final txt = widget.steps[_idx].description.trim();
    if (txt.isEmpty) {
      _showSnack('ไม่มีข้อความให้พูด');
      return;
    }

    setState(() {
      _busy = true;
      _spoken = false;
    });

    try {
      await _tts.stop(); // kill ตัวก่อนหน้า
      await _tts.setLanguage('th-TH');
      await _tts.setVoice({
        'name':
            _female ? 'th-th-x-sfg#female_1-local' : 'th-th-x-sfg#male_1-local',
        'locale': 'th-TH',
      });
      await _tts.speak(txt);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _showSnack('พูดไม่สำเร็จ: $e');
      }
    }
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _toPrev() async {
    if (_idx == 0) return;
    await _tts.stop();
    setState(() {
      _idx--;
      _busy = false;
      _spoken = false;
      _female = DateTime.now().millisecond.isEven;
    });
  }

  Future<void> _toNext() async {
    if (_idx < widget.steps.length - 1) {
      await _tts.stop();
      setState(() {
        _idx++;
        _busy = false;
        _spoken = false;
        _female = DateTime.now().millisecond.isEven;
      });
    } else {
      await _tts.stop();
      if (mounted) Navigator.pop(context);
    }
  }

  /* ───────────────────── build ───────────────────── */
  @override
  Widget build(BuildContext context) {
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
      ),
      body: Column(
        children: [
          /* ภาพประกอบ */
          SizedBox(
            height: 272,
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

          /* คำอธิบาย */
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(step.description,
                  style: const TextStyle(
                      fontSize: 20, height: 1.3, fontWeight: FontWeight.w600)),
            ),
          ),

          /* ปุ่มเสียง */
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _speak,
                icon: Icon(
                  _busy
                      ? Icons.volume_up
                      : (_spoken
                          ? Icons.replay_circle_filled
                          : Icons.play_arrow),
                  size: 40,
                  color: Colors.black,
                ),
                label: Text(
                  _busy ? 'กำลังพูด...' : (_spoken ? 'เล่นซ้ำ' : 'ฟังเสียง'),
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF828282), width: 2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(38)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          /* ปุ่ม back / next */
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavButton(
                    enabled: !isFirst,
                    icon: 'assets/icons/play_previous.svg',
                    label: 'กลับ',
                    onTap: _toPrev,
                  ),
                  _NavButton(
                    enabled: true,
                    icon: 'assets/icons/play_next.svg',
                    label: isLast ? 'เสร็จสิ้น' : 'ถัดไป',
                    onTap: _toNext,
                    dim: isLast,
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
  final bool dim;
  final String icon;
  final String label;
  final VoidCallback onTap;
  const _NavButton({
    required this.enabled,
    this.dim = false,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? (dim ? .5 : 1) : .3,
      child: Column(
        children: [
          IconButton(
            icon: SvgPicture.asset(icon, width: 40, height: 40),
            onPressed: enabled ? onTap : null,
          ),
          Text(label,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
