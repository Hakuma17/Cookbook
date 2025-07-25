// lib/screens/ingredient_filter_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

import 'package:cookbook/services/api_service.dart';
import 'package:cookbook/services/auth_service.dart';
import 'package:cookbook/widgets/custom_bottom_nav.dart';

import 'ingredient_photo_screen.dart' show scanIngredient;

class IngredientFilterScreen extends StatefulWidget {
  final List<String>? initialInclude;
  final List<String>? initialExclude;
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
  final Set<String> _allergySet = {};

  bool _isLoggedIn = false; // ★ มี state นี้อยู่แล้ว ยอดเยี่ยม!
  final _haveCtrl = TextEditingController();
  final _notHaveCtrl = TextEditingController();

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
      _isLoggedIn = results[0] as bool; // ★ มีการดึงข้อมูลสถานะอยู่แล้ว
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

  void _popWithResult() =>
      Navigator.pop(context, [_haveSet.toList(), _notHaveSet.toList()]);

  // ★ 1. [แก้ไข] สร้างฟังก์ชันสำหรับจัดการการนำทางโดยเฉพาะ
  void _onNavItemTapped(int index) {
    if (index == 1) return; // หน้าปัจจุบัน ไม่ต้องทำอะไร

    switch (index) {
      case 0:
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
        break;
      case 2:
        Navigator.pushNamedAndRemoveUntil(context, '/my_recipes', (_) => false);
        break;
      case 3:
        final route = _isLoggedIn ? '/profile' : '/settings';
        Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
        break;
    }
  }

  /* ─── Build Method ──────────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
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
        ),
        // ★ 2. [แก้ไข] ส่งค่า `isLoggedIn` เข้าไป และเรียกใช้ฟังก์ชันใหม่
        bottomNavigationBar: CustomBottomNav(
          selectedIndex: 1,
          onItemSelected: _onNavItemTapped,
          isLoggedIn: _isLoggedIn,
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
              setState(() => onAdd(names.first));
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
          onDeleted: isAllergy ? null : () => onRemove(name),
        );
      }).toList(),
    );
  }
}
