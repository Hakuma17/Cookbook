// lib/screens/ingredient_filter_screen.dart

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
      if (mounted) setState(() => _isLoggedIn = ok);
    });

    AuthService.getUserAllergies().then((list) {
      if (!mounted) return;
      setState(() {
        _allergySet.addAll(list);
        _notHaveSet.addAll(list);
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
        _notHaveSet
          ..clear()
          ..addAll(_allergySet);
      });

  /* ★ helper: pop พร้อมเซ็ตปัจจุบัน */
  void _popWithResult() {
    Navigator.pop(context, [_haveSet.toList(), _notHaveSet.toList()]);
  }

  /* ─── UI ─────────────────────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    const brandOrange = Color(0xFFFF9B05);
    const dangerRed = Color(0xFFFF6F6F);

    return WillPopScope(
      onWillPop: () async {
        _popWithResult();
        return false; // block default pop
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: _popWithResult, // ★
          ),
          centerTitle: true,
          title: const Text('ค้นหาสูตร',
              style: TextStyle(
                  color: Color(0xFF0F2930),
                  fontSize: 24,
                  fontWeight: FontWeight.w700)),
          actions: [
            Tooltip(
              triggerMode: TooltipTriggerMode.tap,
              message: '• พิมพ์สั้น ๆ เช่น “กุ้ง” ระบบจะค้นทุกชนิดที่มีคำนี้\n'
                  '• ถ้าพิมพ์ตรงกับชื่อวัตถุดิบ จะใช้ id ตรง ๆ เพื่อความแม่นยำ\n'
                  '• จัดอันดับเมนูที่มีวัตถุดิบครบที่สุดก่อน',
              child: const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.help_outline, color: Colors.black),
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- include ---
                const Text('แสดงสูตรที่มี:',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _typeAheadBox(
                  controller: _haveCtrl,
                  hint: 'พิมพ์ชื่อวัตถุดิบที่มี',
                  onScan: () async {
                    final n = await scanIngredient(context);
                    if (n != null && n.isNotEmpty) {
                      setState(() => _haveSet.addAll(n));
                    }
                  },
                  onSuggestionSelected: _addHave,
                ),
                const SizedBox(height: 8),
                _chipsWrap(_haveSet, _removeHave, brandOrange),

                const SizedBox(height: 24),

                // --- exclude ---
                const Text('แสดงสูตรที่ไม่มี:',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _typeAheadBox(
                  controller: _notHaveCtrl,
                  hint: 'พิมพ์ชื่อวัตถุดิบเพื่อยกเว้น',
                  onScan: () async {
                    final n = await scanIngredient(context);
                    if (n != null && n.isNotEmpty) {
                      setState(() => _notHaveSet.addAll(n));
                    }
                  },
                  onSuggestionSelected: _addNotHave,
                ),
                const SizedBox(height: 8),
                _chipsWrap(_notHaveSet, _removeNotHave, Colors.grey.shade700),

                const SizedBox(height: 32),

                // --- buttons ---
                Center(
                  child: Column(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: dangerRed,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 14),
                        ),
                        onPressed: _clearAll,
                        child: const Text('ลบตัวกรองทั้งหมด',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandOrange,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 48, vertical: 16),
                        ),
                        onPressed: _popWithResult, // ★
                        child: Text(
                          'ใช้ตัวกรอง (${_haveSet.length + _notHaveSet.length})',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
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
                filled: true,
                fillColor: const Color(0xFFF6F6F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (v) {
                onSuggestionSelected(v);
                txt.clear();
              },
            ),
            itemBuilder: (_, s) => ListTile(title: Text(s)),
            onSelected: (s) {
              onSuggestionSelected(s);
              controller.clear();
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.qr_code_scanner, size: 28),
          onPressed: onScan,
        ),
      ],
    );
  }

  Widget _chipsWrap(
    Set<String> data,
    void Function(String) onRemove,
    Color borderColor,
  ) =>
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: data
            .map((n) => Chip(
                  label: Text(n,
                      style: TextStyle(
                          color: borderColor, fontWeight: FontWeight.w600)),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: _allergySet.contains(n) ? null : () => onRemove(n),
                  backgroundColor: const Color(0xFFEAEAEA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: borderColor),
                  ),
                ))
            .toList(),
      );
}
