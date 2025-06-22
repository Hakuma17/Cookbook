// lib/utils/safe_image.dart
import 'package:flutter/material.dart';

Widget safeImage(String url, {double? width, double? height}) {
  if (url.isEmpty) {
    return Image.asset(
      'assets/images/default_recipe.png',
      width: width,
      height: height,
      fit: BoxFit.cover,
    );
  }
  return Image.network(
    url,
    width: width,
    height: height,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => Image.asset(
      'assets/images/default_recipe.png',
      width: width,
      height: height,
      fit: BoxFit.cover,
    ),
  );
}
