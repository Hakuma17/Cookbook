// lib/screens/ingredient_filter_screen.dart
//
//   รวมคอมเมนต์เดิม + คอมเมนต์ใหม่ (ทำเครื่องหมายด้วย ★ NEW)
// ประเด็นที่แก้:
// - ★ NEW ใส่ key ให้แต่ละ TypeAhead เพื่อให้ instance แยกกันจริง ๆ เวลาเปลี่ยนโหมด (กัน overlay/handler เก่าค้าง)
// - ★ NEW เวลาเลือกจากคำแนะนำ onSelected จะเคลียร์ controller แน่ ๆ และรีโฟกัส (ลดเคสข้อความไม่หาย)
// - ★ NEW เปลี่ยน onSelectionChanged ของสวิตช์โหมด ให้ปิดคีย์บอร์ด/overlay เดิมก่อนสลับ
// - ★ NEW ใน _addGroupTo() ลบรายการในชุด "ชื่อวัตถุดิบ" ที่สะกดเหมือนกลุ่มออก เพื่อลดความสับสนชื่อซ้ำ
// - รองรับค่าเริ่มต้นของ “กลุ่มวัตถุดิบ” (initialIncludeGroups/initialExcludeGroups)

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
  final List<String>? initialIncludeGroups; // ← ใหม่
  final List<String>? initialExcludeGroups; // ← ใหม่

  const IngredientFilterScreen({
    super.key,
    this.initialInclude,
    this.initialExclude,
    this.initialIngredients,
    this.initialIncludeGroups,
    this.initialExcludeGroups,
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
    if (widget.initialIncludeGroups != null) {
      _haveGroupSet.addAll(widget.initialIncludeGroups!
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty));
    }
    if (widget.initialExcludeGroups != null) {
      _notHaveGroupSet.addAll(widget.initialExcludeGroups!
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

      // เอาออกจากชุดกลุ่มฝั่งตรงข้าม
      final toRemove = opposite.firstWhere(
        (e) => _norm(e) == key,
        orElse: () => '',
      );
      if (toRemove.isNotEmpty) {
        opposite.remove(toRemove);
        changed = true;
      }

      // ★ NEW: กันสับสนชื่อซ้ำ — ถ้าชื่อกลุ่มตรงกับ "ชื่อวัตถุดิบ" ที่มีอยู่ ให้ลบออก
      final beforeHave = _haveSet.length;
      _haveSet.removeWhere((e) => _norm(e) == key);
      final removedName1 = beforeHave != _haveSet.length;

      final beforeNotHave = _notHaveSet.length;
      _notHaveSet.removeWhere((e) => _norm(e) == key);
      final removedName2 = beforeNotHave != _notHaveSet.length;
      if (removedName1 || removedName2) changed = true;

      // กันซ้ำใน target (เทียบแบบไม่สนตัวพิมพ์)
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

  /// ส่งค่า  กลับให้หน้าก่อนหน้า
  void _popWithResult() {
    // [OLD] เดิมส่งกลับแค่ 2 ชุด: [_haveSet.toList(), _notHaveSet.toList()]
    // Navigator.pop(context, [_haveSet.toList(), _notHaveSet.toList()]);

    // [NEW] ส่งกลับ 4 ชุด: includeNames, excludeNames, includeGroups, excludeGroups
    // โค้ดเดิมที่อ่าน index 0–1 ยังใช้งานได้เหมือนเดิม
    // ★ ป้องกัน use_build_context_synchronously: จับ Navigator ก่อน
    final nav = Navigator.of(context);
    nav.pop([
      _haveSet.toList(),
      _notHaveSet.toList(),
      _haveGroupSet.toList(),
      _notHaveGroupSet.toList(),
    ]);
  }

  // นำทางล่าง
  void _onNavItemTapped(int index) {
    if (index == 1) return; // หน้าปัจจุบัน
    // ★ ใช้ nav ที่จับไว้ครั้งเดียว
    final nav = Navigator.of(context);
    switch (index) {
      case 0:
        nav.pushNamedAndRemoveUntil('/home', (_) => false);
        break;
      case 2:
        nav.pushNamedAndRemoveUntil('/my_recipes', (_) => false);
        break;
      case 3:
        final route = _isLoggedIn ? '/profile' : '/settings';
        nav.pushNamedAndRemoveUntil(route, (_) => false);
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

  /* ─────────────── Camera handlers (4 ช่อง) ─────────────── */

  // กล้อง: โหมด "ชื่อวัตถุดิบ" → เพิ่มลง include
  Future<void> _onIncludeNameCamera() async {
    final names = await scanIngredient(context);
    if (names.isEmpty) return;
    _addNameTo(_haveSet, _notHaveSet, names.join(','));
    if (!mounted) return;
    // ★ จับ messenger ไว้ก่อนใช้
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text('เพิ่มจากการสแกน: ${names.join(", ")}')),
    );
  }

  // กล้อง: โหมด "ชื่อวัตถุดิบ" → เพิ่มลง exclude
  Future<void> _onExcludeNameCamera() async {
    final names = await scanIngredient(context);
    if (names.isEmpty) return;
    _addNameTo(_notHaveSet, _haveSet, names.join(','));
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text('ยกเว้นจากการสแกน: ${names.join(", ")}')),
    );
  }

  // กล้อง: โหมด "กลุ่มวัตถุดิบ" → สแกนชื่อ → map เป็นกลุ่ม → เพิ่มลง include
  Future<void> _onIncludeGroupCamera() async {
    final names = await scanIngredient(context);
    if (names.isEmpty) return;
    try {
      final groups = await ApiService.mapIngredientsToGroups(names);
      if (groups.isNotEmpty) {
        _addGroupTo(_haveGroupSet, _notHaveGroupSet, groups.join(','));
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(content: Text('เพิ่มกลุ่ม: ${groups.join(", ")}')),
        );
      } else {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          const SnackBar(content: Text('ไม่พบกลุ่มจากภาพที่สแกน')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text('ผิดพลาด: $e')),
      );
    }
  }

  // กล้อง: โหมด "กลุ่มวัตถุดิบ" → สแกนชื่อ → map เป็นกลุ่ม → เพิ่มลง exclude
  Future<void> _onExcludeGroupCamera() async {
    final names = await scanIngredient(context);
    if (names.isEmpty) return;
    try {
      final groups = await ApiService.mapIngredientsToGroups(names);
      if (groups.isNotEmpty) {
        _addGroupTo(_notHaveGroupSet, _haveGroupSet, groups.join(','));
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(content: Text('ยกเว้นกลุ่ม: ${groups.join(", ")}')),
        );
      } else {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          const SnackBar(content: Text('ไม่พบกลุ่มจากภาพที่สแกน')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text('ผิดพลาด: $e')),
      );
    }
  }

  /* ─────────────── Help sheet ─────────────── */

  void _showHelpSheet({required bool isGroupMode}) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final t = Theme.of(ctx).textTheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📝 วิธีกรอกตัวกรอง', style: t.titleLarge),
              const SizedBox(height: 12),
              Text(
                isGroupMode
                    ? 'โหมด “กลุ่มวัตถุดิบ” — พิมพ์ชื่อกลุ่ม เช่น “นมวัว, พริก, อาหารทะเล” (ใส่หลายชื่อคั่น , หรือ ; ได้)'
                    : 'โหมด “ชื่อวัตถุดิบ” — พิมพ์ชื่อวัตถุดิบ เช่น “ใบกะเพรา, กระเทียม, ตะไคร้” (ใส่หลายชื่อคั่น , หรือ ; ได้)',
                style: t.bodyMedium,
              ),
              const SizedBox(height: 8),
              if (isGroupMode)
                Text(
                    'ตัวอย่างชื่อกลุ่ม: นมวัว, พริก, สมุนไพรไทย, อาหารทะเล, เส้นก๋วยเตี๋ยว',
                    style: t.bodySmall),
              const SizedBox(height: 16),
              Text('📷 ทริคการถ่ายรูปให้ทายแม่นยำ', style: t.titleMedium),
              const SizedBox(height: 8),
              const _HelpBullet('วางให้มี “วัตถุดิบเดียว” ชัด ๆ ในภาพ'),
              const _HelpBullet('พื้นหลังเรียบ แสงเพียงพอ ไม่ย้อนแสง'),
              const _HelpBullet('ขนาดภาพ ≥ 224×224 px และไฟล์ ≤ 10MB'),
              const SizedBox(height: 8),
              Text(
                isGroupMode
                    ? 'ในโหมดกลุ่ม ระบบจะ: ถ่ายรูป → รู้ชื่อวัตถุดิบ → แม็ปเป็น “กลุ่ม” ให้อัตโนมัติ'
                    : 'ในโหมดชื่อ ระบบจะ: ถ่ายรูป → รู้ชื่อวัตถุดิบ แล้วเติมลงช่องให้',
                style: t.bodySmall,
              ),
            ],
          ),
        );
      },
    );
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

    // ย้ายไปใช้ PopScope แทน WillPopScope (รองรับ predictive back)
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _popWithResult();
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
                            backgroundColor: theme.colorScheme.tertiaryContainer
                                .withValues(alpha: .3),
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
                      Row(
                        children: [
                          Text('แสดงสูตรที่มี:',
                              style: textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'คู่มือการกรอก',
                            icon: const Icon(Icons.help_outline),
                            onPressed: () =>
                                _showHelpSheet(isGroupMode: _groupMode),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_groupMode)
                        _TypeAheadBox(
                          // ★ NEW: key เฉพาะ instance (กัน overlay เก่าค้าง)
                          key: const ValueKey('inc-group'),
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
                          // ★ กล้องโหมดกลุ่ม: ถ่าย→map→เติมกลุ่ม
                          showCamera: true,
                          onCamera: _onIncludeGroupCamera,
                        )
                      else
                        _TypeAheadBox(
                          key: const ValueKey('inc-name'), // ★ NEW
                          // ชื่อวัตถุดิบ
                          controller: _haveCtrl,
                          focusNode: _haveFocus,
                          hint:
                              'พิมพ์ชื่อวัตถุดิบที่มี (ใส่หลายชื่อคั่น , ; ได้)',
                          suggestionsCallback:
                              ApiService.getIngredientSuggestions,
                          onAdd: (n) => _addNameTo(_haveSet, _notHaveSet, n),
                          showCamera: true,
                          onCamera: _onIncludeNameCamera,
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
                      Row(
                        children: [
                          Text('แสดงสูตรที่ไม่มี:',
                              style: textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'คู่มือการกรอก',
                            icon: const Icon(Icons.help_outline),
                            onPressed: () =>
                                _showHelpSheet(isGroupMode: _groupMode),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_groupMode)
                        _TypeAheadBox(
                          key: const ValueKey('exc-group'), // ★ NEW
                          controller: _notHaveGroupCtrl,
                          focusNode: _notHaveGroupFocus,
                          hint: 'พิมพ์ชื่อกลุ่มวัตถุดิบที่ต้องการยกเว้น',
                          suggestionsCallback: ApiService.getGroupSuggestions,
                          onAdd: (g) => _addGroupTo(
                            _notHaveGroupSet,
                            _haveGroupSet,
                            g,
                          ),
                          // ★ กล้องโหมดกลุ่ม: ถ่าย→map→เติมกลุ่ม (exclude)
                          showCamera: true,
                          onCamera: _onExcludeGroupCamera,
                        )
                      else
                        _TypeAheadBox(
                          key: const ValueKey('exc-name'), // ★ NEW
                          controller: _notHaveCtrl,
                          focusNode: _notHaveFocus,
                          hint: 'พิมพ์ชื่อวัตถุดิบเพื่อยกเว้น',
                          suggestionsCallback:
                              ApiService.getIngredientSuggestions,
                          onAdd: (n) => _addNameTo(_notHaveSet, _haveSet, n),
                          // ★ กล้องครบ 4 ช่อง: โหมดชื่อ (exclude) ก็เปิดกล้องด้วย
                          showCamera: true,
                          onCamera: _onExcludeNameCamera,
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
              // ★ NEW: ปิดคีย์บอร์ด/overlay เดิมก่อนสลับโหมด (กัน state เก่าค้าง)
              if (_groupMode != set.first) {
                _dismissKb();
                setState(() => _groupMode = set.first);
              }
            },
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              padding: WidgetStateProperty.all(
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
      alignment: WrapAlignment.start,
      runAlignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8.0,
      runSpacing: 4.0,
      children: data.map((name) {
        final isAllergy =
            isAllergyAware && _allergySet.any((a) => _norm(a) == _norm(name));

        final chipColor = isAllergy ? allergyColor : color;
        final bg = isAllergy
            ? cs.errorContainer.withValues(alpha: .25)
            : cs.surfaceContainerHighest.withValues(alpha: 0.3);

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
 * - [NEW] รองรับ onCamera (ถ้าส่งมา) เพื่อปรับพฤติกรรมปุ่มกล้องได้ (เช่น mapIngredientsToGroups)
 * - ★ NEW ใส่ super.key เพื่อใช้ ValueKey แยก instance ใน parent
 */
class _TypeAheadBox extends StatelessWidget {
  const _TypeAheadBox({
    super.key, // ★ NEW
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onAdd,
    required this.suggestionsCallback,
    this.showCamera = false,
    this.onCamera, // [NEW]
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final void Function(String) onAdd;

  /// ฟังก์ชันดึงคำแนะนำ (รองรับทั้ง ingredient และ group)
  final Future<List<String>> Function(String) suggestionsCallback;

  /// แสดงปุ่มกล้องหรือไม่ (เฉพาะโหมดชื่อวัตถุดิบหรือกลุ่ม ตามที่ผู้ใช้เลือก)
  final bool showCamera;

  /// [NEW] callback เมื่อกดกล้อง (ถ้าไม่ส่งมา จะ fallback เป็นสแกนแล้วเพิ่มชื่อแรก)
  final Future<void> Function()? onCamera;

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
                if (v.isNotEmpty) {
                  onAdd(v);
                  // เก็บข้อความไว้ต่อ ไม่ clear เพื่อให้แก้ไข/กดค้นหาต่อได้
                  // เลื่อน caret ไปท้ายข้อความ
                  textController.selection = TextSelection.fromPosition(
                    TextPosition(offset: textController.text.length),
                  );
                }
              },
            ),

            // แสดงรายการ
            itemBuilder: (_, s) => ListTile(title: Text(s)),

            // ★ NEW: เคลียร์ให้ชัวร์ และคงโฟกัสเพื่อพิมพ์ต่อได้ทันที
            onSelected: (s) {
              onAdd(s);
              // คงข้อความไว้ และให้โฟกัสอยู่ต่อเพื่อพิมพ์คำถัดไปได้ทันที
              focusNode.requestFocus();
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
        // ปุ่มสแกนด้วยกล้อง (ครบ 4 ช่อง ตาม requirement)
        if (showCamera)
          Semantics(
            button: true,
            label: 'ถ่ายรูปสแกน',
            child: IconButton(
              icon: const Icon(Icons.camera_alt_outlined),
              tooltip: 'ถ่ายรูปสแกน',
              onPressed: () async {
                // ★ ป้องกัน use_build_context_synchronously: จับ messenger ก่อน await
                final messenger = ScaffoldMessenger.of(context);
                if (onCamera != null) {
                  await onCamera!();
                  return;
                }
                // Fallback เดิม: สแกนแล้วเติมชื่อแรก
                final names = await scanIngredient(context);
                if (names.isNotEmpty) {
                  onAdd(names.first);
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
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

/* ───────── Small helper widget ───────── */
class _HelpBullet extends StatelessWidget {
  final String text;
  const _HelpBullet(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
