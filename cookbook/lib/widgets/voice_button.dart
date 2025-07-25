import 'package:flutter/material.dart';

/// ปุ่มเล่นเสียงวิธีทำ  (disabled ได้)
class VoiceButton extends StatelessWidget {
  /// กดเพื่อเล่นเสียง – ถ้า `enabled=false` ให้ส่ง null หรือไม่ใช้เลย
  final VoidCallback? onPressed;
  final bool enabled;

  const VoiceButton({
    super.key,
    required this.onPressed,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: enabled ? onPressed : null, // null = disabled
        icon: const Icon(Icons.play_arrow),
        label: const Text('ขั้นตอนที่อธิบายด้วยเสียง'),
      ),
    );
  }
}
