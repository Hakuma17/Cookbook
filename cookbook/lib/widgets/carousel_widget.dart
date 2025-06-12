// lib/widgets/carousel_widget.dart

import 'package:flutter/material.dart';

/// CarouselWidget
/// แสดง list ของ URL รูปภาพเป็น PageView พร้อม indicator และปุ่มเลื่อนคู่
class CarouselWidget extends StatefulWidget {
  /// รายการ URL ของรูปภาพ
  final List<String>? imageUrls;

  /// ความสูงของ carousel (รูปสูงเท่านี้ + indicator ด้านล่าง)
  final double height;

  /// ถ้ามี controller ภายนอก ให้ใช้ ไม่สร้างใหม่
  final PageController? controller;

  /// ถ้ามี callback onPageChanged ให้เรียกเมื่อเปลี่ยนหน้า
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

  // เลือกใช้ controller ภายนอก ถ้ามี ไม่งั้นใช้ internal
  PageController get _controller => widget.controller ?? _internalController;

  @override
  void initState() {
    super.initState();
    _internalController = PageController();
    // ถ้าใช้ controller ภายใน ต้องติด listener เพื่ออัปเดต dot indicator
    if (widget.controller == null) {
      _internalController.addListener(_handlePageChange);
    }
  }

  void _handlePageChange() {
    final page = _controller.page;
    if (page != null) {
      final idx = page.round();
      if (idx != _currentIndex) {
        setState(() => _currentIndex = idx);
      }
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

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls ?? [];
    final hasImages = urls.isNotEmpty;

    const arrowSize = 43.63;
    const iconSize = 21.81;
    const arrowPadding = 10.91;
    const arrowColor = Color(0xFF666666);
    const bgColor = Colors.white;
    const dotActive = Color(0xFFFF9B05);
    const dotInactive = Color(0xFFE3E3E3);

    return SizedBox(
      width: double.infinity,
      height: widget.height + 13.088,
      child: Stack(
        children: [
          // รูปหรือ placeholder
          Positioned.fill(
            child: hasImages
                ? PageView.builder(
                    controller: _controller,
                    itemCount: urls.length,
                    onPageChanged: widget.onPageChanged ??
                        (i) {
                          // ถ้าไม่มี callback ภายนอก ให้อัปเดต internal dot
                          setState(() => _currentIndex = i);
                        },
                    itemBuilder: (_, i) => Image.network(
                      urls[i],
                      width: double.infinity,
                      height: widget.height,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  )
                : Image.asset(
                    // fallback ถ้าไม่มีรูป
                    'lib/assets/images/default_recipe.png',
                    width: double.infinity,
                    height: widget.height,
                    fit: BoxFit.cover,
                  ),
          ),

          if (hasImages && urls.length > 1) ...[
            // ปุ่มเลื่อนซ้าย
            Positioned(
              left: 8.73,
              top: (widget.height - arrowSize) / 2,
              child: InkWell(
                onTap: () {
                  final prev = (_currentIndex - 1 + urls.length) % urls.length;
                  _controller.animateToPage(
                    prev,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                borderRadius: BorderRadius.circular(arrowSize / 2),
                child: Container(
                  width: arrowSize,
                  height: arrowSize,
                  padding: const EdgeInsets.all(arrowPadding),
                  decoration: const BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios,
                    size: iconSize,
                    color: arrowColor,
                  ),
                ),
              ),
            ),

            // ปุ่มเลื่อนขวา
            Positioned(
              right: 8.73,
              top: (widget.height - arrowSize) / 2,
              child: InkWell(
                onTap: () {
                  final next = (_currentIndex + 1) % urls.length;
                  _controller.animateToPage(
                    next,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                borderRadius: BorderRadius.circular(arrowSize / 2),
                child: Container(
                  width: arrowSize,
                  height: arrowSize,
                  padding: const EdgeInsets.all(arrowPadding),
                  decoration: const BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    size: iconSize,
                    color: arrowColor,
                  ),
                ),
              ),
            ),

            // ดอทอินดิเคเตอร์
            Positioned(
              bottom: 13.088,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(4.38465),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(38.3657),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(urls.length, (i) {
                      final isActive = i == _currentIndex;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4.38),
                        width: 5.48,
                        height: 5.48,
                        decoration: BoxDecoration(
                          color: isActive ? dotActive : dotInactive,
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
