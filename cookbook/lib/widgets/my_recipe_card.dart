// lib/widgets/my_recipe_card.dart

import 'package:flutter/material.dart';
import '../models/recipe.dart';

class MyRecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onTap;

  const MyRecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    /* ───────────────────────── responsive helpers ───────────────────────── */
    double clamp(double v, double min, double max) =>
        v < min ? min : (v > max ? max : v);

    // ───────────────────────────────────────────────────────────────────────
    //  ใช้ LayoutBuilder เพื่อ scale จากขนาด “การ์ดจริง” ไม่ใช่กว้างจอ
    // ───────────────────────────────────────────────────────────────────────
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth; // ความกว้างของการ์ด

      // คำนวณค่าตามสัดส่วน
      final radius = clamp(w * .08, 12, 22); // มุมโค้ง
      final borderW = clamp(w * .004, 1, 1.6); // เส้นกรอบ
      final shadowBlur = clamp(w * .045, 6, 12); // เงา
      final imgH = clamp(w * .62, 110, 200); // สูงรูป
      final nameFont = clamp(w * .09, 14, 20); // ชื่อเมนู
      final metaFont = clamp(nameFont - 3, 11, 17); // คะแนน/รีวิว
      final iconSz = metaFont + 3; // ไอคอนดาว
      final gapX = clamp(w * .02, 4, 8); // ระยะห่างแนวนอน

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE0E0E0), width: borderW),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.08),
              blurRadius: shadowBlur,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: onTap,
            splashColor: const Color(0xFFFFF1E0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                /* ─── รูป ─── */
                SizedBox(
                  height: imgH,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(radius)),
                        child: _buildImage(imgH),
                      ),
                      if (recipe.hasAllergy)
                        Positioned(
                          top: gapX,
                          left: gapX,
                          child: Container(
                            width: iconSz + 6,
                            height: iconSz + 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.redAccent,
                            ),
                            child: const Icon(Icons.priority_high,
                                size: 16, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),

                /* ─── ชื่อเมนู ─── */
                Padding(
                  padding: EdgeInsets.fromLTRB(gapX * 2, gapX * 1.6, gapX * 2,
                      gapX * .8), // = 12,10,12,4 (approx)
                  child: Text(
                    recipe.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: nameFont,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Montserrat',
                      color: const Color(0xFF0A2533),
                    ),
                  ),
                ),

                /* ─── คะแนน / รีวิว ─── */
                Padding(
                  padding:
                      EdgeInsets.fromLTRB(gapX * 2, 0, gapX * 2, gapX * 2.2),
                  child: Row(
                    children: [
                      Icon(Icons.star,
                          size: iconSz, color: const Color(0xFFFF9B05)),
                      SizedBox(width: gapX),
                      // FittedBox กันเลขยาว
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          recipe.averageRating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: metaFont,
                            color: const Color(0xFF555555),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: gapX),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '| ${recipe.reviewCount} ความคิดเห็น',
                          style: TextStyle(
                            fontSize: metaFont,
                            color: const Color(0xFF999999),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  /* ───────────────────── helpers ───────────────────── */
  Widget _buildImage(double h) {
    if (recipe.imageUrl.isNotEmpty) {
      return Image.network(
        recipe.imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: h,
        errorBuilder: (_, __, ___) => _fallbackImage(h),
      );
    }
    return _fallbackImage(h);
  }

  Widget _fallbackImage(double h) => Image.asset(
        'assets/images/default_recipe.png',
        fit: BoxFit.cover,
        width: double.infinity,
        height: h,
      );
}
