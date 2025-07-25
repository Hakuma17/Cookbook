// lib/screens/allergy_screen.dart
// หน้าแสดงและจัดการรายการวัตถุดิบที่แพ้
//
// ★ 2025-07-19 – refactor: ใช้ Theme, ปรับปรุง error handling & UX logic ★
//   • ลบการคำนวณ Responsive เองทิ้งทั้งหมด และเปลี่ยนไปใช้ Theme จาก context
//   • ปรับปรุงการจัดการ Error ให้รองรับ Custom Exception จาก ApiService
//   • แก้ไข Logic ของ "Undo" ให้ถูกต้อง และปรับ "Add" ให้เป็น Optimistic UI
//

import 'dart:async';
// import 'dart:io'; // 🗑️ ลบออก ไม่ได้ใช้แล้ว
import 'package:flutter/material.dart';

import '../models/ingredient.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart'; // ✅ 1. เพิ่ม AuthService
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
  Timer? _debounce;

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
    super.dispose();
  }

  /* ─── API loads & Actions ──────────────────────────────── */
  /// ✅ 2. ปรับปรุง Error Handling ให้รองรับ Custom Exception
  Future<void> _loadAllergyList() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final list = await ApiService.fetchAllergyIngredients();
      if (mounted) {
        setState(() {
          _allergyList = list;
          _filteredList = _applyFilter(list, _searchCtrl.text);
        });
      }
    } on UnauthorizedException {
      // ถ้า Session หมดอายุ ให้บังคับ Logout และไปหน้า Login
      await AuthService.logout();
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('เกิดข้อผิดพลาดที่ไม่รู้จัก: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// ✅ 3. แก้ไข "Undo" Logic ให้ถูกต้อง และปรับปรุง "Remove"
  void _removeAllergy(Ingredient ing) {
    if (_removingIds.contains(ing.id)) return;

    // Optimistic UI: ลบออกจาก List ใน UI ทันที
    setState(() {
      _removingIds.add(ing.id);
      _allergyList.removeWhere((e) => e.id == ing.id);
      _filteredList.removeWhere((e) => e.id == ing.id);
    });

    // แสดง SnackBar พร้อมปุ่ม Undo
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ลบ “${ing.name}” แล้ว'),
        action: SnackBarAction(
          label: 'เลิกทำ',
          onPressed: () => _undoRemove(ing), // เรียกฟังก์ชัน Undo
        ),
      ),
    );

    // เรียก API เพื่อลบข้อมูลจริงในเบื้องหลัง
    ApiService.removeAllergy(ing.id).catchError((_) {
      _showError('เกิดข้อผิดพลาด: ไม่สามารถลบ "${ing.name}" ได้');
      // ถ้าลบไม่สำเร็จ ให้เพิ่มกลับเข้ามาใน List (Rollback)
      if (mounted) {
        setState(() {
          _allergyList.add(ing);
          _filteredList = _applyFilter(_allergyList, _searchCtrl.text);
        });
      }
    }).whenComplete(() {
      if (mounted) setState(() => _removingIds.remove(ing.id));
    });
  }

  Future<void> _undoRemove(Ingredient ing) async {
    // เมื่อกด Undo, ต้องเพิ่มกลับเข้าไปใน List และยิง API เพื่อเพิ่มกลับเข้าไปใน DB ด้วย
    setState(() {
      _allergyList.add(ing);
      _filteredList = _applyFilter(_allergyList, _searchCtrl.text);
    });
    try {
      await ApiService.addAllergy(ing.id);
    } catch (e) {
      _showError('เกิดข้อผิดพลาด: ไม่สามารถเลิกทำได้');
      // ถ้า Error ให้ลบออกจาก UI อีกครั้ง
      setState(() {
        _allergyList.removeWhere((e) => e.id == ing.id);
        _filteredList = _applyFilter(_allergyList, _searchCtrl.text);
      });
    }
  }

  /// ✅ 4. ปรับปรุง "Add" ให้เป็น Optimistic UI
  Future<void> _onAddAllergy() async {
    final Ingredient? picked = await Navigator.push<Ingredient>(
      context,
      MaterialPageRoute(
          builder: (_) => const AllIngredientsScreen(selectionMode: true)),
    );

    if (picked != null && !_allergyList.any((e) => e.id == picked.id)) {
      // Optimistic UI: เพิ่มใน UI ทันที ไม่ต้องรอ API และไม่ต้อง reload ทั้ง List
      setState(() {
        _allergyList.add(picked);
        _filteredList = _applyFilter(_allergyList, _searchCtrl.text);
      });
      try {
        await ApiService.addAllergy(picked.id);
      } catch (e) {
        _showError('เกิดข้อผิดพลาด: ไม่สามารถเพิ่ม "${picked.name}" ได้');
        // ถ้าเพิ่มไม่สำเร็จ, ให้ลบออกจาก UI (Rollback)
        setState(() {
          _allergyList.removeWhere((e) => e.id == picked.id);
          _filteredList = _applyFilter(_allergyList, _searchCtrl.text);
        });
      }
    }
  }

  /* ─── search filter (คงเดิม) ─────────────────────────── */
  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(
            () => _filteredList = _applyFilter(_allergyList, _searchCtrl.text));
      }
    });
  }

  List<Ingredient> _applyFilter(List<Ingredient> src, String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return List.from(src);
    return src.where((i) => i.name.toLowerCase().contains(query)).toList();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /* ─── build ───────────────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    // ✅ 5. ลบการคำนวณ Responsive ทิ้งทั้งหมด และใช้ Theme จาก Context
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('วัตถุดิบที่แพ้')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'เพิ่มวัตถุดิบที่แพ้',
        onPressed: _onAddAllergy,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          /* ─── search bar ─── */
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'ค้นหาวัตถุดิบที่แพ้…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          /* ─── list / empty / loading ─── */
          Expanded(
            child: _buildBody(theme, textTheme),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme, TextTheme textTheme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_allergyList.isEmpty) {
      // เช็คจาก List หลัก
      return _buildEmptyState(textTheme);
    }
    // แสดงผลว่าไม่พบจากการค้นหา
    if (_searchCtrl.text.isNotEmpty && _filteredList.isEmpty) {
      return const Center(child: Text('ไม่พบผลการค้นหา'));
    }

    return RefreshIndicator(
      onRefresh: _loadAllergyList,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
            16, 8, 16, 80), // เพิ่ม padding ด้านล่างเผื่อ FAB
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
            child: Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage(ing.imageUrl),
                  onBackgroundImageError: (_, __) {}, // จัดการ error ของรูปภาพ
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
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  // ✅ 6. แยก Widget ของ Empty State ออกมาเพื่อความสะอาด
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
}
