import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../models/ingredient.dart';
import '../services/api_service.dart';

class AllergyScreen extends StatefulWidget {
  const AllergyScreen({Key? key}) : super(key: key);

  @override
  State<AllergyScreen> createState() => _AllergyScreenState();
}

class _AllergyScreenState extends State<AllergyScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  List<Ingredient> _allergyList = [];
  List<Ingredient> _filteredList = [];
  final Set<int> _removingIds = {};

  bool _loading = true;
  Timer? _debounce; // 💡  debounce search

  /* ───────────────── lifecycle ───────────────── */
  @override
  void initState() {
    super.initState();
    _loadAllergyList();
    _searchCtrl.addListener(_onSearchChanged); // 💡  listener เดียว
  }

  @override
  void dispose() {
    _debounce?.cancel(); // 💡  clean-up
    _searchCtrl.dispose();
    super.dispose();
  }

  /* ───────────────── data loaders ───────────────── */
  Future<void> _loadAllergyList() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final list = await ApiService.fetchAllergyIngredients()
          .timeout(const Duration(seconds: 10)); // 💡 timeout

      if (!mounted) return;
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

  Future<void> _removeAllergy(int id) async {
    if (_removingIds.contains(id)) return; // 💡 double-tap guard
    setState(() => _removingIds.add(id));

    try {
      await ApiService.removeAllergy(id).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        _allergyList.removeWhere((i) => i.id == id);
        _filteredList = _applyFilter(_allergyList, _searchCtrl.text);
      });
    } on TimeoutException {
      _showError('ลบไม่สำเร็จ: เซิร์ฟเวอร์ตอบช้า');
    } on SocketException {
      _showError('ไม่สามารถเชื่อมต่ออินเทอร์เน็ต');
    } catch (e) {
      _showError('ลบวัตถุดิบไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _removingIds.remove(id));
    }
  }

  /* ───────────────── search helpers ───────────────── */
  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _filteredList = _applyFilter(_allergyList, _searchCtrl.text);
      });
    });
  }

  List<Ingredient> _applyFilter(List<Ingredient> src, String q) {
    if (q.trim().isEmpty) return List.from(src);
    final lower = q.toLowerCase();
    return src.where((i) => i.name.toLowerCase().contains(lower)).toList();
  }

  /* ───────────────── misc ───────────────── */
  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /* ───────────────── build ───────────────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('วัตถุดิบที่แพ้'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'เพิ่มวัตถุดิบ',
            onPressed: () async {
              final added =
                  await Navigator.pushNamed(context, '/all_ingredients');
              if (added == true) _loadAllergyList();
            },
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllergyList,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'ค้นหาวัตถุดิบที่แพ้…',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(child: _buildList()),
                ],
              ),
            ),
    );
  }

  Widget _buildList() {
    if (_filteredList.isEmpty) {
      return const Center(
        child: Text('ยังไม่มีวัตถุดิบที่แพ้',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredList.length,
      itemBuilder: (_, i) {
        final ing = _filteredList[i];
        final isRemoving = _removingIds.contains(ing.id);

        return Card(
          elevation: 1.5,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            leading: ClipOval(
              child: Image.network(
                ing.imageUrl,
                width: 46,
                height: 46,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/images/default_ingredients.png',
                  width: 46,
                  height: 46,
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
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeAllergy(ing.id),
                  ),
          ),
        );
      },
    );
  }
}
