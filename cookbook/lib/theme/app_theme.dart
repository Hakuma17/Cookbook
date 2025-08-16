import 'package:flutter/material.dart';

/// สีแบรนด์หลัก (สว่าง)
const _brandSeed = Color(0xFFFF6E40); // ส้มพีช (ปรับได้ตามแบรนด์)
const _lightSurface = Color(0xFFFDF7F2); // เคยใช้ใน Home
const _lightSection = Color(0xFFFFE3D9); // เคยใช้ใน Ingredient section

/// สีฝั่งมืด ให้คอนทราสต์ดีขึ้น
const _darkSurface = Color(0xFF111315);
const _darkSection = Color(0xFF1B1E20);

final ColorScheme lightScheme = ColorScheme.fromSeed(
  seedColor: _brandSeed,
  brightness: Brightness.light,
).copyWith(
  surface: _lightSurface,
  secondaryContainer: _lightSection,
);

final ColorScheme darkScheme = ColorScheme.fromSeed(
  seedColor: _brandSeed,
  brightness: Brightness.dark,
).copyWith(
  surface: _darkSurface,
  secondaryContainer: _darkSection,
);

ThemeData buildLightTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: lightScheme,
      scaffoldBackgroundColor: lightScheme.surface,
    );

ThemeData buildDarkTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: darkScheme,
      scaffoldBackgroundColor: darkScheme.surface,
    );
