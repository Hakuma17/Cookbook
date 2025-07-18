// lib/widgets/carousel_widget.dart

import 'package:flutter/material.dart';

/// CarouselWidget
/// แสดง list ของ URL รูปภาพเป็น PageView พร้อม indicator และปุ่มเลื่อน
class CarouselWidget extends StatefulWidget {
  final List<String>? imageUrls;
  final double height; // สูงของรูป (ไม่รวม indicator)
  final PageController? controller;
  final ValueChanged<int>? onPageChanged;
  const CarouselWidget({
    Key? key,
    this.imageUrls,
    this.height = 272.67,
    this.controller,
    this.onPageChanged,
  }) : super(key: key);

  @override
  State<CarouselWidget> createState() => _CarouselWidgetState();
}

class _CarouselWidgetState extends State<CarouselWidget> {
  late final PageController _internalController;
  int _currentIndex = 0;

  PageController get _controller => widget.controller ?? _internalController;

  @override
  void initState() {
    super.initState();
    _internalController = PageController();
    if (widget.controller == null) {
      _internalController.addListener(_handlePageChange);
    }
  }

  void _handlePageChange() {
    final page = _controller.page;
    if (page != null) {
      final idx = page.round();
      if (idx != _currentIndex) setState(() => _currentIndex = idx);
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _internalController.removeListener(_handlePageChange);
      _internalController.dispose();
    }
    super.dispose();
  }

  /* ────────────── build ────────────── */
  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls ?? [];
    final hasImages = urls.isNotEmpty;

    /* ── responsive numbers ── */
    final w = MediaQuery.of(context).size.width;
    double clamp(double v, double min, double max) =>
        v < min ? min : (v > max ? max : v);

    final arrowSize = clamp(w * .11, 32, widget.height * .80); // ≤ 80 % สูงรูป
    final iconSize = arrowSize * .50;
    final arrowPad = arrowSize * .25;
    final sideInset = clamp(w * .02, 6, 20);
    final dotSize = clamp(w * .015, 4, 8);
    final dotGap = dotSize * .80;
    final indicatorPad = dotSize;
    final bottomOff = dotSize * 2; // space ยก indicator

    const arrowColor = Color(0xFF666666);
    const bgColor = Colors.white;
    const dotActive = Color(0xFFFF9B05);
    const dotInactive = Color(0xFFE3E3E3);

    return SizedBox(
      width: double.infinity,
      height: widget.height + bottomOff + indicatorPad * 2,
      child: Stack(
        children: [
          /* รูปหลัก / fallback */
          Positioned.fill(
            child: hasImages
                ? PageView.builder(
                    controller: _controller,
                    itemCount: urls.length,
                    onPageChanged: widget.onPageChanged ??
                        (i) => setState(() => _currentIndex = i),
                    itemBuilder: (_, i) => Image.network(
                      urls[i],
                      width: double.infinity,
                      height: widget.height,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image,
                            size: 48, color: Colors.grey),
                      ),
                    ),
                  )
                : Image.asset('assets/images/default_recipe.png',
                    width: double.infinity,
                    height: widget.height,
                    fit: BoxFit.cover),
          ),

          /* ───────── controls / indicator ───────── */
          if (hasImages && urls.length > 1) ...[
            /* ปุ่มซ้าย */
            Positioned(
              left: sideInset,
              top: (widget.height - arrowSize) / 2,
              child: _ArrowButton(
                size: arrowSize,
                iconSize: iconSize,
                padding: arrowPad,
                icon: Icons.arrow_back_ios,
                onTap: () {
                  final prev = (_currentIndex - 1 + urls.length) % urls.length;
                  _controller.animateToPage(
                    prev,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ),

            /* ปุ่มขวา */
            Positioned(
              right: sideInset,
              top: (widget.height - arrowSize) / 2,
              child: _ArrowButton(
                size: arrowSize,
                iconSize: iconSize,
                padding: arrowPad,
                icon: Icons.arrow_forward_ios,
                onTap: () {
                  final next = (_currentIndex + 1) % urls.length;
                  _controller.animateToPage(
                    next,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ),

            /* dot-indicator */
            Positioned(
              bottom: bottomOff,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(indicatorPad * .6),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(urls.length, (i) {
                      final active = i == _currentIndex;
                      return Container(
                        margin: EdgeInsets.symmetric(horizontal: dotGap / 2),
                        width: dotSize,
                        height: dotSize,
                        decoration: BoxDecoration(
                          color: active ? dotActive : dotInactive,
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/*─────────── arrow button widget ─────────*/
class _ArrowButton extends StatelessWidget {
  final double size;
  final double iconSize;
  final double padding;
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowButton({
    required this.size,
    required this.iconSize,
    required this.padding,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(padding),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: iconSize, color: Color(0xFF666666)),
      ),
    );
  }
}
