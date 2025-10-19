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
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';

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
    print(
        '🔍 _addNameTo called with: "$raw" (โหมด: ${_groupMode ? "กลุ่ม" : "เดี่ยว"})');

    final names = raw
        .split(RegExp(r'[;,]')) // รองรับใส่หลายชื่อคั่นด้วย , ;
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);

    bool changed = false;

    for (final name in names) {
      final key = _norm(name);
      print('   → เพิ่มชื่อวัตถุดิบ: "$name"');

      // เอาออกจากอีกฝั่ง ถ้ามีอยู่ (เทียบแบบไม่สนตัวพิมพ์)
      final toRemove = opposite.firstWhere(
        (e) => _norm(e) == key,
        orElse: () => '',
      );
      if (toRemove.isNotEmpty) {
        print('   → ลบออกจากฝั่งตรงข้าม: "$toRemove"');
        opposite.remove(toRemove);
        changed = true;
      }

      // กันซ้ำใน target (เทียบแบบไม่สนตัวพิมพ์)
      final exists = target.any((e) => _norm(e) == key);
      if (!exists) {
        target.add(name);
        changed = true;
        print('   ✅ เพิ่มแล้ว: "$name"');
      } else {
        print('   ⚠️ มีอยู่แล้ว: "$name"');
      }
    }

    if (changed) setState(() {});
  }

  // เพิ่มลงชุด "กลุ่มวัตถุดิบ" (แยกออกจากชื่อวัตถุดิบเดี่ยวอย่างชัดเจน)
  void _addGroupTo(Set<String> target, Set<String> opposite, String raw) {
    print(
        '🏷️ _addGroupTo called with: "$raw" (โหมด: ${_groupMode ? "กลุ่ม" : "เดี่ยว"})');

    final groups = raw
        .split(RegExp(r'[;,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);

    bool changed = false;

    for (final g in groups) {
      final key = _norm(g);
      print('   → เพิ่มกลุ่ม: "$g"');

      // เอาออกจากชุดกลุ่มฝั่งตรงข้าม
      final toRemove = opposite.firstWhere(
        (e) => _norm(e) == key,
        orElse: () => '',
      );
      if (toRemove.isNotEmpty) {
        print('   → ลบกลุ่มออกจากฝั่งตรงข้าม: "$toRemove"');
        opposite.remove(toRemove);
        changed = true;
      }

      // ★ REMOVED: ไม่ลบชื่อวัตถุดิบเดี่ยวออกอีกต่อไป เพื่อให้ผู้ใช้เลือกได้ทั้ง 2 แบบ
      // เดิม: ลบชื่อวัตถุดิบที่ซ้ำกับกลุ่ม -> ทำให้เกิดความสับสน

      // กันซ้ำใน target (เทียบแบบไม่สนตัวพิมพ์)
      final exists = target.any((e) => _norm(e) == key);
      if (!exists) {
        target.add(g);
        changed = true;
        print('   ✅ เพิ่มกลุ่มแล้ว: "$g"');
      } else {
        print('   ⚠️ มีกลุ่มอยู่แล้ว: "$g"');
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
    // ปิด focus nodes ทั้งหมด
    _haveFocus.unfocus();
    _notHaveFocus.unfocus();
    _haveGroupFocus.unfocus();
    _notHaveGroupFocus.unfocus();

    // ปิด keyboard ใน context ปัจจุบัน
    FocusScope.of(context).unfocus();
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
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final t = theme.textTheme;
        final cs = theme.colorScheme;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // หัวข้อหลัก
                Row(
                  children: [
                    Icon(Icons.help_outline, color: cs.primary, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'คู่มือการใช้ตัวกรองวัตถุดิบ',
                        style: t.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // โหมดปัจจุบัน
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isGroupMode ? Icons.category : Icons.inventory_2,
                            color: cs.onPrimaryContainer,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'โหมดปัจจุบัน: ${isGroupMode ? "กลุ่มวัตถุดิบ" : "ชื่อวัตถุดิบ"}',
                            style: t.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isGroupMode
                            ? 'โหมดกลุ่มวัตถุดิบ: ใช้ชื่อ “กลุ่ม” เพื่อค้นหาเมนูที่มีหรือไม่มีวัตถุดิบในกลุ่มนั้น'
                            : 'โหมดชื่อวัตถุดิบ: ใช้ชื่อวัตถุดิบรายตัวเพื่อคัดกรองเมนู',
                        style: t.bodyMedium
                            ?.copyWith(color: cs.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // หน้าที่ของหน้านี้
                Row(
                  children: [
                    Icon(Icons.tune, color: cs.secondary),
                    const SizedBox(width: 8),
                    Text('หน้าที่ของหน้านี้',
                        style: t.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                const _HelpBullet(
                    'คัดกรองสูตรอาหารจากวัตถุดิบที่ “ต้องมี” หรือ “ต้องไม่มี”'),
                const _HelpBullet(
                    'สลับได้ระหว่าง โหมดชื่อวัตถุดิบ และ โหมดกลุ่มวัตถุดิบ'),
                const _HelpBullet(
                    'แก้ไข/ลบรายการที่เพิ่มแล้วได้ โดยแตะที่ชิปหรือปุ่ม ×'),
                const SizedBox(height: 16),

                // วิธีการกรอกข้อมูล
                Row(
                  children: [
                    Icon(Icons.keyboard, color: cs.secondary),
                    const SizedBox(width: 8),
                    Text('การพิมพ์ตัวกรอง',
                        style: t.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isGroupMode
                      ? 'พิมพ์ชื่อกลุ่ม เช่น “นมวัว, พริก, อาหารทะเล” (ใส่หลายรายการคั่นด้วย , หรือ ;)'
                      : 'พิมพ์ชื่อวัตถุดิบ เช่น “ใบกะเพรา, กระเทียม, ตะไคร้” (ใส่หลายรายการคั่นด้วย , หรือ ;)',
                  style: t.bodyMedium,
                ),
                const SizedBox(height: 6),
                const _HelpBullet(
                    'เลือกจากรายชื่อแนะนำเพื่อหลีกเลี่ยงการสะกดผิด'),
                const _HelpBullet('กด Enter เพื่อเพิ่มจากข้อความที่พิมพ์'),
                if (!isGroupMode)
                  const _HelpBullet(
                      'ถ้ารายการนั้นอยู่ใน “วัตถุดิบที่แพ้” จะถูกทำเครื่องหมายและไม่สามารถลบจากการแจ้งเตือนได้'),
                const SizedBox(height: 12),

                // ตัวอย่างอินพุต
                Builder(
                  builder: (_) {
                    final samples = isGroupMode
                        ? ['นมวัว', 'พริก', 'อาหารทะเล', 'สมุนไพรไทย']
                        : ['ใบกะเพรา', 'กระเทียม', 'ตะไคร้', 'ข่า'];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ตัวอย่าง',
                            style: t.titleSmall
                                ?.copyWith(color: cs.onSurfaceVariant)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: samples
                              .map((s) => Chip(
                                    label: Text(s),
                                    side: BorderSide(color: cs.outlineVariant),
                                    backgroundColor: cs.surfaceContainerHighest
                                        .withValues(alpha: .3),
                                  ))
                              .toList(),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 16),
                Divider(color: cs.outlineVariant),
                const SizedBox(height: 12),

                // สัญลักษณ์บนหน้าจอ
                Row(
                  children: [
                    Icon(Icons.info_outline, color: cs.secondary),
                    const SizedBox(width: 8),
                    Text('สัญลักษณ์บนหน้านี้',
                        style: t.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                const _HelpBullet('ไอคอนเครื่องหมายคำถาม (?) เปิดคู่มือนี้'),
                const _HelpBullet(
                    'ไอคอนกล้อง ใช้ช่วยกรอกอย่างรวดเร็ว (คำแนะนำการถ่ายภาพอยู่ในหน้ากล้อง)'),
                const _HelpBullet(
                    'ปุ่ม “ใช้ตัวกรอง” จะส่งค่าทั้งหมดกลับไปใช้กับการค้นหา'),
                const SizedBox(height: 20),

                // ปุ่มปิด
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.check),
                    label: const Text('เข้าใจแล้ว'),
                  ),
                ),
              ],
            ),
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

    // ใช้ WillPopScope เพื่อรองรับการกด back แล้วส่งผลลัพธ์กลับ
    return WillPopScope(
      onWillPop: () async {
        _popWithResult();
        return false;
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        resizeToAvoidBottomInset:
            true, // เพิ่ม: ให้หน้าจอปรับขนาดเมื่อแป้นพิมพ์ขึ้น
        extendBody: true, // ขยายพื้นที่ body ไปยัง bottom navigation
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _popWithResult,
            tooltip: 'กลับและใช้ตัวกรอง',
          ),
          title: const Text('ค้นหาด้วยวัตถุดิบ'),
        ),
        bottomNavigationBar: KeyboardVisibilityBuilder(
          builder: (context, isKeyboardVisible) {
            // ซ่อน bottom navigation bar เมื่อแป้นพิมพ์ขึ้น
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: isKeyboardVisible ? 0 : null,
              child: isKeyboardVisible
                  ? const SizedBox()
                  : CustomBottomNav(
                      selectedIndex: 1,
                      onItemSelected: _onNavItemTapped,
                      isLoggedIn: _isLoggedIn,
                    ),
            );
          },
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
                  padding: EdgeInsets.only(
                    left: 20.0,
                    right: 20.0,
                    top: 20.0,
                    bottom: MediaQuery.of(context).viewInsets.bottom +
                        80.0, // เพิ่ม padding bottom เยอะขึ้นเพื่อให้มีพื้นที่มากขึ้น
                  ),
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
                          hint: 'พิมพ์กลุ่ม เช่น ผักใบเขียว อาหารทะเล ถั่ว',
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
                              'พิมพ์ชื่อวัตถุดิบเดี่ยว เช่น กบ หอมแดง มะเขือเทศ',
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
                          hint: 'พิมพ์กลุ่มที่ไม่ต้องการ เช่น เนื้อสัตว์ นมวัว',
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
                          hint: 'พิมพ์วัตถุดิบที่ไม่ต้องการ เช่น นม ไข่ กุ้ง',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('ชื่อวัตถุดิบ'),
                    icon: Icon(Icons.label_outline),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('กลุ่มวัตถุดิบ'),
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
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // เพิ่มคำอธิบายโหมดปัจจุบัน
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                _groupMode ? Icons.info_outline : Icons.lightbulb_outline,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _groupMode
                      ? 'โหมดกลุ่ม: เลือก "กบ" จะได้กลุ่มวัตถุดิบที่เกี่ยวข้องทั้งหมด'
                      : 'โหมดเดี่ยว: เลือก "กบ" จะได้เฉพาะ "กบ" ตัวเดียว',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
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

            // พฤติกรรมกล่อง suggestion - ให้ปิดเมื่อไม่โฟกัสแต่ไม่หายไปง่าย
            hideOnUnfocus: true,
            hideOnEmpty: true,
            hideOnLoading: false,
            retainOnLoading: true, // เก็บ suggestions ไว้ขณะโหลด

            // ช่องกรอก
            builder: (ctx, textController, fieldFocus) => TextField(
              controller: textController,
              focusNode: fieldFocus,
              textInputAction: TextInputAction.done,
              enableSuggestions: true,
              autocorrect: false,
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
                  // เคลียร์ข้อความหลังเพิ่มเสร็จแล้ว
                  textController.clear();
                  // คง focus เพื่อพิมพ์ต่อได้ทันที
                  fieldFocus.requestFocus();
                }
              },
            ),

            // แสดงรายการ
            itemBuilder: (_, s) => ListTile(title: Text(s)),

            // ★ NEW: เคลียร์ให้ชัวร์ และคงโฟกัสเพื่อพิมพ์ต่อได้ทันที
            onSelected: (s) {
              onAdd(s);
              // เคลียร์ controller และคงโฟกัสเพื่อพิมพ์ต่อได้
              controller.clear();
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
