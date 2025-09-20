import 'package:flutter/material.dart';
import '../utils/safe_image.dart';

/// CarouselWidget – PageView + arrows + dots
/// • ถ้า list ว่าง หรือโหลดรูปเน็ตไม่ได้  ➜  ใช้ default_recipe.png
class CarouselWidget extends StatefulWidget {
  final List<String>? imageUrls; // ← ยอมรับ null ได้ด้วย
  final double height;
  final PageController? controller;
  final ValueChanged<int>? onPageChanged;

  const CarouselWidget({
    super.key,
    required this.imageUrls,
    this.height = 280,
    this.controller,
    this.onPageChanged,
  });

  @override
  State<CarouselWidget> createState() => _CarouselWidgetState();
}

class _CarouselWidgetState extends State<CarouselWidget> {
  late final PageController _internal;
  int _idx = 0;

  PageController get _ctrl => widget.controller ?? _internal;

  @override
  void initState() {
    super.initState();
    _internal = PageController();
    if (widget.controller == null) {
      _internal.addListener(() {
        final p = _ctrl.page;
        if (p != null) setState(() => _idx = p.round());
      });
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) _internal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    /* 1️⃣ เตรียมรายการรูป (ใส่ fallback เสมอ) */
    final imgs = (widget.imageUrls ?? [])
        .where((e) => e.trim().isNotEmpty)
        .toList(growable: true);
    if (imgs.isEmpty) imgs.add('assets/images/default_recipe.png');

    return SizedBox(
      height: widget.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          /* PageView */
          PageView.builder(
            controller: _ctrl,
            itemCount: imgs.length,
            onPageChanged: widget.onPageChanged,
            itemBuilder: (_, i) {
              final src = imgs[i];
              final isAsset = src.startsWith('assets/');
              return isAsset
                  ? Image.asset(src, fit: BoxFit.cover)
                  : SafeImage(
                      url: src,
                      fit: BoxFit.cover,
                    );
            },
          ),

          /* arrows + dots */
          if (imgs.length > 1) ...[
            Positioned(
              left: 16,
              child: _Arrow(
                Icons.arrow_back_ios_new,
                () => _ctrl.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut),
              ),
            ),
            Positioned(
              right: 16,
              child: _Arrow(
                Icons.arrow_forward_ios,
                () => _ctrl.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut),
              ),
            ),
            Positioned(
              bottom: 16,
              child: _Dots(count: imgs.length, active: _idx),
            ),
          ],
        ],
      ),
    );
  }
}

/* ── helper ───────────────────────── */

class _Arrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback tap;
  const _Arrow(this.icon, this.tap);

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: tap,
        icon: Icon(icon),
        iconSize: 22,
        style: IconButton.styleFrom(
          backgroundColor:
              Theme.of(context).colorScheme.surface.withValues(alpha: .8),
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(12),
        ),
      );
}

class _Dots extends StatelessWidget {
  final int count;
  final int active;
  const _Dots({required this.count, required this.active});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: List.generate(count, (i) {
            final on = i == active;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: on ? 10 : 8,
              height: on ? 10 : 8,
              decoration: BoxDecoration(
                color: on
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white.withValues(alpha: .8),
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      );
}
