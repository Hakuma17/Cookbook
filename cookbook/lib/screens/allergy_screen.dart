// lib/screens/allergy_screen.dart
// หน้าแสดงและจัดการรายการวัตถุดิบที่แพ้

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../models/ingredient.dart';
import '../services/api_service.dart';
import 'all_ingredients_screen.dart'; // ★ นำเข้าโค้ด AllIngredientsScreen

class AllergyScreen extends StatefulWidget {
  const AllergyScreen({Key? key}) : super(key: key);

  @override
  State<AllergyScreen> createState() => _AllergyScreenState();
}

class _AllergyScreenState extends State<AllergyScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Ingredient> _allergyList = []; // ดึงจากเซิร์ฟเวอร์
  List<Ingredient> _filteredList = []; // หลังกรองชื่อ
  final Set<int> _removingIds = {}; // กันกดลบซ้ำ
  bool _loading = true;
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

  /// โหลดรายการวัตถุดิบที่แพ้จาก API
  Future<void> _loadAllergyList() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService.fetchAllergyIngredients()
          .timeout(const Duration(seconds: 10));
      setState(() {
        _allergyList = list;
        _filteredList = _applyFilter(list, _searchCtrl.text);
      });
    } on TimeoutException {
      _showError('เซิร์ฟเวอร์ช้าหรือไม่ตอบสนอง');
    } on SocketException {
      _showError('ไม่มีการเชื่อมต่ออินเทอร์เน็ต');
    } catch (e) {
      _showError('โหลดข้อมูลล้มเหลว: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  /// ฟังก์ชันกรองตามข้อความค้นหา
  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _filteredList = _applyFilter(_allergyList, _searchCtrl.text);
      });
    });
  }

  List<Ingredient> _applyFilter(List<Ingredient> src, String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return List.from(src);
    return src.where((i) => i.name.toLowerCase().contains(query)).toList();
  }

  /// ลบรายการและให้ Undo ได้
  void _removeAllergy(Ingredient ing) {
    final id = ing.id;
    if (_removingIds.contains(id)) return;
    setState(() {
      _removingIds.add(id);
      _allergyList.removeWhere((i) => i.id == id);
      _filteredList.removeWhere((i) => i.id == id);
    });

    ApiService.removeAllergy(id)
        .timeout(const Duration(seconds: 8))
        .catchError((e) {
      _showError('ลบไม่สำเร็จ: $e');
      // ถ้า error ให้คืนค่าเดิม
      setState(() {
        _allergyList.add(ing);
        _filteredList.add(ing);
      });
    }).whenComplete(() {
      setState(() => _removingIds.remove(id));
      // แสดง Snackbar พร้อม Undo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ลบ “${ing.name}” แล้ว'),
          action: SnackBarAction(
            label: 'เลิกทำ',
            onPressed: () {
              setState(() {
                _allergyList.add(ing);
                _filteredList.add(ing);
              });
            },
          ),
        ),
      );
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  /// ★ ไปหน้าเพิ่ม All Ingredients ในโหมดเลือก แล้วรับกลับ Ingredient เดียว
  Future<void> _onAddAllergy() async {
    final Ingredient? picked = await Navigator.push<Ingredient>(
      context,
      MaterialPageRoute(
        builder: (_) => const AllIngredientsScreen(
          selectionMode: true,
        ),
      ),
    );
    if (picked != null) {
      // เรียก API เพิ่ม Allergy แล้วรีโหลด
      await ApiService.addAllergy(picked.id);
      _loadAllergyList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('วัตถุดิบที่แพ้'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllergyList,
              child: Column(
                children: [
                  // ─── Search Bar ──────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'ค้นหาวัตถุดิบที่แพ้…',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 0),
                      ),
                    ),
                  ),

                  // ─── Empty State ─────────────────────────
                  if (_filteredList.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sentiment_satisfied,
                                size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text('ยังไม่มีวัตถุดิบที่แพ้',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 16)),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _onAddAllergy,
                              icon: const Icon(Icons.add),
                              label: const Text('เพิ่มวัตถุดิบที่แพ้'),
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    // ─── List of Allergies ───────────────────
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
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
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child:
                                  const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) => _removeAllergy(ing),
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 1,
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: ListTile(
                                leading: ClipOval(
                                  child: Image.network(
                                    ing.imageUrl,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Image.asset(
                                      'assets/images/default_ingredients.png',
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                title: Text(ing.name),
                                subtitle: ing.displayName?.isNotEmpty == true
                                    ? Text(ing.displayName!)
                                    : null,
                                trailing: isRemoving
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddAllergy,
        child: const Icon(Icons.add),
        tooltip: 'เพิ่มวัตถุดิบที่แพ้',
      ),
    );
  }
}
