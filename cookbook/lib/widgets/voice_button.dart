// lib/widgets/voice_button.dart

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
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(
        Icons.play_arrow,
        size: 24,
        color: Color(0xFF000000),
      ),
      label: const Text(
        'ฟังเสียง',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF000000),
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        side: const BorderSide(
          color: Color(0xFF828282),
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(41),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}
