// lib/screens/allergy_screen.dart
// หน้าแสดงและจัดการรายการวัตถุดิบที่แพ้
//
// ★ 2025-07-11 – responsive upgrade ★
//   • คำนวณ scale = w/360 (clamp 0.85‒1.25) แล้วคูณทุก padding / font / radius
//   • ปรับ empty-state, list-tile, FAB ให้พอดีกับทุกขนาด
//   • logic API, undo, dismissible ฯลฯ ไม่เปลี่ยน
//

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
  /* ─── state ───────────────────────────────────────────── */
  final TextEditingController _searchCtrl = TextEditingController();
  List<Ingredient> _allergyList = [];
  List<Ingredient> _filteredList = [];
  final Set<int> _removingIds = {};
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

  /* ─── API loads ───────────────────────────────────────── */
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
      if (mounted) setState(() => _loading = false);
    }
  }

  /* ─── search filter ──────────────────────────────────── */
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

  /* ─── remove + undo ──────────────────────────────────── */
  void _removeAllergy(Ingredient ing) {
    final id = ing.id;
    if (_removingIds.contains(id)) return;

    setState(() {
      _removingIds.add(id);
      _allergyList.removeWhere((e) => e.id == id);
      _filteredList.removeWhere((e) => e.id == id);
    });

    ApiService.removeAllergy(id)
        .timeout(const Duration(seconds: 8))
        .catchError((e) {
      _showError('ลบไม่สำเร็จ: $e');
      if (mounted) {
        setState(() {
          _allergyList.add(ing);
          _filteredList.add(ing);
        });
      }
    }).whenComplete(() {
      if (!mounted) return;
      setState(() => _removingIds.remove(id));
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

  /* ─── add with picker ─────────────────────────────────── */
  Future<void> _onAddAllergy() async {
    final Ingredient? picked = await Navigator.push<Ingredient>(
      context,
      MaterialPageRoute(
        builder: (_) => const AllIngredientsScreen(selectionMode: true),
      ),
    );
    if (picked != null) {
      await ApiService.addAllergy(picked.id);
      _loadAllergyList();
    }
  }

  void _showError(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /* ─── build ───────────────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    /* responsive helpers */
    final w = MediaQuery.of(context).size.width;
    double scale = (w / 360).clamp(0.85, 1.25);
    double px(double v) => v * scale;

    // numbers (อ้างอิง comment ด้านบนของคุณ → ปรับผ่าน px())
    final padH = px(16);
    final padV = px(14);
    final spaceS = px(8);
    final iconEmptySize = px(80);
    final fontEmpty = px(16);
    final btnRadius = px(18);
    final btnIcon = px(24);
    final cardMarginV = px(6);
    final imgSize = px(48);
    final trailingSz = px(22);

    return Scaffold(
      appBar: AppBar(
        title: const Text('วัตถุดิบที่แพ้'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'เพิ่มวัตถุดิบที่แพ้',
        onPressed: _onAddAllergy,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllergyList,
              child: Column(
                children: [
                  /* ─── search bar ─── */
                  Padding(
                    padding: EdgeInsets.fromLTRB(padH, padV, padH, 0),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'ค้นหาวัตถุดิบที่แพ้…',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(px(24)),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: padH, vertical: px(10)),
                      ),
                    ),
                  ),
                  SizedBox(height: spaceS),

                  /* ─── list / empty ─── */
                  if (_filteredList.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sentiment_satisfied,
                                size: iconEmptySize, color: Colors.grey[400]),
                            SizedBox(height: spaceS * 1.5),
                            Text('ยังไม่มีวัตถุดิบที่แพ้',
                                style: TextStyle(
                                    fontSize: fontEmpty,
                                    color: Colors.grey[600])),
                            SizedBox(height: spaceS),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('เพิ่มวัตถุดิบที่แพ้'),
                              onPressed: _onAddAllergy,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(btnRadius),
                                ),
                                iconSize: btnIcon,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(
                            horizontal: padH, vertical: padV * .6),
                        itemCount: _filteredList.length,
                        itemBuilder: (_, i) {
                          final ing = _filteredList[i];
                          final removing = _removingIds.contains(ing.id);
                          return Dismissible(
                            key: ValueKey(ing.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: EdgeInsets.only(right: padH),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(px(12)),
                              ),
                              child:
                                  const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) => _removeAllergy(ing),
                            child: Card(
                              elevation: 1,
                              margin:
                                  EdgeInsets.symmetric(vertical: cardMarginV),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(px(12))),
                              child: ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: padH * .5,
                                    vertical: cardMarginV),
                                leading: ClipOval(
                                  child: Image.network(
                                    ing.imageUrl,
                                    width: imgSize,
                                    height: imgSize,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Image.asset(
                                        'assets/images/default_ingredients.png',
                                        width: imgSize,
                                        height: imgSize,
                                        fit: BoxFit.cover),
                                  ),
                                ),
                                title: Text(ing.name,
                                    style: TextStyle(fontSize: px(15))),
                                subtitle: ing.displayName?.isNotEmpty == true
                                    ? Text(ing.displayName!,
                                        style: TextStyle(fontSize: px(13)))
                                    : null,
                                trailing: removing
                                    ? SizedBox(
                                        width: trailingSz,
                                        height: trailingSz,
                                        child: const CircularProgressIndicator(
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
    );
  }
}
