// lib/screens/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import 'home_screen.dart';
import 'welcome_screen.dart';

/* ────────────────────────────────────────────────────────────────────────── */
/*  สี / สไตล์แบรนด์                                                          */
/* ────────────────────────────────────────────────────────────────────────── */
const _brand = Color(0xFFFFC08D); // สีใหญ่ที่เห็นใน Splash
const _accent = Color(0xFFFF9B05); // สีปุ่มหลักส้มสด
const _textDark = Color(0xFF1A1A1A);
const _textLight = Color(0xFF747474);

/* ────────────────────────────────────────────────────────────────────────── */
/*  โมเดลข้อมูลของแต่ละสไลด์                                                   */
/* ────────────────────────────────────────────────────────────────────────── */
class _FeatureIntroPageData {
  final String title; // หัวใหญ่ดำ
  final String? subtitleAccent; // ข้อความสั้นสีส้ม (optional)
  final WidgetBuilder illustrationBuilder; // วาดรูปตัวอย่างฟีเจอร์
  final List<_StepCalloutData>? steps; // รายการขั้นตอน (optional)

  const _FeatureIntroPageData({
    required this.title,
    this.subtitleAccent,
    required this.illustrationBuilder,
    this.steps,
  });
}

class _StepCalloutData {
  final int number; // ลำดับ 1,2,3 ...
  final String text; // อธิบายขั้นตอน
  final Color? bulletColor; // สีวงกลมตัวเลข
  // ignore: unused_element_parameter
  const _StepCalloutData(this.number, this.text, {this.bulletColor});
}

/* ────────────────────────────────────────────────────────────────────────── */
/*  OnboardingScreen                                                           */
/* ────────────────────────────────────────────────────────────────────────── */
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pc;
  late final List<_FeatureIntroPageData> _pages;
  int _index = 0;
  bool _loadingLogin = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _pc = PageController();
    _pages = _buildPages();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final logged = await AuthService.isLoggedIn();
    if (!mounted) return;
    setState(() {
      _loggedIn = logged;
      _loadingLogin = false;
    });
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  /* ────────────────────────── DATA: เพจต่าง ๆ ────────────────────────── */
  List<_FeatureIntroPageData> _buildPages() {
    return [
      _FeatureIntroPageData(
        title: 'ค้นหาสูตรอาหารได้ตรงใจ',
        subtitleAccent: 'พิมพ์คำค้น + กรองเฉพาะวัตถุดิบที่อยากใช้',
        illustrationBuilder: (_) =>
            const _IllustrationImage('assets/onboarding/ob_search.png'),
      ),
      _FeatureIntroPageData(
        title: 'หน้าสอนการใช้ฟีเจอร์ "ค้นด้วยภาพวัตถุดิบ"',
        subtitleAccent: 'ถ่ายรูปวัตถุดิบในครัว แล้วเราช่วยแนะนำเมนู',
        illustrationBuilder: (_) =>
            const _IllustrationImage('assets/images/onboarding/ob_scan.png'),
        steps: const [
          _StepCalloutData(1, 'กดไอคอนกล้องในแถบค้นหา'),
          _StepCalloutData(2, 'ถ่ายรูปหรือเลือกจากคลังภาพ'),
          _StepCalloutData(3, 'ดูสูตรอาหารที่แนะนำ'),
        ],
      ),
      _FeatureIntroPageData(
        title: 'จัดการรายการแพ้อาหารได้',
        subtitleAccent: 'เราจะช่วยกรองสูตรที่ไม่เหมาะ',
        illustrationBuilder: (_) =>
            const _IllustrationImage('assets/images/onboarding/ob_allergy.png'),
      ),
      _FeatureIntroPageData(
        title: 'สร้างคลังสูตรของฉัน',
        subtitleAccent: 'บันทึกสูตรที่ชอบ เพิ่มสูตรของคุณเอง',
        illustrationBuilder: (_) => const _IllustrationImage(
            'assets/images/onboarding/ob_myrecipes.png'),
      ),
      _FeatureIntroPageData(
        title: 'พร้อมอร่อยไปกับเราไหม?',
        subtitleAccent: null,
        illustrationBuilder: (_) =>
            const _IllustrationImage('assets/images/onboarding/ob_ready.png'),
      ),
    ];
  }

  /* ────────────────────────── ACTIONS ────────────────────────── */
  bool get _isLast => _index == _pages.length - 1;

  void _next() {
    if (_isLast) {
      _finish(signUpPressed: !_loggedIn); // ถ้ายังไม่ล็อกอินถือว่าอยากสมัคร
    } else {
      _pc.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _skip() {
    _finish(signUpPressed: false);
  }

  Future<void> _finish({required bool signUpPressed}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (!mounted) return;

    Widget dest;
    if (signUpPressed && !_loggedIn) {
      dest = const WelcomeScreen();
    } else {
      // ถ้าล็อกอินแล้ว (หรือกดข้าม) ไป Home ถ้า login, ถ้าไม่ login ไป Welcome
      final logged = _loggedIn || await AuthService.isLoggedIn();
      dest = logged ? const HomeScreen() : const WelcomeScreen();
    }

    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => dest,
      transitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ));
  }

  /* ────────────────────────── UI BUILD ────────────────────────── */
  @override
  Widget build(BuildContext context) {
    final pages = _pages; // local
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _FeatureIntroPage(pages[i]),
              ),
            ),
            const SizedBox(height: 16),
            _Dots(count: pages.length, index: _index, activeColor: _accent),
            const SizedBox(height: 24),
            _buildButtons(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildButtons() {
    final isLast = _isLast;
    final mainLabel =
        isLast ? (_loggedIn ? 'เริ่มใช้งาน' : 'สมัครสมาชิกเลย') : 'ต่อไป';
    final secLabel = isLast ? 'ข้าม' : 'ข้าม'; // เหมือนกันแต่ปรับได้

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                textStyle:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              onPressed: _loadingLogin ? null : _next,
              child: Text(mainLabel),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFDBDBDB), width: 2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                textStyle:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                foregroundColor: _textLight,
              ),
              onPressed: _loadingLogin ? null : _skip,
              child: Text(secLabel),
            ),
          ),
        ],
      ),
    );
  }
}

/* ────────────────────────────────────────────────────────────────────────── */
/*  วิดเจ็ตเพจย่อย                                                              */
/* ────────────────────────────────────────────────────────────────────────── */
class _FeatureIntroPage extends StatelessWidget {
  final _FeatureIntroPageData data;
  const _FeatureIntroPage(this.data);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final maxH = mq.size.height;
    final bool showSteps = data.steps != null && data.steps!.isNotEmpty;

    // scale ภาพเล็กลงอิงความสูงหน้าจอ
    final double illusMaxH = maxH * (showSteps ? 0.38 : 0.48);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          Text(data.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: _textDark)),
          if (data.subtitleAccent != null) ...[
            const SizedBox(height: 12),
            Text(data.subtitleAccent!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600, color: _accent)),
          ],
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: illusMaxH, maxWidth: 500),
            child: data.illustrationBuilder(context),
          ),
          if (showSteps) ...[
            const SizedBox(height: 32),
            _StepCalloutList(data.steps!),
          ],
        ],
      ),
    );
  }
}

/* ────────────────────────────────────────────────────────────────────────── */
/*  รูปประกอบ                                                                   */
/* ────────────────────────────────────────────────────────────────────────── */
class _IllustrationImage extends StatelessWidget {
  final String asset;
  const _IllustrationImage(this.asset, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Image.asset(asset, fit: BoxFit.contain, errorBuilder: (_, __, ___) {
      // fallback debug placeholder
      return Container(
        color: _brand.withOpacity(.2),
        alignment: Alignment.center,
        child: const Text('ภาพหาย', style: TextStyle(color: _textLight)),
      );
    });
  }
}

/* ────────────────────────────────────────────────────────────────────────── */
/*  Step Callouts                                                               */
/* ────────────────────────────────────────────────────────────────────────── */
class _StepCalloutList extends StatelessWidget {
  final List<_StepCalloutData> steps;
  const _StepCalloutList(this.steps, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: steps.map((s) => _StepCallout(s)).toList(),
    );
  }
}

class _StepCallout extends StatelessWidget {
  final _StepCalloutData data;
  const _StepCallout(this.data, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = data.bulletColor ?? _accent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: color.withOpacity(.15),
                border: Border.all(color: color, width: 1.5),
                shape: BoxShape.circle),
            child: Text('${data.number}',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(data.text,
                style: const TextStyle(
                    fontSize: 16, color: _textDark, height: 1.25)),
          ),
        ],
      ),
    );
  }
}

/* ────────────────────────────────────────────────────────────────────────── */
/*  จุดบอกหน้าสไลด์                                                             */
/* ────────────────────────────────────────────────────────────────────────── */
class _Dots extends StatelessWidget {
  final int count;
  final int index;
  final Color activeColor;
  const _Dots(
      {required this.count,
      required this.index,
      required this.activeColor,
      Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 12 : 8,
          height: active ? 12 : 8,
          decoration: BoxDecoration(
            color: active ? activeColor : const Color(0xFFD8D8D8),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}
