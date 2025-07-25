// lib/screens/ingredient_filter_screen.dart
// --------------------------------------------------------------
// ★ 2025-07-19 – refactor: ใช้ Theme, ปรับปรุง State Initialization ★
//   • รื้อระบบ Manual Responsive Calculation ทิ้งทั้งหมด
//   • ใช้ Theme ส่วนกลางในการกำหนดสไตล์และสีทั้งหมด
//   • รวมการโหลดข้อมูลเริ่มต้น (Login Status, Allergies) ไว้ใน Future เดียว
//   • จัดระเบียบ Widget Helpers ให้สะอาดและพึ่งพา Theme
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
    super.key,
    this.initialInclude,
    this.initialExclude,
    this.initialIngredients,
  });

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

  // ✅ 1. ใช้ Future เดียวในการจัดการสถานะการโหลดข้อมูลเริ่มต้น
  late final Future<void> _initFuture;

  /* ─── Lifecycle ─────────────────────────────────────────── */
  @override
  void initState() {
    super.initState();
    _initFuture = _initialize();
  }

  Future<void> _initialize() async {
    // รวมค่าที่ส่งมา
    if (widget.initialInclude != null) {
      _haveSet.addAll(widget.initialInclude!.map((e) => e.trim()));
    } else if (widget.initialIngredients != null) {
      _haveSet.addAll(widget.initialIngredients!.map((e) => e.trim()));
    }
    if (widget.initialExclude != null) {
      _notHaveSet.addAll(widget.initialExclude!.map((e) => e.trim()));
    }

    // โหลดข้อมูลที่จำเป็นพร้อมกัน
    final results = await Future.wait([
      AuthService.isLoggedIn(),
      AuthService.getUserAllergies(),
    ]);

    if (!mounted) return;
    setState(() {
      _isLoggedIn = results[0] as bool;
      final allergyList = results[1] as List<String>;
      _allergySet.clear();
      _allergySet.addAll(allergyList);
    });
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
        _notHaveSet.clear();
      });

  /* ★ helper: pop พร้อมเซ็ตปัจจุบัน */
  void _popWithResult() =>
      Navigator.pop(context, [_haveSet.toList(), _notHaveSet.toList()]);

  /* ─── Build Method ──────────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    // ✅ 2. ลบ Manual Responsive Calculation ทั้งหมด และใช้ Theme แทน
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final totalFilters = _haveSet.length + _notHaveSet.length;

    return WillPopScope(
      onWillPop: () async {
        _popWithResult();
        return false;
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _popWithResult,
          ),
          title: const Text('ค้นหาด้วยวัตถุดิบ'),
          // actions ถูกกำหนด style จาก theme หลักแล้ว
        ),
        bottomNavigationBar: CustomBottomNav(
          selectedIndex: 1, // Explore Tab
          onItemSelected: (i) {
            if (i == 1) return;
            // ใช้ named route เพื่อกลับหน้าหลัก
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/home', (route) => false);
          },
        ),
        body: FutureBuilder(
          future: _initFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Section: "มีวัตถุดิบ" ---
                    Text('แสดงสูตรที่มี:',
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildTypeAheadBox(
                      controller: _haveCtrl,
                      hint: 'พิมพ์ชื่อวัตถุดิบที่มี',
                      onAdd: _addHave,
                    ),
                    const SizedBox(height: 12),
                    _buildChipsWrap(
                        _haveSet, _removeHave, theme.colorScheme.primary),
                    const SizedBox(height: 24),

                    // --- Section: "ไม่มีวัตถุดิบ" ---
                    Text('แสดงสูตรที่ไม่มี:',
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildTypeAheadBox(
                      controller: _notHaveCtrl,
                      hint: 'พิมพ์ชื่อวัตถุดิบเพื่อยกเว้น',
                      onAdd: _addNotHave,
                    ),
                    const SizedBox(height: 12),
                    _buildChipsWrap(_notHaveSet, _removeNotHave,
                        theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 32),

                    // --- Section: Buttons ---
                    Center(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.delete_sweep_outlined),
                            label: const Text('ลบตัวกรองทั้งหมด'),
                            onPressed: _clearAll,
                            style: TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _popWithResult,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 48, vertical: 16),
                            ),
                            child: Text('ใช้ตัวกรอง ($totalFilters)'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /* ─── UI Components ───────────────────────────────────────── */
  /// ✅ 3. Refactor Component Helpers ให้สะอาดและใช้ Theme
  Widget _buildTypeAheadBox({
    required TextEditingController controller,
    required String hint,
    required void Function(String) onAdd,
  }) {
    return Row(
      children: [
        Expanded(
          child: TypeAheadField<String>(
            suggestionsCallback: ApiService.getIngredientSuggestions,
            debounceDuration: const Duration(milliseconds: 300),
            builder: (ctx, textController, focusNode) => TextField(
              controller: textController,
              focusNode: focusNode,
              decoration: InputDecoration(hintText: hint),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) onAdd(value);
                textController.clear();
              },
            ),
            itemBuilder: (_, suggestion) => ListTile(title: Text(suggestion)),
            onSelected: (suggestion) {
              onAdd(suggestion);
              controller.clear();
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.camera_alt_outlined),
          tooltip: 'ถ่ายรูปสแกนวัตถุดิบ',
          onPressed: () async {
            final names = await scanIngredient(context);
            if (names != null && names.isNotEmpty) {
              setState(() => onAdd(names.first)); // สมมติว่าเพิ่มทีละรายการ
            }
          },
        ),
      ],
    );
  }

  Widget _buildChipsWrap(
      Set<String> data, void Function(String) onRemove, Color color) {
    if (data.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: data.map((name) {
        final isAllergy = _allergySet.contains(name);
        return Chip(
          label: Text(name),
          labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
          side: BorderSide(color: color),
          backgroundColor:
              Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          deleteIcon: const Icon(Icons.close, size: 16),
          // วัตถุดิบที่แพ้จะลบไม่ได้
          onDeleted: isAllergy ? null : () => onRemove(name),
        );
      }).toList(),
    );
  }
}
