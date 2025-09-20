// lib/screens/allergy_screen.dart
//
// หมายเหตุ (TH):
// - หน้านี้ใช้แนวทาง “ปลอดภัยหลัง await” เพื่อเลี่ยง use_build_context_synchronously
//   • จับ Navigator/ScaffoldMessenger/Theme ก่อน await แล้วใช้ตัวแปรที่จับไว้
//   • ใช้ builder context ภายใน dialog/sheet แทน context ด้านนอกเสมอ
//   • เช็ค mounted ก่อนทำ setState หรือเรียกเมธอดที่อาศัย State
// - UI ปรับตาม Material 3 แล้ว: surfaceContainerHighest, withValues, TextScaler เป็นต้น
// หน้าแสดงและจัดการรายการวัตถุดิบที่แพ้
//
// ★ 2025-07-19 – refactor: ใช้ Theme, ปรับปรุง error handling & UX logic ★
//   • ลบการคำนวณ Responsive เองทิ้งทั้งหมด และเปลี่ยนไปใช้ Theme จาก context
//   • ปรับปรุงการจัดการ Error ให้รองรับ Custom Exception จาก ApiService
//   • แก้ไข Logic ของ "Undo" ให้ถูกต้อง และปรับ "Add" ให้เป็น Optimistic UI
//
// ★ 2025-08-10 – รองรับ “แพ้แบบกลุ่ม” ให้สอดคล้อง backend ใหม่
//   • โหลดสรุปกลุ่มจาก get_allergy_list.php (field: groups)
//   • แสดงส่วน “กลุ่มที่แพ้” เป็นชิป ลบได้ครั้งเดียวทั้งกลุ่ม (removeAllergyGroup)
//   • เพิ่มเมนู “ลบทั้งกลุ่มนี้” จากรายการวัตถุดิบ (long-press / more menu)
//   • คงพฤติกรรมเดิมการลบทีละรายการไว้ และคอมเมนต์ [OLD] ในส่วนที่เปลี่ยน

import 'dart:async';
import 'package:flutter/material.dart';

import '../models/ingredient.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart'; //   1. เพิ่ม AuthService
import 'all_ingredients_screen.dart';

class AllergyScreen extends StatefulWidget {
  const AllergyScreen({super.key});

  @override
  State<AllergyScreen> createState() => _AllergyScreenState();
}

class _AllergyScreenState extends State<AllergyScreen> {
  /* ─── state ───────────────────────────────────────────── */
  List<Ingredient> _allergyList = [];
  List<Ingredient> _filteredList = [];
  final Set<int> _removingIds = {};
  bool _loading = true;

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;

  String? _errorMessage;

  // ★ NEW: กลุ่มที่ผู้ใช้แพ้ (สรุปจาก backend)
  //    โครงสร้างดิบจาก ApiService.fetchAllergyGroups():
  //    [{ group_name, representative_ingredient_id }]
  List<_GroupSummary> _groups = [];
  final Set<int> _removingGroupRepIds = {};

  @override
  void initState() {
    super.initState();
    _loadAllergyList();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /* ─── API loads & Actions ──────────────────────────────── */
  ///   2. ปรับปรุง Error Handling ให้รองรับ Custom Exception
  Future<void> _loadAllergyList() async {
    if (!mounted) return;
    // ★ จับ ScaffoldMessenger ล่วงหน้าเพื่อใช้หลัง await ได้อย่างปลอดภัย
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _loading = true;
      _errorMessage = null; // reset error ก่อนโหลดใหม่
    });

    try {
      // [OLD]
      // final list = await ApiService.fetchAllergyIngredients();

      // [NEW] โหลด “รายการเดี่ยว” + “สรุปกลุ่ม”
      final results = await Future.wait([
        ApiService.fetchAllergyIngredients(), // 0: รายการเดี่ยว
        ApiService.fetchAllergyGroups(), // 1: สรุปกลุ่ม (ชื่อกลุ่ม + rep_id)
      ]);

      final list = results[0] as List<Ingredient>;
      final rawGroups = results[1] as List<Map<String, dynamic>>;

      // ผูกภาพตัวแทนของกลุ่มจาก rep_id กับรายการเดี่ยว ถ้าหาเจอ
      final imageById = {for (final i in list) i.id: i.imageUrl};
      final nameById = {for (final i in list) i.id: (i.displayName ?? i.name)};

      final groups = rawGroups.map((g) {
        final rep = (g['representative_ingredient_id'] is int)
            ? g['representative_ingredient_id'] as int
            : int.tryParse('${g['representative_ingredient_id'] ?? 0}') ?? 0;
        final gn = (g['group_name'] ?? '').toString();
        final img = imageById[rep];
        final repName = nameById[rep];
        return _GroupSummary(
          groupName: gn,
          representativeIngredientId: rep,
          representativeImageUrl: (img != null && img.isNotEmpty) ? img : null,
          representativeName: repName,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _allergyList = _sorted(list);
        _filteredList = _applyFilter(_allergyList, _searchCtrl.text);
        _groups = groups;
      });
    } on UnauthorizedException {
      // ★ ป้องกัน use_build_context_synchronously: จับ nav ก่อน await
      final nav = Navigator.of(context);
      await AuthService.logout();
      // ใช้ nav ที่จับไว้
      nav.pushNamedAndRemoveUntil('/login', (route) => false);
    } on ApiException catch (e) {
      // ใช้ messenger ที่จับไว้ แทนเรียกผ่าน context หลัง await
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      final m = 'เกิดข้อผิดพลาดที่ไม่รู้จัก: $e';
      messenger.showSnackBar(SnackBar(content: Text(m)));
      if (mounted) setState(() => _errorMessage = m);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  ///   3. แก้ไข "Undo" Logic ให้ถูกต้อง และปรับปรุง "Remove"
  void _removeAllergy(Ingredient ing) {
    if (_removingIds.contains(ing.id)) return;
    // ★ จับ messenger ไว้ใช้ใน callback หลัง async gap
    final messenger = ScaffoldMessenger.of(context);

    // Optimistic UI: ลบออกจาก List ใน UI ทันที
    setState(() {
      _removingIds.add(ing.id);
      _allergyList.removeWhere((e) => e.id == ing.id);
      _filteredList.removeWhere((e) => e.id == ing.id);
    });

    // กัน SnackBar ซ้อน
    messenger.hideCurrentSnackBar();
    // แสดง SnackBar พร้อมปุ่ม Undo
    messenger.showSnackBar(
      SnackBar(
        content: Text('ลบ “${ing.name}” แล้ว'),
        action: SnackBarAction(
          label: 'เลิกทำ',
          onPressed: () => _undoRemove(ing),
        ),
      ),
    );

    // เรียก API เพื่อลบข้อมูลจริงในเบื้องหลัง
    ApiService.removeAllergy(ing.id).catchError((_) {
      messenger.showSnackBar(SnackBar(
          content: Text('เกิดข้อผิดพลาด: ไม่สามารถลบ "${ing.name}" ได้')));
      // Rollback
      if (mounted) {
        setState(() {
          _allergyList.add(ing);
          _allergyList = _sorted(_allergyList);
          _filteredList = _applyFilter(_allergyList, _searchCtrl.text);
        });
      }
    }).whenComplete(() {
      if (mounted) setState(() => _removingIds.remove(ing.id));
    });
  }

  // ★ NEW: ลบ “ทั้งกลุ่ม” อิงจาก representative_ingredient_id
  Future<void> _removeAllergyGroup(_GroupSummary g) async {
    if (_removingGroupRepIds.contains(g.representativeIngredientId)) return;
    // ★ จับ messenger ไว้ก่อนมี await เพื่อหลีกเลี่ยงการใช้ context หลัง async gap
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      // หมายเหตุ: ใช้ context ของ builder (dCtx) ตอน pop() เพื่อเลี่ยงการอ้างอิง
      // context ด้านนอกภายหลัง async gap และเพื่อความชัดเจนของ scope
      builder: (dCtx) => AlertDialog(
        title: const Text('ลบทั้งกลุ่ม'),
        content: Text(
            'ต้องการลบกลุ่ม “${g.groupName}” ออกจากรายการแพ้ทั้งหมดใช่หรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(dCtx, true),
              child: const Text('ลบ')),
        ],
      ),
    );

    if (ok != true) return;

    // Optimistic UI: เอาชิปกลุ่มออกก่อน
    setState(() {
      _removingGroupRepIds.add(g.representativeIngredientId);
      _groups.removeWhere(
          (x) => x.representativeIngredientId == g.representativeIngredientId);
    });

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('ลบกลุ่ม “${g.groupName}” แล้ว')),
    );

    try {
      await ApiService.removeAllergyGroup([g.representativeIngredientId]);
      // หลังลบจริง โหลดทั้งหน้าใหม่เพื่อให้รายการเดี่ยวตรงกับกลุ่ม
      if (!mounted) return; // กัน context หลัง await
      await _loadAllergyList();
    } catch (_) {
      _showError('เกิดข้อผิดพลาด: ไม่สามารถลบกลุ่ม “${g.groupName}” ได้');
      // Rollback เฉพาะชิปกลุ่ม (รายการเดี่ยวจะรีเฟรชอยู่ดี)
      if (mounted) setState(() => _groups.add(g));
    } finally {
      if (mounted) {
        setState(
            () => _removingGroupRepIds.remove(g.representativeIngredientId));
      }
    }
  }

  Future<void> _undoRemove(Ingredient ing) async {
    // ★ จับ messenger ไว้ก่อน await
    final messenger = ScaffoldMessenger.of(context);
    // เมื่อกด Undo, ต้องเพิ่มกลับเข้าไปใน List และยิง API เพื่อเพิ่มกลับเข้าไปใน DB ด้วย
    setState(() {
      _allergyList.add(ing);
      _allergyList = _sorted(_allergyList);
      _filteredList = _applyFilter(_allergyList, _searchCtrl.text);
    });
    try {
      await ApiService.addAllergy(ing.id);
    } catch (e) {
      messenger.showSnackBar(
          const SnackBar(content: Text('เกิดข้อผิดพลาด: ไม่สามารถเลิกทำได้')));
      // ถ้า Error ให้ลบออกจาก UI อีกครั้ง
      setState(() {
        _allergyList.removeWhere((e) => e.id == ing.id);
        _filteredList = _applyFilter(_allergyList, _searchCtrl.text);
      });
    }
  }

  ///   4. ปรับปรุง "Add" ให้เป็น Optimistic UI
  Future<void> _onAddAllergy() async {
    final messenger = ScaffoldMessenger.of(context); // ★ จับไว้ใช้หลัง await
    final Ingredient? picked = await Navigator.push<Ingredient>(
      context,
      MaterialPageRoute(
          builder: (_) => const AllIngredientsScreen(selectionMode: true)),
    );

    if (picked != null && !_allergyList.any((e) => e.id == picked.id)) {
      setState(() {
        _allergyList.add(picked);
        _allergyList = _sorted(_allergyList);
        _filteredList = _applyFilter(_allergyList, _searchCtrl.text);
      });
      try {
        await ApiService.addAllergy(picked.id);
        // เคสใช้งานทั่วไป: ถ้าอยาก “เพิ่มทั้งกลุ่ม” ให้ผู้ใช้กดค้างที่รายการแล้วเลือกเมนู
      } catch (e) {
        messenger.showSnackBar(SnackBar(
            content:
                Text('เกิดข้อผิดพลาด: ไม่สามารถเพิ่ม "${picked.name}" ได้')));
        setState(() {
          _allergyList.removeWhere((e) => e.id == picked.id);
          _filteredList = _applyFilter(_allergyList, _searchCtrl.text);
        });
      }
    }
  }

  // ★ NEW: เมนูจากรายการเดี่ยว → เลือกลบทั้งกลุ่ม (อิงชื่อเดียวกันบน backend)
  void _showItemActions(Ingredient ing) {
    // ★ จับ nav/messenger ก่อน เพื่อใช้ใน callbacks
    final nav = Navigator.of(context);
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('ลบเฉพาะรายการนี้'),
              onTap: () {
                nav.pop();
                _removeAllergy(ing);
              },
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('ลบทั้งกลุ่มนี้'),
              subtitle: const Text('ลบทุกวัตถุดิบที่ชื่อกลุ่มเดียวกัน'),
              onTap: () async {
                nav.pop();
                // ใช้ ingredient_id เดียวกันเป็นตัวแทน (backend จะขยายเป็นกลุ่มตามชื่อ)
                final g = _GroupSummary(
                  groupName: ing.displayName ?? ing.name,
                  representativeIngredientId: ing.id,
                  representativeImageUrl: ing.imageUrl,
                  representativeName: ing.displayName ?? ing.name,
                );
                await _removeAllergyGroup(g);
              },
            ),
          ],
        ),
      ),
    );
  }

  /* ─── search filter (คงเดิม + ขยายเงื่อนไข) ──────────────────── */
  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(
            () => _filteredList = _applyFilter(_allergyList, _searchCtrl.text));
      }
    });
  }

  // ★ Changed: ค้นหาทั้ง name และ displayName (ถ้ามี)
  List<Ingredient> _applyFilter(List<Ingredient> src, String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return List.from(src);
    return src.where((i) {
      final n = i.name.toLowerCase();
      final d = (i.displayName ?? '').toLowerCase();
      return n.contains(query) || d.contains(query);
    }).toList();
  }

  // ★ Added: ช่วยจัดเรียงชื่อ A→Z (ใช้ displayName ถ้ามี)
  List<Ingredient> _sorted(List<Ingredient> src) {
    final list = List<Ingredient>.from(src);
    list.sort((a, b) {
      final ka = (a.displayName?.isNotEmpty == true ? a.displayName! : a.name)
          .toLowerCase();
      final kb = (b.displayName?.isNotEmpty == true ? b.displayName! : b.name)
          .toLowerCase();
      return ka.compareTo(kb);
    });
    return list;
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ★ Added: ซ่อนคีย์บอร์ดสะดวก ๆ
  void _unfocus() {
    if (_searchFocus.hasFocus) _searchFocus.unfocus();
  }

  /* ─── build ───────────────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('วัตถุดิบที่แพ้'),
        actions: [
          // [OLD] ไม่มีเมนู
          // [NEW] ปุ่มช่วยเหลือสั้น ๆ
          IconButton(
            tooltip: 'วิธีจัดการกลุ่ม',
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showGroupHelp(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'เพิ่มวัตถุดิบที่แพ้',
        onPressed: _onAddAllergy,
        child: const Icon(Icons.add),
      ),
      body: GestureDetector(
        onTap: _unfocus,
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            /* ─── search bar ─── */
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _unfocus(),
                decoration: InputDecoration(
                  hintText: 'ค้นหาวัตถุดิบที่แพ้…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: (_searchCtrl.text.isNotEmpty)
                      ? IconButton(
                          tooltip: 'ล้างคำค้นหา',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() =>
                                _filteredList = _applyFilter(_allergyList, ''));
                            _unfocus();
                          },
                        )
                      : null,
                ),
              ),
            ),

            // ★ NEW: ส่วน “กลุ่มที่แพ้” (สรุปจาก backend)
            if (_groups.isNotEmpty)
              _AllergyGroupsSection(
                groups: _groups,
                removingRepIds: _removingGroupRepIds,
                onRemoveGroup: _removeAllergyGroup,
              ),

            /* ─── list / empty / loading ─── */
            Expanded(
              child: _buildBody(theme, textTheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, TextTheme textTheme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // ★ Added: แสดง retry UI เมื่อมี error
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _loadAllergyList,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      );
    }

    if (_allergyList.isEmpty) {
      return _buildEmptyState(textTheme);
    }
    if (_searchCtrl.text.isNotEmpty && _filteredList.isEmpty) {
      return Center(child: Text('ไม่พบผลการค้นหา “${_searchCtrl.text}”'));
    }

    return RefreshIndicator(
      onRefresh: _loadAllergyList,
      child: Scrollbar(
        child: ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          itemCount: _filteredList.length,
          itemBuilder: (_, i) {
            final ing = _filteredList[i];
            final isRemoving = _removingIds.contains(ing.id);

            return Dismissible(
              key: ValueKey(ing.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) => _removeAllergy(ing),
              child: Semantics(
                label: 'วัตถุดิบที่แพ้ ${ing.name}',
                child: Card(
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundImage: _avatarProvider(ing.imageUrl),
                      onBackgroundImageError: (_, __) {},
                    ),
                    title: Text(ing.name, style: textTheme.titleMedium),
                    subtitle: (ing.displayName?.isNotEmpty ?? false)
                        ? Text(ing.displayName!)
                        : null,
                    trailing: isRemoving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : PopupMenuButton<String>(
                            tooltip: 'ตัวเลือก',
                            onSelected: (key) {
                              if (key == 'remove_one') {
                                _removeAllergy(ing);
                              } else if (key == 'remove_group') {
                                _showItemActions(ing);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'remove_one',
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.delete_outline),
                                  title: Text('ลบเฉพาะรายการนี้'),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'remove_group',
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.groups_outlined),
                                  title: Text('ลบทั้งกลุ่มนี้'),
                                  subtitle:
                                      Text('ลบทุกวัตถุดิบที่ชื่อกลุ่มเดียวกัน'),
                                ),
                              ),
                            ],
                          ),
                    // [OLD]
                    // trailing: IconButton(
                    //   tooltip: 'ลบออกจากรายการแพ้',
                    //   icon: const Icon(Icons.delete_outline),
                    //   onPressed: () => _removeAllergy(ing),
                    // ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  //   6. แยก Widget ของ Empty State ออกมาเพื่อความสะอาด
  Widget _buildEmptyState(TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sentiment_satisfied, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('ยังไม่มีวัตถุดิบที่แพ้', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('คุณสามารถเพิ่มได้โดยกดปุ่มบวก',
              style: textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
        ],
      ),
    );
  }

  // ★ Added: ตัวช่วยเลือกรูปรองรับ URL ว่าง → asset fallback
  ImageProvider _avatarProvider(String? url) {
    if (url == null || url.isEmpty) {
      return const AssetImage('assets/images/default_ingredient.png');
    }
    return NetworkImage(url);
  }

  void _showGroupHelp(BuildContext ctx) {
    final tt = Theme.of(ctx).textTheme;
    showModalBottomSheet(
      context: ctx,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('จัดการแบบกลุ่ม', style: tt.titleLarge),
            const SizedBox(height: 12),
            Text(
                'คุณสามารถลบทั้งกลุ่มได้จากส่วน “กลุ่มที่แพ้” หรือกดที่จุดสามจุดของแต่ละรายการแล้วเลือก “ลบทั้งกลุ่มนี้”.',
                style: tt.bodyMedium),
            const SizedBox(height: 8),
            Text(
                'การลบแบบกลุ่มจะลบวัตถุดิบทั้งหมดที่อยู่ในกลุ่มชื่อเดียวกันให้โดยอัตโนมัติ.',
                style: tt.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/* ──────────────────────────────
 * Internal view models / widgets
 * ────────────────────────────── */

class _GroupSummary {
  final String groupName;
  final int representativeIngredientId;
  final String? representativeImageUrl;
  final String? representativeName;

  const _GroupSummary({
    required this.groupName,
    required this.representativeIngredientId,
    this.representativeImageUrl,
    this.representativeName,
  });
}

class _AllergyGroupsSection extends StatelessWidget {
  final List<_GroupSummary> groups;
  final Set<int> removingRepIds;
  final Future<void> Function(_GroupSummary) onRemoveGroup;

  const _AllergyGroupsSection({
    required this.groups,
    required this.removingRepIds,
    required this.onRemoveGroup,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (groups.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('กลุ่มที่แพ้',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: groups.map((g) {
              final busy =
                  removingRepIds.contains(g.representativeIngredientId);
              return InputChip(
                label: Text(g.groupName),
                avatar: g.representativeImageUrl != null
                    ? CircleAvatar(
                        backgroundImage:
                            NetworkImage(g.representativeImageUrl!))
                    : const CircleAvatar(child: Icon(Icons.groups)),
                onDeleted: busy ? null : () => onRemoveGroup(g),
                deleteIcon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.close),
                side: BorderSide(color: cs.error),
                backgroundColor: cs.errorContainer.withValues(alpha: .15),
                labelStyle: TextStyle(
                    color: cs.onErrorContainer, fontWeight: FontWeight.w600),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
