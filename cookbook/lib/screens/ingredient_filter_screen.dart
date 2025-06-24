import 'package:flutter/material.dart';

import 'ingredient_photo_screen.dart' show scanIngredient;
import 'search_screen.dart'; // ← เปิดผลค้นหา

class IngredientFilterScreen extends StatefulWidget {
  final List<String>? initialIngredients; // ← รับผลสแกนรอบแรก (optional)

  const IngredientFilterScreen({super.key, this.initialIngredients});

  @override
  State<IngredientFilterScreen> createState() => _IngredientFilterScreenState();
}

class _IngredientFilterScreenState extends State<IngredientFilterScreen> {
  /* ─── state ─── */
  final _haveSet = <String>{}; // “ต้องมี”
  final _notHaveSet = <String>{}; // “ต้องไม่มี”

  final _haveCtrl = TextEditingController();
  final _notHaveCtrl = TextEditingController();

  /* ─── init ─── */
  @override
  void initState() {
    super.initState();
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

  /* ─── helpers ─── */
  void _addHave(String n) {
    final v = n.trim();
    if (v.isEmpty || _haveSet.contains(v)) return;
    setState(() => _haveSet.add(v));
  }

  void _addNotHave(String n) {
    final v = n.trim();
    if (v.isEmpty || _notHaveSet.contains(v)) return;
    setState(() => _notHaveSet.add(v));
  }

  void _removeHave(String n) => setState(() => _haveSet.remove(n));
  void _removeNotHave(String n) => setState(() => _notHaveSet.remove(n));

  void _clearAll() => setState(() {
        _haveSet.clear();
        _notHaveSet.clear();
      });

  /* ─── open scanner ─── */
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

  /* ─── search ─── */
  void _searchRecipes() {
    if (_haveSet.isEmpty && _notHaveSet.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('กรุณาเพิ่มวัตถุดิบอย่างน้อย 1 รายการ')));
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

  /* ─── UI ─── */
  @override
  Widget build(BuildContext context) {
    const brandOrange = Color(0xFFFF9B05);
    const btnOrange = Color(0xFFFF9B05);
    const dangerRed = Color(0xFFFF6F6F);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Search',
            style: TextStyle(
                color: Color(0xFF0F2930),
                fontSize: 24,
                fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /* ───────── HAVE ───────── */
              const Text('แสดงสูตรที่มี:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _textBox(_haveCtrl, 'พิมพ์ชื่อวัตถุดิบได้มากกว่า 1 ชนิด',
                  onSubmitted: _addHave, onScan: _scanForHave),
              const SizedBox(height: 8),
              _chipsWrap(_haveSet, _removeHave, brandOrange),
              const SizedBox(height: 24),

              /* ───────── NOT HAVE ───────── */
              const Text('แสดงสูตรที่ไม่มี:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _textBox(_notHaveCtrl, 'พิมพ์ชื่อวัตถุดิบได้มากกว่า 1 ชนิด',
                  onSubmitted: _addNotHave, onScan: _scanForNotHave),
              const SizedBox(height: 8),
              _chipsWrap(_notHaveSet, _removeNotHave, Colors.grey.shade700),
              const SizedBox(height: 40),

              /* ───────── CLEAR ───────── */
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dangerRed,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                  ),
                  onPressed: _clearAll,
                  child: const Text('ลบตัวกรองทั้งหมด',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 32),

              /* ───────── SEARCH BTN ───────── */
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: btnOrange,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 48, vertical: 16),
                  ),
                  onPressed: _searchRecipes,
                  child: Text(
                      'แสดง ${_haveSet.length + _notHaveSet.length} สูตร',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _fakeBottomNav(1), // keep nav UI เหมือนเดิม
    );
  }

  /* ─── TextBox + Scan icon ─── */
  Widget _textBox(TextEditingController ctrl, String hint,
          {required void Function(String) onSubmitted,
          required VoidCallback onScan}) =>
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              decoration: InputDecoration(
                hintText: hint,
                filled: true,
                fillColor: const Color(0xFFF6F6F6),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFBDBDBD))),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (v) {
                onSubmitted(v);
                ctrl.clear();
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, size: 28),
            onPressed: onScan,
          )
        ],
      );

  /* ─── Chips ─── */
  Widget _chipsWrap(
          Set<String> data, void Function(String) onRemove, Color c) =>
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: data
            .map((n) => Chip(
                  label: Text(n,
                      style: TextStyle(
                          color: c, fontWeight: FontWeight.w600, fontSize: 14)),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () => onRemove(n),
                  backgroundColor: const Color(0xFFEAEAEA),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: c)),
                ))
            .toList(),
      );

  /* ─── Bottom Navigation Placeholder ─── */
  Widget _fakeBottomNav(int idx) => BottomNavigationBar(
        currentIndex: idx,
        onTap: (_) {},
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: ''),
        ],
        selectedItemColor: Color(0xFFFF9B05),
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      );
}
