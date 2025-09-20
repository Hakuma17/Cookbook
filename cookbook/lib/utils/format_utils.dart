// lib/utils/format_utils.dart
// (no Flutter imports needed here)

/// 950 → 950, 1,000 → 1.0K, 12,345 → 12.3K, 1,234,567 → 1.2M
String formatCount(int? number) {
  final n = number ?? 0;
  if (n >= 1_000_000) {
    return '${(n / 1_000_000).toStringAsFixed(1)}M';
  } else if (n >= 1_000) {
    return '${(n / 1_000).toStringAsFixed(1)}K';
  }
  return n.toString();
}

/// แปลงคะแนนเป็นทศนิยม 1 ตำแหน่ง รองรับค่า null
String formatRating(double? rating) => (rating ?? 0).toStringAsFixed(1);
