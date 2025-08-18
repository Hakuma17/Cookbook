// lib/utils/safe_image.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/api_service.dart';

/// โหลดรูป "แบบปลอดภัย":
/// - URL ว่าง → ใช้ asset fallback (ค่าเริ่มต้น: assets/images/default_recipe.png)
/// - เป็น asset อยู่แล้ว → Image.asset
/// - เป็น URL → CachedNetworkImage (+ placeholder, error fallback)
class SafeImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? error;
  final double? width, height;
  final BorderRadius? borderRadius;

  /// รูปสำรอง (asset) เวลาโหลดไม่ได้/URL ว่าง
  /// ถ้าไม่ระบุจะใช้ `assets/images/default_recipe.png`
  final String? fallbackAsset;

  /// ป้ายเพื่อการเข้าถึง (อ่านหน้าจอ)
  final String? semanticLabel;

  const SafeImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.error,
    this.width,
    this.height,
    this.borderRadius,
    this.fallbackAsset,
    this.semanticLabel,
  });

  bool _looksLikeAsset(String s) =>
      s.startsWith('assets/') || s.startsWith('asset:');

  @override
  Widget build(BuildContext context) {
    // ให้ ApiService แปลง relative → absolute, รวมถึงกรณี http://localhost → 10.0.2.2
    final normalized = ApiService.normalizeUrl(url).trim();
    final fallback = fallbackAsset ?? 'assets/images/default_recipe.png';

    final dpr = MediaQuery.of(context).devicePixelRatio;
    final memCacheWidth =
        (width != null && width! > 0) ? (width! * dpr).round() : null;
    final memCacheHeight =
        (height != null && height! > 0) ? (height! * dpr).round() : null;

    Widget child;

    if (normalized.isEmpty) {
      // ว่าง → ใช้ fallback asset
      child = error ??
          Image.asset(fallback, fit: fit, width: width, height: height);
    } else if (_looksLikeAsset(normalized)) {
      // เป็น asset path อยู่แล้ว → ไม่ต้องโหลดเน็ต
      final assetPath = normalized.startsWith('asset:')
          ? normalized.substring(6)
          : normalized;
      child = Image.asset(assetPath, fit: fit, width: width, height: height);
    } else {
      // โหลดผ่านเน็ตด้วยแคช
      child = CachedNetworkImage(
        imageUrl: normalized,
        fit: fit,
        width: width,
        height: height,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        placeholder: (_, __) =>
            placeholder ?? _DefaultSkeleton(width: width, height: height),
        errorWidget: (_, __, ___) =>
            error ??
            Image.asset(fallback, fit: fit, width: width, height: height),
      );
    }

    // คลิปโค้งถ้าระบุ borderRadius
    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }

    // ใส่ semantics ถ้าต้องการ
    if (semanticLabel != null && semanticLabel!.isNotEmpty) {
      child = Semantics(label: semanticLabel, image: true, child: child);
    }

    return child;
  }
}

class _DefaultSkeleton extends StatelessWidget {
  final double? width, height;
  const _DefaultSkeleton({this.width, this.height});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
    );
  }
}
