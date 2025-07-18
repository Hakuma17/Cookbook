// lib/screens/ingredient_filter_screen.dart
// --------------------------------------------------------------
// Responsive-tuned 2025-07-xx  ♦ safe-clamp + overflow-proof
// 2025-07-15 ★ CHG: no auto-fill allergy chips                ←
// --------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

import 'package:cookbook/services/api_service.dart';
import 'package:cookbook/services/auth_service.dart';
import 'package:cookbook/widgets/custom_bottom_nav.dart';

import 'ingredient_photo_screen.dart' show scanIngredient;

class IngredientFilterScreen extends StatefulWidget {
  /// 🎯 ใหม่: ส่งค่าเริ่มต้นเข้ามาแยก “มี / ไม่มี”
  final List<String>? initialInclude;
  final List<String>? initialExclude;

  // legacy (include ทั้งก้อน)
  final List<String>? initialIngredients;

  const IngredientFilterScreen({
    Key? key,
    this.initialInclude,
    this.initialExclude,
    this.initialIngredients,
  }) : super(key: key);

  @override
  State<IngredientFilterScreen> createState() => _IngredientFilterScreenState();
}

class _IngredientFilterScreenState extends State<IngredientFilterScreen> {
  /* ─── State ──────────────────────────────────────────────── */
  final Set<String> _haveSet = {};
  final Set<String> _notHaveSet = {};
  final Set<String> _allergySet = {}; // hidden (exclude only)

  bool _isLoggedIn = false;
  final _haveCtrl = TextEditingController();
  final _notHaveCtrl = TextEditingController();

  /* ─── Lifecycle ─────────────────────────────────────────── */
  @override
  void initState() {
    super.initState();

    AuthService.isLoggedIn().then((ok) {
      if (!mounted) return;
      setState(() => _isLoggedIn = ok);
    });

    AuthService.getUserAllergies().then((list) {
      if (!mounted) return;
      setState(() {
        _allergySet
          ..clear()
          ..addAll(list); // ★ แค่เก็บไว้ ไม่ใส่ _notHaveSet แล้ว
      });
    });

    // รวมค่าที่ส่งมา
    if (widget.initialInclude != null) {
      _haveSet.addAll(widget.initialInclude!.map((e) => e.trim()));
    } else if (widget.initialIngredients != null) {
      _haveSet.addAll(widget.initialIngredients!.map((e) => e.trim()));
    }
    if (widget.initialExclude != null) {
      _notHaveSet.addAll(widget.initialExclude!.map((e) => e.trim()));
    }
  }

  @override
  void dispose() {
    _haveCtrl.dispose();
    _notHaveCtrl.dispose();
    super.dispose();
  }

  /* ─── Helpers ────────────────────────────────────────────── */
  void _addHave(String n) => setState(() => _haveSet.add(n.trim()));
  void _addNotHave(String n) => setState(() => _notHaveSet.add(n.trim()));

  void _removeHave(String n) => setState(() => _haveSet.remove(n));
  void _removeNotHave(String n) => setState(() => _notHaveSet.remove(n));

  void _clearAll() => setState(() {
        _haveSet.clear();
        _notHaveSet.clear(); // ★ ไม่เติม allergy อีกต่อไป
      });

  /* ★ helper: pop พร้อมเซ็ตปัจจุบัน */
  void _popWithResult() =>
      Navigator.pop(context, [_haveSet.toList(), _notHaveSet.toList()]);

  /* ─── UI (เหมือนเดิมทุกบรรทัด ยกเว้นแค่เพิ่ม ★ คอมเมนต์) ───── */
  @override
  Widget build(BuildContext context) {
    /* –– responsive metrics –– */
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final h = media.size.height;
    double clamp(double v, double min, double max) =>
        v < min ? min : (v > max ? max : v);

    final padH = clamp(w * 0.06, 20, 36); // ซ้าย-ขวา
    final padV = clamp(h * 0.023, 14, 26);
    final sectSpace = clamp(h * 0.015, 6, 20);
    final titleFont = clamp(w * 0.060, 20, 28);
    final labelFont = clamp(w * 0.045, 14, 22);
    final chipFont = clamp(w * 0.040, 12, 18);
    final chipSpacing = clamp(w * 0.020, 6, 14);
    final chipRadius = clamp(w * 0.045, 14, 24);
    final scanIconSz = clamp(w * 0.070, 24, 32);
    final btnRadius = clamp(w * 0.045, 16, 24);
    final btnPadH = clamp(w * 0.130, 28, 48);
    final btnPadV = clamp(h * 0.022, 10, 20);
    final applyPadH = clamp(w * 0.190, 40, 64);
    final applyPadV = clamp(h * 0.025, 12, 24);
    final applyFont = clamp(w * 0.050, 16, 22);

    const brandOrange = Color(0xFFFF9B05);
    const dangerRed = Color(0xFFFF6F6F);

    return WillPopScope(
      onWillPop: () async {
        _popWithResult();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, size: scanIconSz, color: Colors.black),
            onPressed: _popWithResult,
          ),
          centerTitle: true,
          title: Text(
            'ค้นหาสูตร',
            style: TextStyle(
              color: const Color(0xFF0F2930),
              fontSize: titleFont,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            Tooltip(
              triggerMode: TooltipTriggerMode.tap,
              message: '''
• พิมพ์ชื่อวัตถุดิบ → เพิ่ม chip
• แตะ ✕ เพื่อลบ
• กด 📷 สแกนวัตถุดิบ
• ลบทั้งหมด → รีเซ็ต
• ใช้ตัวกรอง (N) → ค้นสูตร''',
              child: Padding(
                padding: EdgeInsets.only(right: padH * .3),
                child: Icon(Icons.help_outline,
                    size: scanIconSz, color: Colors.black),
              ),
            ),
          ],
        ),
        bottomNavigationBar: CustomBottomNav(
          selectedIndex: 1,
          isLoggedIn: _isLoggedIn,
          onItemSelected: (i) {
            if (i == 1) return;
            // … (ตรรกะเดิม) …
          },
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                //---------------- include ----------------
                Text('แสดงสูตรที่มี:',
                    style: TextStyle(
                        fontSize: labelFont, fontWeight: FontWeight.w700)),
                SizedBox(height: sectSpace),
                _typeAheadBox(
                  controller: _haveCtrl,
                  hint: 'พิมพ์ชื่อวัตถุดิบที่มี',
                  onScan: () async {
                    final n = await scanIngredient(context);
                    if (n != null && n.isNotEmpty)
                      setState(() => _haveSet.addAll(n));
                  },
                  onSuggestionSelected: _addHave,
                  hintFont: labelFont * .9,
                  borderRadius: chipRadius,
                  fillColor: const Color(0xFFF6F6F6),
                  padH: padH * .25,
                  padV: padV * .7,
                  scanIconSize: scanIconSz,
                ),
                SizedBox(height: sectSpace),
                _chipsWrap(_haveSet, _removeHave, brandOrange, chipFont,
                    chipSpacing, chipRadius),
                SizedBox(height: padV * 1.5),

                //---------------- exclude ----------------
                Text('แสดงสูตรที่ไม่มี:',
                    style: TextStyle(
                        fontSize: labelFont, fontWeight: FontWeight.w700)),
                SizedBox(height: sectSpace),
                _typeAheadBox(
                  controller: _notHaveCtrl,
                  hint: 'พิมพ์ชื่อวัตถุดิบเพื่อยกเว้น',
                  onScan: () async {
                    final n = await scanIngredient(context);
                    if (n != null && n.isNotEmpty)
                      setState(() => _notHaveSet.addAll(n));
                  },
                  onSuggestionSelected: _addNotHave,
                  hintFont: labelFont * .9,
                  borderRadius: chipRadius,
                  fillColor: const Color(0xFFF6F6F6),
                  padH: padH * .25,
                  padV: padV * .7,
                  scanIconSize: scanIconSz,
                ),
                SizedBox(height: sectSpace),
                _chipsWrap(_notHaveSet, _removeNotHave, Colors.grey.shade700,
                    chipFont, chipSpacing, chipRadius),
                SizedBox(height: padV * 2),

                //---------------- buttons ----------------
                Center(
                  child: Column(
                    children: [
                      _actionBtn(
                        label: 'ลบตัวกรองทั้งหมด',
                        bg: dangerRed,
                        onTap: _clearAll,
                        radius: btnRadius,
                        padH: btnPadH,
                        padV: btnPadV,
                        font: chipFont,
                      ),
                      SizedBox(height: sectSpace * 1.5),
                      _actionBtn(
                        label:
                            'ใช้ตัวกรอง (${_haveSet.length + _notHaveSet.length})',
                        bg: brandOrange,
                        onTap: _popWithResult,
                        radius: btnRadius,
                        padH: applyPadH,
                        padV: applyPadV,
                        font: applyFont,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /* ─── Components ───────────────────────────────────────── */
  Widget _typeAheadBox({
    required TextEditingController controller,
    required String hint,
    required VoidCallback onScan,
    required void Function(String) onSuggestionSelected,
    required double hintFont,
    required double borderRadius,
    required Color fillColor,
    required double padH,
    required double padV,
    required double scanIconSize,
  }) {
    return Row(
      children: [
        Expanded(
          child: TypeAheadField<String>(
            suggestionsCallback: ApiService.getIngredientSuggestions,
            debounceDuration: const Duration(milliseconds: 300),
            hideOnEmpty: true,
            hideOnLoading: true,
            hideOnError: true,
            builder: (ctx, txt, focus) => TextField(
              controller: txt,
              focusNode: focus,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(fontSize: hintFont),
                filled: true,
                fillColor: fillColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: padH, vertical: padV),
              ),
              onSubmitted: (v) {
                onSuggestionSelected(v);
                txt.clear();
              },
            ),
            itemBuilder: (_, s) =>
                ListTile(title: Text(s, style: TextStyle(fontSize: hintFont))),
            onSelected: (s) {
              onSuggestionSelected(s);
              controller.clear();
            },
          ),
        ),
        SizedBox(width: padH * .3),
        IconButton(
          icon: Icon(Icons.camera_alt, size: scanIconSize),
          tooltip: 'ถ่ายรูปสแกนวัตถุดิบ',
          onPressed: onScan,
        ),
      ],
    );
  }

  Widget _chipsWrap(
    Set<String> data,
    void Function(String) onRemove,
    Color borderColor,
    double fontSize,
    double spacing,
    double radius,
  ) =>
      Wrap(
        spacing: spacing,
        runSpacing: spacing * .5,
        children: data
            .map((n) => Chip(
                  label: Text(n,
                      style: TextStyle(
                          color: borderColor,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600)),
                  deleteIcon: Icon(Icons.close, size: fontSize * .9),
                  onDeleted: _allergySet.contains(n) ? null : () => onRemove(n),
                  backgroundColor: const Color(0xFFEAEAEA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radius),
                    side: BorderSide(color: borderColor),
                  ),
                ))
            .toList(),
      );

  /* ─── small helpers ────────────────────────────────────── */
  Widget _actionBtn({
    required String label,
    required Color bg,
    required VoidCallback onTap,
    required double radius,
    required double padH,
    required double padV,
    required double font,
  }) =>
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius)),
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        ),
        onPressed: onTap,
        child: Text(label,
            style: TextStyle(fontSize: font, fontWeight: FontWeight.bold)),
      );
}
