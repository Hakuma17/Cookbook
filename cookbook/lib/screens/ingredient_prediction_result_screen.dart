// lib/screens/ingredient_prediction_result_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';

/// ─── แผนที่ Label → ชื่อภาษาไทย ─────────────────────────────────────
const Map<String, String> _kLabelMap = {
  'garlic': 'กระเทียม',
  'lime': 'มะนาว',
  'long_bean': 'ถั่วฝักยาว',
  'chilli': 'พริก',
  'carrot': 'แครอท',
  'cabbage': 'กะหล่ำปลี',
  'egg': 'ไข่',
  'tomato': 'มะเขือเทศ',
  'onion': 'หัวหอม',
  'lemongrass': 'ตะไคร้',
};

const double _kAutoFillThreshold = 0.80;
const double contentWidth = 312.0; // ความกว้างเนื้อหา
const double imgHeight = contentWidth; // ให้รูปเป็นสี่เหลี่ยมจัตุรัส
const double listBoxHeight = 140.0; // ความสูงกล่องรายการ

class IngredientPredictionResultScreen extends StatefulWidget {
  final File imageFile;
  //  รับผลการทำนายทั้งหมดมา
  final List<Map<String, dynamic>> allPredictions;

  const IngredientPredictionResultScreen({
    Key? key,
    required this.imageFile,
    required this.allPredictions,
  }) : super(key: key);

  @override
  _IngredientPredictionResultScreenState createState() =>
      _IngredientPredictionResultScreenState();
}

class _IngredientPredictionResultScreenState
    extends State<IngredientPredictionResultScreen> {
  final _inputCtrl = TextEditingController(); // ควบคุม TextField
  final _selected = <String>{}; // รายการที่ผู้ใช้เลือก
  List<Map<String, dynamic>> _preds = [];
  bool _showPreds = false;

  @override
  void initState() {
    super.initState();
    //ไม่มีการโหลดโมเดล ใช้ข้อมูลที่ส่งมาได้เลย
    _preds = widget.allPredictions.take(3).toList();

    // auto‐fill ถ้า confidence สูงพอ
    if (widget.allPredictions.isNotEmpty) {
      final topPrediction = widget.allPredictions.first;
      if ((topPrediction['confidence'] as double) >= _kAutoFillThreshold) {
        _inputCtrl.text = _map(topPrediction['label'] as String);
      }
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();

    super.dispose();
  }

  /// แปลง label อังกฤษ → ไทย
  String _map(String raw) => _kLabelMap[raw.toLowerCase()] ?? raw;

  /// เพิ่มใน list
  void _addToList() {
    final v = _inputCtrl.text.trim();
    if (v.isNotEmpty) {
      setState(() => _selected.add(v));
      _inputCtrl.clear();
      FocusScope.of(context).unfocus(); // ซ่อนคีย์บอร์ด
    }
  }

  /// ลบรายการ
  void _remove(String n) => setState(() => _selected.remove(n));

  ///  แสดง Bottom Sheet ช่วยแนะนำวิธีใช้
  void _showHelpSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📝 วิธีใช้หน้านี้',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            _bullet('กดที่ชื่อวัตถุดิบที่ทายผล เพื่อกรอกอัตโนมัติ'),
            _bullet('หรือพิมพ์ชื่อเอง แล้วกดปุ่ม “+” เพื่อเพิ่ม'),
            _bullet('แตะที่รูปวัตถุดิบในรายการเพื่อลบออก'),
            _bullet('กด “ดูสูตรอาหาร” เมื่อเลือกวัตถุดิบครบแล้ว'),
            const SizedBox(height: 12),
            const Text('สนุกกับการทำอาหารนะ! 🎉',
                style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _bullet(String t) =>
      Row(children: [const Text('• '), Expanded(child: Text(t))]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE3B9),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Custom Header ───────────────────────────────
            Container(
              width: double.infinity,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade400, width: 2),
                ),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(34)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // ปุ่มยกเลิก
                  Positioned(
                    left: 24,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'ยกเลิก',
                        style: TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF9B05),
                        ),
                      ),
                    ),
                  ),
                  // ชื่อหน้า
                  const Text(
                    'เพิ่มวัตถุดิบ',
                    style: TextStyle(
                      fontFamily: 'Josefin Sans',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF9B05),
                    ),
                  ),
                  // ปุ่มช่วยเหลือ
                  Positioned(
                    right: 24,
                    child: IconButton(
                      icon: const Icon(Icons.help_outline,
                          size: 28, color: Color(0xFFFF9B05)),
                      tooltip: 'ดูวิธีใช้',
                      onPressed: _showHelpSheet,
                    ),
                  ),
                ],
              ),
            ),

            // ─── เนื้อหา ─────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                child: Center(
                  child: Column(
                    children: [
                      // รูปที่ถ่าย (สี่เหลี่ยมจัตุรัส)
                      Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            widget.imageFile,
                            width: contentWidth,
                            height: imgHeight,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Image.asset(
                              'assets/images/default_ingredients.png',
                              width: contentWidth,
                              height: imgHeight,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ช่องกรอก + ปุ่ม +
                      SizedBox(
                        width: contentWidth,
                        child: _ManualInput(
                          controller: _inputCtrl,
                          onAdd: _addToList,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ผลทำนาย expandable
                      SizedBox(
                        width: contentWidth,
                        child: GestureDetector(
                          onTap: () => setState(() => _showPreds = !_showPreds),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ผลลัพธ์การทำนาย',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              Icon(
                                _showPreds
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: Colors.grey.shade800,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_showPreds && _preds.isNotEmpty)
                        SizedBox(
                          width: contentWidth,
                          child: Column(
                            children: List.generate(_preds.length,
                                (i) => _buildPredictionBar(_preds[i], i)),
                          ),
                        ),
                      const SizedBox(height: 24),

                      // รายการวัตถุดิบ (scroll แนวนอน)
                      if (_selected.isNotEmpty) ...[
                        SizedBox(
                          width: contentWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'รายการวัตถุดิบ',
                                style: TextStyle(
                                  fontFamily: 'Roboto Condensed',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: contentWidth,
                                height: listBoxHeight,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFBEEDC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.black12),
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: _selected.map((name) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(right: 12),
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          alignment: Alignment.center,
                                          children: [
                                            Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Image.asset(
                                                    'assets/images/default_ingredients.png', // ใช้ภาพ placeholder
                                                    width: 78,
                                                    height: 78,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  name,
                                                  style: const TextStyle(
                                                    fontFamily: 'Montserrat',
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Positioned(
                                              right: -8,
                                              top: -8,
                                              child: GestureDetector(
                                                onTap: () => _remove(name),
                                                child: Container(
                                                  width: 24,
                                                  height: 24,
                                                  decoration:
                                                      const BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.redAccent,
                                                  ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    size: 16,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // ปุ่มหลัก "ดูสูตรอาหาร"
                      SizedBox(
                        width: contentWidth,
                        child: _PrimaryButton(
                          onTap: () =>
                              Navigator.pop(context, _selected.toList()),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // สร้าง Prediction bar จาก Map
  Widget _buildPredictionBar(Map<String, dynamic> p, int index) {
    final colors = [
      const Color(0xFFFF9B05),
      const Color(0xFFFF4081),
      const Color(0xFF7C4DFF),
    ];
    final fillColor = colors[index % colors.length];
    final bgColor = fillColor.withOpacity(0.2);

    final label = _map(p['label'] as String);
    final score = p['confidence'] as double;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onTap: () {
          _inputCtrl.text = label;
        },
        child: Container(
          width: contentWidth,
          height: 36, // เพิ่มความสูงเล็กน้อย
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: score.clamp(0.0, 1.0),
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      Text('${(score * 100).toInt()}%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ★ REMOVED: คลาสนี้ไม่จำเป็นต้องใช้อีกต่อไป
// class _Pred { ... }

/// ปุ่มหลัก “ดูสูตรอาหาร”
class _PrimaryButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PrimaryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          // ★ CHANGED: เปลี่ยนสีปุ่มให้เข้ากับ Theme
          color: const Color(0xFFFF9B05),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))
          ],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.search, size: 28, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'ดูสูตรอาหาร',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ช่องกรอกชื่อวัตถุดิบพร้อมปุ่ม +
class _ManualInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onAdd;
  const _ManualInput({
    required this.controller,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
              decoration: const InputDecoration(
                hintText: 'พิมพ์ชื่อวัตถุดิบ',
                border: InputBorder.none,
              ),
              onSubmitted: (_) => onAdd(),
            ),
          ),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFF9B05),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}
