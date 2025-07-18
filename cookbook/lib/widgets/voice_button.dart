// lib/widgets/voice_button.dart
//
// ★ 2025-07-10 – responsive upgrade ★

import 'package:flutter/material.dart';

/// ปุ่มฟังเสียงสไตล์ Outline ตาม mock-up
class VoiceButton extends StatelessWidget {
  /// Callback เมื่อกดปุ่ม
  final VoidCallback onPressed;

  const VoiceButton({
    Key? key,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    /* ───── responsive numbers ───── */
    final w = MediaQuery.of(context).size.width;
    double scale = (w / 360).clamp(0.82, 1.25); // safe-range

    // helper + clamp ภายใน
    double px(double v, {double min = 4, double max = 999}) =>
        (v * scale).clamp(min, max).toDouble();

    final iconSz = px(24, min: 18, max: 32);
    final fontSz = px(15, min: 12, max: 20);
    final padH = px(16, min: 10);
    final padV = px(12, min: 8);
    final radius = px(41, min: 24); // มุมโค้งอย่างน้อย 24
    final strokeW = px(1.5, min: .8);

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        Icons.play_arrow,
        size: iconSz,
        color: const Color(0xFF000000),
      ),
      label: Text(
        'ฟังเสียง',
        style: TextStyle(
          fontSize: fontSz,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF000000),
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        side: BorderSide(
          color: const Color(0xFF828282),
          width: strokeW,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: padH,
          vertical: padV,
        ),
      ),
    );
  }
}
