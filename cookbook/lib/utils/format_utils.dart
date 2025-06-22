// lib/utils/format_utils.dart

import 'package:flutter/material.dart';

/// แปลงตัวเลข เช่น 1000 → 1k, 2500000 → 2.5M
String formatCount(int number) {
  if (number >= 1000000) {
    return '${(number / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
  } else if (number >= 1000) {
    return '${(number / 1000).toStringAsFixed(1).replaceAll('.0', '')}k';
  } else {
    return number.toString();
  }
}

/// คืน widget รูปภาพจาก URL ถ้ามี, ถ้าไม่มีให้ใช้รูป fallback แทน
Widget safeImage(String? url,
    {BoxFit fit = BoxFit.cover, double? width, double? height}) {
  if (url == null || url.trim().isEmpty) {
    return Image.asset(
      'assets/images/default_recipe.jpg',
      fit: fit,
      width: width,
      height: height,
    );
  }

  return Image.network(
    url,
    fit: fit,
    width: width,
    height: height,
    errorBuilder: (context, error, stackTrace) {
      return Image.asset(
        'assets/images/default_recipe.jpg',
        fit: fit,
        width: width,
        height: height,
      );
    },
  );
}
