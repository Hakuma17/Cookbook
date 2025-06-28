import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

import 'package:cookbook/services/api_service.dart';
import 'package:cookbook/services/auth_service.dart';
import 'package:cookbook/widgets/custom_bottom_nav.dart';

import 'ingredient_photo_screen.dart' show scanIngredient;
import 'search_screen.dart';

class IngredientFilterScreen extends StatefulWidget {
  final List<String>? initialIngredients;

  const IngredientFilterScreen({Key? key, this.initialIngredients})
      : super(key: key);

  @override
  State<IngredientFilterScreen> createState() => _IngredientFilterScreenState();
}

class _IngredientFilterScreenState extends State<IngredientFilterScreen> {
  /* ─── State ──────────────────────────────────────────────── */
  final Set<String> _haveSet = {}; // ต้อง “มี”
  final Set<String> _notHaveSet = {}; // ต้อง “ไม่มี”
  final Set<String> _allergySet = {}; // จากโปรไฟล์ (ใช้แค่ exclude - ไม่โชว์)

  bool _isLoggedIn = false;

  final TextEditingController _haveCtrl = TextEditingController();
  final TextEditingController _notHaveCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();

    /// 1) สถานะล็อกอิน
    AuthService.isLoggedIn().then((v) {
      if (mounted) setState(() => _isLoggedIn = v);
    });

    /// 2) รายการแพ้จากโปรไฟล์ → ใส่ exclude อัตโนมัติ
    AuthService.getUserAllergies().then((list) {
      if (!mounted) return;
      setState(() {
        _allergySet.addAll(list);
        _notHaveSet.addAll(list);
      });
    });

    /// 3) initial (ถ้ามี)
    if (widget.initialIngredients != null) {
      _haveSet.addAll(widget.initialIngredients!
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty));
    }
  }

  @override
  void dispose() {
    _haveCtrl.dispose();
    _notHaveCtrl.dispose();
    super.dispose();
  }

  /* ─── Helper ─────────────────────────────────────────────── */
  void _addHave(String n) {
    final s = n.trim();
    if (s.isNotEmpty && !_haveSet.contains(s)) {
      setState(() => _haveSet.add(s));
    }
  }

  void _addNotHave(String n) {
    final s = n.trim();
    if (s.isNotEmpty && !_notHaveSet.contains(s)) {
      setState(() => _notHaveSet.add(s));
    }
  }

  void _removeHave(String n) => setState(() => _haveSet.remove(n));
  void _removeNotHave(String n) => setState(() => _notHaveSet.remove(n));

  void _clearAll() => setState(() {
        _haveSet.clear();
        _notHaveSet
          ..clear()
          ..addAll(_allergySet); // ไม่ให้ผู้ใช้ลบแพ้ออกจาก filter
      });

  /* ─── Scan camera ───────────────────────────────────────── */
  Future<void> _scanForHave() async {
    final names = await scanIngredient(context);
    if (names != null && names.isNotEmpty) {
      setState(() => _haveSet.addAll(names));
    }
  }

  Future<void> _scanForNotHave() async {
    final names = await scanIngredient(context);
    if (names != null && names.isNotEmpty) {
      setState(() => _notHaveSet.addAll(names));
    }
  }

  /* ─── Search action ─────────────────────────────────────── */
  void _searchRecipes() {
    if (_haveSet.isEmpty && _notHaveSet.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเพิ่มวัตถุดิบอย่างน้อย 1 รายการ')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          ingredients: _haveSet.toList(),
          excludeIngredients: _notHaveSet.toList(),
        ),
      ),
    );
  }

  /* ─── Bottom-nav handler ────────────────────────────────── */
  void _onNav(int i) {
    if (i == 1) return;
    switch (i) {
      case 0:
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/my_recipes', arguments: 0);
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

  /* ─── UI ─────────────────────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    const brandOrange = Color(0xFFFF9B05);
    const dangerRed = Color(0xFFFF6F6F);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text('ค้นหาสูตร',
            style: TextStyle(
                color: Color(0xFF0F2930),
                fontSize: 24,
                fontWeight: FontWeight.w700)),

        /// (i) tooltip อธิบายหลักการกรอง
        actions: [
          Tooltip(
            triggerMode: TooltipTriggerMode.tap,
            message: '• เว้นวรรค 2 ครั้ง เพื่อคั่นหลายคำ\n'
                '• พิมพ์สั้น ๆ เช่น “กุ้ง” ระบบจะค้นทุกชนิดที่มีคำนี้\n'
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
        onItemSelected: _onNav,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// HAVE
              const Text('แสดงสูตรที่มี:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _typeAheadBox(
                controller: _haveCtrl,
                hint: 'พิมพ์ชื่อวัตถุดิบที่มี',
                onScan: _scanForHave,
                onSuggestionSelected: _addHave,
              ),
              const SizedBox(height: 8),
              _chipsWrap(_haveSet, _removeHave, brandOrange),

              const SizedBox(height: 24),

              /// EXCLUDE
              const Text('แสดงสูตรที่ไม่มี:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _typeAheadBox(
                controller: _notHaveCtrl,
                hint: 'พิมพ์ชื่อวัตถุดิบเพื่อยกเว้น',
                onScan: _scanForNotHave,
                onSuggestionSelected: _addNotHave,
              ),
              const SizedBox(height: 8),
              _chipsWrap(_notHaveSet, _removeNotHave, Colors.grey.shade700),

              const SizedBox(height: 32),

              /// ACTION BTNS
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
                      onPressed: _searchRecipes,
                      child: Text(
                        'แสดง ${_haveSet.length + _notHaveSet.length} สูตร',
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
    );
  }

  /* ─── Components ─────────────────────────────────────────── */
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
            builder: (ctx, txt, focus) {
              // **ไม่ sync controller เพื่อไม่ลบค่าที่พิมพ์**
              return TextField(
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
              );
            },
            itemBuilder: (_, s) => ListTile(title: Text(s)),
            onSelected: (s) {
              onSuggestionSelected(s);
              controller.clear();
            },
            debounceDuration: const Duration(milliseconds: 300),
            hideOnEmpty: true,
            hideOnError: true,
            hideOnLoading: true,
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
                  onDeleted: () => onRemove(n),
                  backgroundColor: const Color(0xFFEAEAEA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: borderColor),
                  ),
                ))
            .toList(),
      );
}
