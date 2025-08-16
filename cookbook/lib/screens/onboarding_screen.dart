// lib/screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class _FeatureIntroPageData {
  final String title;
  final String? subtitleAccent;
  final WidgetBuilder illustrationBuilder;
  final List<_StepCalloutData>? steps;

  const _FeatureIntroPageData({
    required this.title,
    this.subtitleAccent,
    required this.illustrationBuilder,
    this.steps,
  });
}

class _StepCalloutData {
  final int number;
  final String text;
  final Color? bulletColor;
  const _StepCalloutData(this.number, this.text, {this.bulletColor});
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

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
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
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

  List<_FeatureIntroPageData> _buildPages() {
    return [
      _FeatureIntroPageData(
        title: 'ค้นหาสูตรอาหารได้ตรงใจ',
        subtitleAccent: 'พิมพ์คำค้น + กรองเฉพาะวัตถุดิบที่อยากใช้',
        illustrationBuilder: (_) =>
            _IllustrationImage('assets/onboarding/ob_search.png'),
      ),
      _FeatureIntroPageData(
        title: 'ค้นหาสูตรด้วยภาพถ่ายวัตถุดิบ',
        subtitleAccent: 'ถ่ายรูปวัตถุดิบในครัว แล้วเราช่วยแนะนำเมนู',
        illustrationBuilder: (_) =>
            _IllustrationImage('assets/onboarding/ob_scan.png'),
        steps: [
          _StepCalloutData(1, 'กดไอคอนกล้องในแถบค้นหา'),
          _StepCalloutData(2, 'ถ่ายรูปหรือเลือกจากคลังภาพ'),
          _StepCalloutData(3, 'ดูสูตรอาหารที่แนะนำ'),
        ],
      ),
      _FeatureIntroPageData(
        title: 'จัดการรายการแพ้อาหาร',
        subtitleAccent: 'เราจะช่วยเตือนและกรองสูตรที่ไม่เหมาะกับคุณ',
        illustrationBuilder: (_) =>
            _IllustrationImage('assets/onboarding/ob_allergy.png'),
      ),
      _FeatureIntroPageData(
        title: 'สร้างคลังสูตรของฉัน',
        subtitleAccent: 'บันทึกสูตรที่ชอบ เพิ่มสูตรของคุณเอง',
        illustrationBuilder: (_) =>
            _IllustrationImage('assets/onboarding/ob_myrecipes.png'),
      ),
      _FeatureIntroPageData(
        title: 'พร้อมอร่อยไปกับเราแล้วหรือยัง?',
        subtitleAccent: null,
        illustrationBuilder: (_) =>
            _IllustrationImage('assets/onboarding/ob_ready.png'),
      ),
    ];
  }

  bool get _isLastPage => _index == _pages.length - 1;

  void _next() {
    if (_isLastPage) {
      _finish(wantsToSignUp: !_loggedIn);
    } else {
      _pc.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _skip() => _finish(wantsToSignUp: false);

  Future<void> _finish({required bool wantsToSignUp}) async {
    await AuthService.setOnboardingComplete();
    if (!mounted) return;

    final destinationRoute =
        wantsToSignUp ? '/welcome' : (_loggedIn ? '/home' : '/welcome');

    Navigator.of(context).pushReplacementNamed(destinationRoute);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = _isLastPage;
    final mainButtonLabel = isLast
        ? (_loggedIn ? 'เริ่มใช้งาน' : 'สมัครสมาชิก / เข้าสู่ระบบ')
        : 'ต่อไป';

    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pc,
                    physics: _loadingLogin
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) => _FeatureIntroPage(_pages[i]),
                  ),
                ),
                const SizedBox(height: 16),
                _Dots(
                  count: _pages.length,
                  index: _index,
                  activeColor: theme.colorScheme.primary,
                  inactiveColor: theme.colorScheme.surfaceVariant,
                  onDotTap: (i) => _pc.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: EdgeInsets.fromLTRB(32, 0, 32, 16 + bottomSafe),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _loadingLogin ? null : _next,
                          child: Text(mainButtonLabel),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          onPressed: _loadingLogin ? null : _skip,
                          child: const Text('ข้าม'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // overlay ระหว่างเช็คสถานะล็อกอินครั้งแรก
            if (_loadingLogin)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: Container(
                    color: theme.colorScheme.surface.withOpacity(0.4),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/* ───────────── Pages ───────────── */

class _FeatureIntroPage extends StatelessWidget {
  final _FeatureIntroPageData data;
  const _FeatureIntroPage(this.data);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final showSteps = data.steps != null && data.steps!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        children: [
          Semantics(
            header: true,
            child: Text(
              data.title,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (data.subtitleAccent != null) ...[
            const SizedBox(height: 12),
            Text(
              data.subtitleAccent!,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Expanded(
            child: FractionallySizedBox(
              widthFactor: 0.9,
              child: data.illustrationBuilder(context),
            ),
          ),
          if (showSteps) ...[
            const SizedBox(height: 24),
            _StepCalloutList(data.steps!),
          ],
        ],
      ),
    );
  }
}

class _IllustrationImage extends StatelessWidget {
  final String asset;
  const _IllustrationImage(this.asset);

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        final cs = Theme.of(context).colorScheme;
        return Container(
          color: cs.secondaryContainer,
          alignment: Alignment.center,
          child: Text(
            'ไม่สามารถโหลดรูปภาพได้',
            style: TextStyle(color: cs.onSecondaryContainer),
          ),
        );
      },
    );
  }
}

class _StepCalloutList extends StatelessWidget {
  final List<_StepCalloutData> steps;
  const _StepCalloutList(this.steps);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: steps.map((s) => _StepCallout(s)).toList(),
    );
  }
}

class _StepCallout extends StatelessWidget {
  final _StepCalloutData data;
  const _StepCallout(this.data);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = data.bulletColor ?? theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: color.withOpacity(0.15),
            child: Text(
              '${data.number}',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              data.text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  final Color activeColor;
  final Color inactiveColor;
  final ValueChanged<int>? onDotTap;

  const _Dots({
    required this.count,
    required this.index,
    required this.activeColor,
    required this.inactiveColor,
    this.onDotTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == index;
        return Semantics(
          label: 'สไลด์ที่ ${i + 1} จาก $count',
          selected: isActive,
          button: true,
          child: GestureDetector(
            onTap: onDotTap == null ? null : () => onDotTap!(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 12 : 8,
              height: isActive ? 12 : 8,
              decoration: BoxDecoration(
                color: isActive ? activeColor : inactiveColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}
