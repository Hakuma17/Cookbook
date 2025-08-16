// lib/screens/ingredient_filter_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

import 'package:cookbook/services/api_service.dart';
import 'package:cookbook/services/auth_service.dart';
import 'package:cookbook/widgets/custom_bottom_nav.dart';

import 'ingredient_photo_screen.dart' show scanIngredient;

/// หน้าจอเลือกตัวกรองวัตถุดิบเพื่อใช้กับการค้นหา
/// ปรับปรุง:
///  - เพิ่มโหมด "กลุ่มวัตถุดิบ" (categorynew) เพื่อรองรับการแม็ปแบบยืดหยุ่นด้านหลังบ้าน
///  - คงผลลัพธ์แบบเดิม (2 ชุด: include/exclude) และเพิ่มอีก 2 ชุดสำหรับกลุ่ม
///    รูปผลลัพธ์: [includeNames, excludeNames, includeGroups, excludeGroups]
///    เพื่อให้โค้ดฝั่งเรียกใช้งานเดิมยังอ่าน index 0–1 ได้ตามปกติ
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
  /* ───────────────────────── State ───────────────────────── */

  /// ชุดตัวกรองแบบ "ชื่อวัตถุดิบ"
  final Set<String> _haveSet = {};
  final Set<String> _notHaveSet = {};

  /// ชุดตัวกรองแบบ "กลุ่มวัตถุดิบ" (เช่น กุ้งทะเล, นมวัว, เส้นก๋วยเตี๋ยว ฯลฯ)
  final Set<String> _haveGroupSet = {};
  final Set<String> _notHaveGroupSet = {};

  /// รายการวัตถุดิบที่ผู้ใช้แพ้ (รายการเป็น "ชื่อวัตถุดิบ" ตามระบบเดิม)
  final Set<String> _allergySet = {};

  bool _isLoggedIn = false;

  /// ช่องกรอกสำหรับโหมด "ชื่อวัตถุดิบ"
  final _haveCtrl = TextEditingController();
  final _notHaveCtrl = TextEditingController();
  final _haveFocus = FocusNode();
  final _notHaveFocus = FocusNode();

  /// ช่องกรอกสำหรับโหมด "กลุ่มวัตถุดิบ" (ใช้ controller แยกเพื่อไม่ปะปนกับโหมดชื่อ)
  final _haveGroupCtrl = TextEditingController();
  final _notHaveGroupCtrl = TextEditingController();
  final _haveGroupFocus = FocusNode();
  final _notHaveGroupFocus = FocusNode();

  late final Future<void> _initFuture;

  /// โหมดอินพุตปัจจุบันของหน้าจอ: true = กลุ่มวัตถุดิบ, false = ชื่อวัตถุดิบ
  bool _groupMode = false;

  /* ─────────────────────── Lifecycle ─────────────────────── */
  @override
  void initState() {
    super.initState();
    _initFuture = _initialize();
  }

  @override
  void dispose() {
    _haveCtrl.dispose();
    _notHaveCtrl.dispose();
    _haveFocus.dispose();
    _notHaveFocus.dispose();

    _haveGroupCtrl.dispose();
    _notHaveGroupCtrl.dispose();
    _haveGroupFocus.dispose();
    _notHaveGroupFocus.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    // รวมค่าที่ส่งมาเป็นค่าเริ่มต้น (ชื่อวัตถุดิบ)
    if (widget.initialInclude != null) {
      _haveSet.addAll(widget.initialInclude!
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty));
    } else if (widget.initialIngredients != null) {
      _haveSet.addAll(widget.initialIngredients!
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty));
    }
    if (widget.initialExclude != null) {
      _notHaveSet.addAll(widget.initialExclude!
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty));
    }

    // โหลดสถานะล็อกอิน + รายการแพ้อาหาร
    final results = await Future.wait([
      AuthService.isLoggedIn(),
      AuthService.getUserAllergies(), // สมมติคืน List<String> ชื่อวัตถุดิบ
    ]);

    if (!mounted) return;
    setState(() {
      _isLoggedIn = results[0] as bool;
      final allergyList = results[1] as List<String>;
      _allergySet
        ..clear()
        ..addAll(allergyList.map((e) => e.trim()).where((e) => e.isNotEmpty));
    });
  }

  /* ─────────────────────── Helpers ───────────────────────── */

  // normalize เทียบชื่อแบบไม่สนตัวพิมพ์ใหญ่เล็ก
  String _norm(String s) => s.trim().toLowerCase();

  // เพิ่มลงชุด "ชื่อวัตถุดิบ" โดยลบออกจากฝั่งตรงข้ามให้อัตโนมัติ + กันซ้ำแบบ case-insensitive
  void _addNameTo(Set<String> target, Set<String> opposite, String raw) {
    final names = raw
        .split(RegExp(r'[;,]')) // รองรับใส่หลายชื่อคั่นด้วย , ;
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);

    bool changed = false;

    for (final name in names) {
      final key = _norm(name);

      // เอาออกจากอีกฝั่ง ถ้ามีอยู่ (เทียบแบบไม่สนตัวพิมพ์)
      final toRemove = opposite.firstWhere(
        (e) => _norm(e) == key,
        orElse: () => '',
      );
      if (toRemove.isNotEmpty) {
        opposite.remove(toRemove);
        changed = true;
      }

      // กันซ้ำใน target (เทียบแบบไม่สนตัวพิมพ์)
      final exists = target.any((e) => _norm(e) == key);
      if (!exists) {
        target.add(name);
        changed = true;
      }
    }

    if (changed) setState(() {});
  }

  // เพิ่มลงชุด "กลุ่มวัตถุดิบ" (หลักการเดียวกับชื่อ)
  void _addGroupTo(Set<String> target, Set<String> opposite, String raw) {
    final groups = raw
        .split(RegExp(r'[;,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);

    bool changed = false;

    for (final g in groups) {
      final key = _norm(g);

      final toRemove = opposite.firstWhere(
        (e) => _norm(e) == key,
        orElse: () => '',
      );
      if (toRemove.isNotEmpty) {
        opposite.remove(toRemove);
        changed = true;
      }

      final exists = target.any((e) => _norm(e) == key);
      if (!exists) {
        target.add(g);
        changed = true;
      }
    }

    if (changed) setState(() {});
  }

  void _removeFrom(Set<String> set, String name) {
    set.removeWhere((e) => _norm(e) == _norm(name));
    setState(() {});
  }

  void _clearAll() => setState(() {
        _haveSet.clear();
        _notHaveSet.clear();
        _haveGroupSet.clear();
        _notHaveGroupSet.clear();
      });

  /// ส่งค่ากลับให้หน้าก่อนหน้า
  void _popWithResult() {
    // [OLD] เดิมส่งกลับแค่ 2 ชุด: [_haveSet.toList(), _notHaveSet.toList()]
    // Navigator.pop(context, [_haveSet.toList(), _notHaveSet.toList()]);

    // [NEW] ส่งกลับ 4 ชุด: includeNames, excludeNames, includeGroups, excludeGroups
    // โค้ดเดิมที่อ่าน index 0–1 ยังใช้งานได้เหมือนเดิม
    Navigator.pop(context, [
      _haveSet.toList(),
      _notHaveSet.toList(),
      _haveGroupSet.toList(),
      _notHaveGroupSet.toList(),
    ]);
  }

  // นำทางล่าง
  void _onNavItemTapped(int index) {
    if (index == 1) return; // หน้าปัจจุบัน
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

  /// มีวัตถุดิบที่แพ้ แต่ถูกใส่ไว้ใน "มีวัตถุดิบ" (เฉพาะโหมดชื่อวัตถุดิบ)
  bool get _hasAllergyConflict {
    final lowers = _haveSet.map(_norm).toSet();
    return _allergySet.any((a) => lowers.contains(_norm(a)));
  }

  void _dismissKb() {
    _haveFocus.unfocus();
    _notHaveFocus.unfocus();
    _haveGroupFocus.unfocus();
    _notHaveGroupFocus.unfocus();
  }

  /* ─────────────────────── Build ─────────────────────────── */
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // นับจำนวนตัวกรองทั้งหมดเพื่อแสดงบนปุ่ม
    final totalFilters = _haveSet.length +
        _notHaveSet.length +
        _haveGroupSet.length +
        _notHaveGroupSet.length;

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
            tooltip: 'กลับและใช้ตัวกรอง',
          ),
          title: const Text('ค้นหาด้วยวัตถุดิบ'),
        ),
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
              child: GestureDetector(
                onTap: _dismissKb,
                behavior: HitTestBehavior.translucent,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // แถบสลับโหมดอินพุต
                      _buildModeSwitcher(theme),

                      const SizedBox(height: 12),
                      if (_hasAllergyConflict)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: MaterialBanner(
                            backgroundColor:
                                theme.colorScheme.tertiaryContainer.withOpacity(
                              .3,
                            ),
                            content: const Text(
                                'มีวัตถุดิบที่คุณแพ้อยู่ในรายการ “มีวัตถุดิบ”'),
                            actions: [
                              TextButton(
                                onPressed: () {},
                                child: const Text('ปิด'),
                              ),
                            ],
                          ),
                        ),

                      // --- Section: "มีวัตถุดิบ" ---
                      Text('แสดงสูตรที่มี:',
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),

                      if (_groupMode)
                        _TypeAheadBox(
                          // กลุ่มวัตถุดิบ
                          controller: _haveGroupCtrl,
                          focusNode: _haveGroupFocus,
                          hint: 'พิมพ์ชื่อกลุ่มวัตถุดิบ (เช่น กุ้งทะเล, นมวัว)',
                          // ใช้ suggest กลุ่ม
                          suggestionsCallback: ApiService.getGroupSuggestions,
                          onAdd: (g) => _addGroupTo(
                            _haveGroupSet,
                            _notHaveGroupSet,
                            g,
                          ),
                          showCamera: false, // กลุ่มไม่ใช้กล้อง
                        )
                      else
                        _TypeAheadBox(
                          // ชื่อวัตถุดิบ
                          controller: _haveCtrl,
                          focusNode: _haveFocus,
                          hint:
                              'พิมพ์ชื่อวัตถุดิบที่มี (ใส่หลายชื่อคั่น , ; ได้)',
                          suggestionsCallback:
                              ApiService.getIngredientSuggestions,
                          onAdd: (n) => _addNameTo(_haveSet, _notHaveSet, n),
                          showCamera: true,
                        ),

                      const SizedBox(height: 12),

                      // ชิปของ "มีวัตถุดิบ": แยกแสดงตามประเภท
                      if (_haveSet.isNotEmpty || _haveGroupSet.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_haveSet.isNotEmpty) ...[
                              Text('ชื่อวัตถุดิบ',
                                  style: textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              _buildChipsWrap(
                                data: _haveSet,
                                onRemove: (n) => _removeFrom(_haveSet, n),
                                color: theme.colorScheme.primary,
                                allergyColor: theme.colorScheme.error,
                                isAllergyAware: true, // ชื่อเท่านั้นที่เช็กแพ้
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (_haveGroupSet.isNotEmpty) ...[
                              Text('กลุ่มวัตถุดิบ',
                                  style: textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              _buildChipsWrap(
                                data: _haveGroupSet,
                                onRemove: (n) => _removeFrom(_haveGroupSet, n),
                                color: theme.colorScheme.primary,
                                allergyColor: theme.colorScheme.error,
                                isAllergyAware: false,
                              ),
                            ],
                          ],
                        ),

                      const SizedBox(height: 24),

                      // --- Section: "ไม่มีวัตถุดิบ" ---
                      Text('แสดงสูตรที่ไม่มี:',
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),

                      if (_groupMode)
                        _TypeAheadBox(
                          controller: _notHaveGroupCtrl,
                          focusNode: _notHaveGroupFocus,
                          hint: 'พิมพ์ชื่อกลุ่มวัตถุดิบที่ต้องการยกเว้น',
                          suggestionsCallback: ApiService.getGroupSuggestions,
                          onAdd: (g) => _addGroupTo(
                            _notHaveGroupSet,
                            _haveGroupSet,
                            g,
                          ),
                          showCamera: false,
                        )
                      else
                        _TypeAheadBox(
                          controller: _notHaveCtrl,
                          focusNode: _notHaveFocus,
                          hint: 'พิมพ์ชื่อวัตถุดิบเพื่อยกเว้น',
                          suggestionsCallback:
                              ApiService.getIngredientSuggestions,
                          onAdd: (n) => _addNameTo(_notHaveSet, _haveSet, n),
                          showCamera: false,
                        ),

                      const SizedBox(height: 12),

                      // ชิปของ "ไม่มีวัตถุดิบ": แยกแสดงตามประเภท
                      if (_notHaveSet.isNotEmpty || _notHaveGroupSet.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_notHaveSet.isNotEmpty) ...[
                              Text('ชื่อวัตถุดิบ',
                                  style: textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              _buildChipsWrap(
                                data: _notHaveSet,
                                onRemove: (n) => _removeFrom(_notHaveSet, n),
                                color: theme.colorScheme.onSurfaceVariant,
                                allergyColor: theme.colorScheme.error,
                                isAllergyAware: false,
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (_notHaveGroupSet.isNotEmpty) ...[
                              Text('กลุ่มวัตถุดิบ',
                                  style: textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              _buildChipsWrap(
                                data: _notHaveGroupSet,
                                onRemove: (n) =>
                                    _removeFrom(_notHaveGroupSet, n),
                                color: theme.colorScheme.onSurfaceVariant,
                                allergyColor: theme.colorScheme.error,
                                isAllergyAware: false,
                              ),
                            ],
                          ],
                        ),

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
              ),
            );
          },
        ),
      ),
    );
  }

  /* ─────────────────────── UI Parts ─────────────────────── */

  /// สวิตช์เลือกโหมดอินพุตของหน้าจอ
  Widget _buildModeSwitcher(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                label: Text('ตามชื่อวัตถุดิบ'),
                icon: Icon(Icons.label_outline),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text('ตามกลุ่มวัตถุดิบ'),
                icon: Icon(Icons.category_outlined),
              ),
            ],
            selected: {_groupMode},
            onSelectionChanged: (set) {
              setState(() => _groupMode = set.first);
            },
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              padding: MaterialStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 8)),
            ),
          ),
        ),
      ],
    );
  }

  /// แสดงชิปชื่อ/กลุ่มวัตถุดิบ
  Widget _buildChipsWrap({
    required Set<String> data,
    required void Function(String) onRemove,
    required Color color,
    required Color allergyColor,
    required bool isAllergyAware, // true เฉพาะชุด "ชื่อวัตถุดิบ"
  }) {
    if (data.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: data.map((name) {
        final isAllergy =
            isAllergyAware && _allergySet.any((a) => _norm(a) == _norm(name));

        final chipColor = isAllergy ? allergyColor : color;
        final bg = isAllergy
            ? cs.errorContainer.withOpacity(.25)
            : cs.surfaceVariant.withOpacity(0.3);

        final chip = Chip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAllergy) ...[
                const Icon(Icons.warning_amber_rounded, size: 16),
                const SizedBox(width: 4),
              ],
              Text(name),
            ],
          ),
          labelStyle: TextStyle(color: chipColor, fontWeight: FontWeight.w600),
          side: BorderSide(color: chipColor),
          backgroundColor: bg,
          deleteIcon: const Icon(Icons.close, size: 16),
          onDeleted: isAllergy ? null : () => onRemove(name),
        );

        return Semantics(
          label: isAllergy ? 'วัตถุดิบแพ้ $name' : 'วัตถุดิบ $name',
          child: Tooltip(
            message:
                isAllergy ? 'อยู่ในรายการแพ้ — ลบไม่ได้' : 'ลบออกจากตัวกรอง',
            child: chip,
          ),
        );
      }).toList(),
    );
  }
}

/* ───────── TypeAhead box (รับทั้ง "ชื่อวัตถุดิบ" และ "กลุ่มวัตถุดิบ") ─────────
 * - ควบคุมด้วยพารามิเตอร์ suggestionsCallback และ showCamera
 * - เมื่อ submit/เลือก suggestion จะเรียก onAdd แล้วเคลียร์ controller ให้
 */
class _TypeAheadBox extends StatelessWidget {
  const _TypeAheadBox({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onAdd,
    required this.suggestionsCallback,
    this.showCamera = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final void Function(String) onAdd;

  /// ฟังก์ชันดึงคำแนะนำ (รองรับทั้ง ingredient และ group)
  final Future<List<String>> Function(String) suggestionsCallback;

  /// แสดงปุ่มกล้องหรือไม่ (เฉพาะโหมดชื่อวัตถุดิบ)
  final bool showCamera;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TypeAheadField<String>(
            controller: controller,
            suggestionsCallback: suggestionsCallback,
            debounceDuration: const Duration(milliseconds: 300),

            // พฤติกรรมกล่อง suggestion
            hideOnUnfocus: true,
            hideOnEmpty: true,
            hideOnLoading: false,

            // ช่องกรอก
            builder: (ctx, textController, fieldFocus) => TextField(
              controller: textController,
              focusNode: fieldFocus,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: hint,
                suffixIcon: (textController.text.isNotEmpty)
                    ? IconButton(
                        tooltip: 'ล้างข้อความ',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          textController.clear();
                        },
                      )
                    : null,
              ),
              onSubmitted: (value) {
                final v = value.trim();
                if (v.isNotEmpty) onAdd(v);
                textController.clear();
              },
            ),

            // แสดงรายการ
            itemBuilder: (_, s) => ListTile(title: Text(s)),
            onSelected: (s) {
              onAdd(s);
              controller.clear();
            },

            // ว่าง
            emptyBuilder: (_) => const Padding(
              padding: EdgeInsets.all(12),
              child: Text('ไม่พบรายการ'),
            ),

            // กำลังโหลด
            loadingBuilder: (_) => const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),

            // error
            errorBuilder: (_, error) => Padding(
              padding: const EdgeInsets.all(12),
              child: Text('เกิดข้อผิดพลาด: $error'),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // ปุ่มสแกนด้วยกล้อง เฉพาะโหมด "ชื่อวัตถุดิบ"
        if (showCamera)
          Semantics(
            button: true,
            label: 'ถ่ายรูปสแกนวัตถุดิบ',
            child: IconButton(
              icon: const Icon(Icons.camera_alt_outlined),
              tooltip: 'ถ่ายรูปสแกนวัตถุดิบ',
              onPressed: () async {
                final names = await scanIngredient(context);
                if (names != null && names.isNotEmpty) {
                  onAdd(names.first);
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('เพิ่ม "${names.first}" จากการสแกน')),
                  );
                }
              },
            ),
          ),
      ],
    );
  }
}
