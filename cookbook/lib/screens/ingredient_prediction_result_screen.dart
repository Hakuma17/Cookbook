import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'search_screen.dart'; // ← หน้าแสดงสูตร (รับ ingredients)

class IngredientPredictionResultScreen extends StatefulWidget {
  final File imageFile;
  final String predictedName;

  const IngredientPredictionResultScreen({
    Key? key,
    required this.imageFile,
    required this.predictedName,
  }) : super(key: key);

  @override
  State<IngredientPredictionResultScreen> createState() =>
      _IngredientPredictionResultScreenState();
}

class _IngredientPredictionResultScreenState
    extends State<IngredientPredictionResultScreen> {
  /// ใช้ Set ป้องกันชื่อซ้ำ
  final Set<String> _selected = {};

  /* ────────────────── helpers ────────────────── */

  void _add(String name) {
    if (!_selected.contains(name)) {
      if (!mounted) return;
      setState(() => _selected.add(name));
    }
  }

  void _remove(String name) {
    if (!mounted) return;
    setState(() => _selected.remove(name));
  }

  /* ────────────────── init ────────────────── */
  @override
  void initState() {
    super.initState();
    _add(widget.predictedName.trim());
  }

  /* ────────────────── build ────────────────── */
  @override
  Widget build(BuildContext context) {
    // ---- CONSTANTS ----
    const brandOrange = Color(0xFFFF9B05);
    const paleBg = Color(0xFFFFE3B9);

    return Scaffold(
      backgroundColor: paleBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final maxW = constraints.maxWidth;
            return SingleChildScrollView(
              child: Column(
                children: [
                  /* ─── App-bar style header ─── */
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom:
                            BorderSide(color: Colors.grey.shade400, width: 1),
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: brandOrange),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text(
                          'เพิ่มวัตถุดิบ',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: brandOrange,
                            fontFamily: 'Josefin Sans',
                          ),
                        ),
                      ],
                    ),
                  ),

                  /* ─── ภาพวัตถุดิบ ─── */
                  const SizedBox(height: 24),
                  _buildImagePreview(maxW * 0.8),

                  /* ─── ช่องชื่อ ─── */
                  const SizedBox(height: 24),
                  _buildNameBox(),

                  /* ─── ปุ่มเพิ่ม ─── */
                  const SizedBox(height: 16),
                  _RoundButton(
                    label: 'เพิ่มรายการวัตถุดิบ +',
                    onPressed: () => _add(widget.predictedName.trim()),
                  ),

                  /* ─── รายการวัตถุดิบ ─── */
                  const SizedBox(height: 24),
                  _buildListBox(maxW * 0.86),

                  /* ─── ปุ่มดูสูตรอาหาร ─── */
                  const SizedBox(height: 32),
                  _RoundButton(
                    label: 'ดูสูตรอาหาร',
                    icon: Icons.search,
                    color: Colors.green,
                    onPressed: _onViewRecipes,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /* ────────────────── UI pieces ────────────────── */

  Widget _buildImagePreview(double size) {
    final exists = widget.imageFile.existsSync();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: exists
          ? Image.file(widget.imageFile,
              width: size, height: size * 0.66, fit: BoxFit.cover)
          : Image.asset(
              'assets/images/ingredients/default.png',
              width: size,
              height: size * 0.66,
              fit: BoxFit.cover,
            ),
    );
  }

  Widget _buildNameBox() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade500),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          widget.predictedName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _buildListBox(double width) => Container(
        width: width,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFBEEDC),
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const Text(
              'รายการวัตถุดิบ',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            _selected.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('ยังไม่มีรายการ',
                        style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _selected.length,
                    itemBuilder: (_, i) {
                      final name = _selected.elementAt(i);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _ingredientThumb(name),
                        title: Text(name),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _remove(name),
                        ),
                      );
                    },
                  ),
          ],
        ),
      );

  /* ────────────────── actions ────────────────── */

  Future<void> _onViewRecipes() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเพิ่มวัตถุดิบอย่างน้อย 1 รายการ')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchScreen(ingredients: _selected.toList()),
      ),
    );
  }

  /* ────────────────── utils ────────────────── */

  Image _ingredientThumb(String name) {
    // พยายามโหลด asset ตามชื่อ (เช่น carrot.png) ถ้าไม่มี fallback
    final assetPath = 'assets/images/ingredients/${name.toLowerCase()}.png';
    return Image.asset(
      assetPath,
      width: 46,
      height: 46,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Image.asset(
          'assets/images/ingredients/default.png',
          width: 46,
          height: 46,
          fit: BoxFit.cover),
    );
  }
}

/* ────────────────── shared button ────────────────── */
class _RoundButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color color;

  const _RoundButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = const Color(0xFFFF9B05),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 260,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(38),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 8),
                Icon(icon, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
