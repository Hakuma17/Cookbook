// lib/widgets/allergy_warning_dialog.dart
//
// responsive-plus 2025-07-11
// – รองรับจอเล็ก-ใหญ่ ไม่ล้นขอบ (ใช้ SingleChildScrollView + Wrap badge)
// – clamp() คุมทุกตัวเลขเหมือนเดิม  ✅
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import '../models/recipe.dart';

typedef OnAllergyConfirmed = void Function(Recipe recipe);

class AllergyWarningDialog extends StatelessWidget {
  final Recipe recipe;
  final List<String> badIngredientNames;
  final OnAllergyConfirmed onConfirm;

  const AllergyWarningDialog({
    Key? key,
    required this.recipe,
    required this.badIngredientNames,
    required this.onConfirm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    /* ── responsive metrics ── */
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    double clamp(double v, double min, double max) =>
        v < min ? min : (v > max ? max : v);

    final padH = clamp(w * .06, 16, 32); // แนวนอน
    final padV = clamp(w * .045, 20, 28); // แนวตั้ง
    final iconSz = clamp(w * .14, 44, 72); // ไอคอนเตือน
    final titleF = clamp(w * .050, 18, 24); // ฟอนต์หัวข้อ
    final bodyF = clamp(w * .044, 14, 18); // ฟอนต์ข้อความ
    final buttonF = clamp(w * .046, 15, 20); // ฟอนต์ปุ่ม
    final badgeF = bodyF; // ฟอนต์ชื่อวัตถุดิบ
    final badgePad = clamp(w * .03, 10, 16); // padding badge

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: padH,
        vertical: clamp(h * .05, 24, 48), // เพิ่ม vertical padding
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: SingleChildScrollView(
        // ⇦ ป้องกันล้นแนวสูง
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: iconSz, color: Colors.redAccent),
              SizedBox(height: padV * .6),
              Text(
                'คำเตือน',
                style: TextStyle(
                  fontSize: titleF,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
              SizedBox(height: padV * .45),
              Text(
                'เมนู “${recipe.name}” มีวัตถุดิบที่คุณอาจแพ้',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: bodyF, height: 1.4),
              ),
              SizedBox(height: padV * .3),

              /* ── badge รายชื่อวัตถุดิบ (Wrap ป้องกันล้นแนวกว้าง) ── */
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(badgePad),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  runSpacing: badgePad * .4,
                  spacing: badgePad * .4,
                  children: badIngredientNames
                      .map((n) => Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: badgePad * .8,
                                vertical: badgePad * .4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              n,
                              style: TextStyle(
                                fontSize: badgeF,
                                fontWeight: FontWeight.w600,
                                color: Colors.redAccent,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
              SizedBox(height: padV),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(
                            vertical: clamp(w * .035, 12, 18)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text('ยกเลิก',
                          style: TextStyle(
                              fontSize: buttonF, color: Colors.grey.shade700)),
                    ),
                  ),
                  SizedBox(width: padH * .5),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(
                            vertical: clamp(w * .035, 12, 18)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        onConfirm(recipe);
                      },
                      child: Text('เปิดดู',
                          style: TextStyle(
                              fontSize: buttonF, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
