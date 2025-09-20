// lib/widgets/skeletons.dart
//
// 2025-08-10 – theme-first shimmer & a11y
// - ใช้สีจาก Theme (surface/surfaceVariant + onSurface overlay) แทนสี fixed
// - ปิด shimmer อัตโนมัติเมื่อผู้ใช้เปิดโหมดลดแอนิเมชัน (accessibleNavigation)
// - เพิ่มพารามิเตอร์ baseColor/highlightColor/enabled เผื่อต้องการ override
// - เพิ่ม Semantics ที่ระดับการ์ด (ประกาศว่า "กำลังโหลด…") แต่หลีกเลี่ยงสแปมในแต่ละกล่อง
// - คง API เดิมของ shimmerBox (เพิ่ม option ไม่ทำให้แตก)

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// กล่อง shimmer ทั่วไปสำหรับวางเป็นบล็อกสีเทาๆ
/// - ถ้ามี `context` จะใช้สีจาก Theme อัตโนมัติ
/// - ถ้าไม่มี/ไม่อยากส่ง ก็ใช้ค่า fallback ที่ดูดีในโหมดสว่าง/มืด
Widget shimmerBox({
  BuildContext? context,
  double? w,
  double? h,
  BorderRadius? radius,
  Color? baseColor,
  Color? highlightColor,
  bool? enabled,
}) {
  // เคารพโหมดลดแอนิเมชันของระบบ
  final reduceMotion =
      context != null ? MediaQuery.of(context).accessibleNavigation : false;
  final isEnabled = enabled ?? !reduceMotion;

  // สร้างเฉดสีจาก Theme (ถ้ามี), ไม่งั้นใช้ fallback
  final cs = context != null ? Theme.of(context).colorScheme : null;

  final Color base = baseColor ??
      (cs != null
          ? Color.alphaBlend(
              cs.onSurface.withValues(alpha: 0.06), cs.surfaceVariant)
          : Colors.grey.shade300);

  final Color highlight = highlightColor ??
      (cs != null
          ? Color.alphaBlend(cs.onSurface.withValues(alpha: 0.04), cs.surface)
          : Colors.grey.shade100);

  final child = Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: base,
      borderRadius: radius ?? BorderRadius.circular(8),
    ),
  );

  if (!isEnabled) return child;

  return Shimmer.fromColors(
    baseColor: base,
    highlightColor: highlight,
    period: const Duration(milliseconds: 1400),
    child: child,
    // เวอร์ชันใหม่ของ shimmer รองรับ enabled; ถ้าเวอร์ชันเก่า ไม่มี field นี้ก็ไม่เป็นไร
    enabled: true,
  );
}

/// โครงการ์ดวัตถุดิบตอนโหลด
class IngredientCardSkeleton extends StatelessWidget {
  final double width;

  /// สัดส่วนรูป (ดีฟอลต์ 4/3 → h = w * 3/4)
  final double imageRatio;

  const IngredientCardSkeleton({
    super.key,
    required this.width,
    this.imageRatio = 4 / 3,
  });

  @override
  Widget build(BuildContext context) {
    final imgH = width / imageRatio; // 4/3 → w * 3/4
    return Semantics(
      label: 'กำลังโหลดการ์ดวัตถุดิบ',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          shimmerBox(
            context: context,
            w: width,
            h: imgH,
            radius: BorderRadius.circular(12),
          ),
          const SizedBox(height: 8),
          shimmerBox(
            context: context,
            w: width,
            h: 14,
            radius: BorderRadius.circular(6),
          ),
          const SizedBox(height: 6),
          shimmerBox(
            context: context,
            w: width * 0.7,
            h: 14,
            radius: BorderRadius.circular(6),
          ),
        ],
      ),
    );
  }
}

/// โครงการ์ดสูตรอาหารแนวตั้งตอนโหลด
class RecipeCardSkeleton extends StatelessWidget {
  /// ความกว้างของการ์ด (เช่น kRecipeCardVerticalWidth)
  final double width;

  const RecipeCardSkeleton({super.key, required this.width});

  @override
  Widget build(BuildContext context) {
    final imgH = width * (3 / 4); // รูป 4:3
    return Semantics(
      label: 'กำลังโหลดการ์ดสูตรอาหาร',
      container: true,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            shimmerBox(
              context: context,
              w: width,
              h: imgH,
              radius: BorderRadius.circular(12),
            ),
            const SizedBox(height: 8),
            shimmerBox(
              context: context,
              w: width,
              h: 16,
              radius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 6),
            shimmerBox(
              context: context,
              w: width * .6,
              h: 14,
              radius: BorderRadius.circular(6),
            ),
          ],
        ),
      ),
    );
  }
}
