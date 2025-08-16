import 'dart:io';
import 'package:flutter/material.dart';

/// ─── แผนที่ Label → ชื่อภาษาไทย ─────────────────────────────────────
/// (อัปเดตให้ตรง 12 คลาสจาก labels.txt และรองรับ sanitize ใน _mapLabel)
const Map<String, String> _kLabelMap = {
  'bai horapha': 'ใบโหระพา',
  'bai yi ra': 'ใบยี่หร่า',
  'hom daeng': 'หอมแดง',
  'kaprao': 'ใบกะเพรา',
  'krathiam': 'กระเทียม',
  'makrut': 'ใบมะกรูด',
  'manao': 'มะนาว',
  'prik chi fa': 'พริกชี้ฟ้า',
  'prik khi nu': 'พริกขี้หนู',
  'takhrai': 'ตะไคร้',
  'krachai': 'กระชาย',
  'kha': 'ข่า',
};

const double _kAutoFillThreshold = 0.80;

// ★ ธง/เกณฑ์สำหรับเตือนกรณีมีหลายวัตถุดิบในภาพ
const double _kMultiGap = 0.10; // top1 - top2 < 0.10
const double _kMultiSecond = 0.50; // และ top2 ≥ 0.50

/* ────────────────────────────────────────────────────────────── */
/*  สีหลักตาม mock-up                                            */
/* ────────────────────────────────────────────────────────────── */
const _bgColor = Color(0xFFFFE8CB); // ครีมอ่อน
const _primaryBtn = Color(0xFFFF00D6); // ชมพูสดปุ่มหลัก
const _barColors = [
  Color(0xFFF4A026), // ส้ม
  Color(0xFFFF4F86), // ชมพู
  Color(0xFFC9A4C9), // ม่วงอ่อน
];

class IngredientPredictionResultScreen extends StatefulWidget {
  final File imageFile;
  final List<Map<String, dynamic>> allPredictions;

  const IngredientPredictionResultScreen({
    super.key,
    required this.imageFile,
    required this.allPredictions,
  });

  @override
  State<IngredientPredictionResultScreen> createState() =>
      _IngredientPredictionResultScreenState();
}

class _IngredientPredictionResultScreenState
    extends State<IngredientPredictionResultScreen> {
  final _inputCtrl = TextEditingController();
  final _selected = <String>{};

  List<Map<String, dynamic>> _topPredictions = [];
  bool _showPredictions = false;

  // ★ ธงเตือน ‘หลายวัตถุดิบ’
  bool _multiObjectSuspected = false;

  @override
  void initState() {
    super.initState();
    _topPredictions = widget.allPredictions.take(3).toList();

    if (widget.allPredictions.isNotEmpty) {
      final top = widget.allPredictions.first;
      final conf = (top['confidence'] as num).toDouble();
      if (conf >= _kAutoFillThreshold) {
        _inputCtrl.text = _mapLabel(top['label'] as String);
      }
      if (widget.allPredictions.length >= 2) {
        final c1 = (widget.allPredictions[0]['confidence'] as num).toDouble();
        final c2 = (widget.allPredictions[1]['confidence'] as num).toDouble();
        _multiObjectSuspected =
            ((c1 - c2) < _kMultiGap) && (c2 >= _kMultiSecond);
      }
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  // sanitize label → lower/trim/ตัดเลขต้น/แปลง '_' เป็นช่องว่าง
  String _mapLabel(String raw) {
    final s = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'^\d+\s+'), '')
        .replaceAll('_', ' ');
    return _kLabelMap[s] ?? raw;
  }

  void _addToList() {
    final value = _inputCtrl.text.trim();
    if (value.isNotEmpty) {
      setState(() => _selected.add(value));
      _inputCtrl.clear();
      FocusScope.of(context).unfocus();
    }
  }

  void _removeFromList(String n) => setState(() => _selected.remove(n));

  void _showHelpSheet() => showModalBottomSheet(
        context: context,
        builder: (ctx) {
          final t = Theme.of(ctx).textTheme;
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📝 วิธีใช้หน้านี้', style: t.titleLarge),
                const SizedBox(height: 16),
                _bullet('กดชื่อวัตถุดิบเพื่อกรอกอัตโนมัติ', t),
                _bullet('พิมพ์ชื่อเองแล้วกด “+” เพื่อเพิ่ม', t),
                _bullet('แตะ ✕ เพื่อลบออกจากรายการ', t),
                _bullet('กด “ใช้รายการนี้” เมื่อเลือกครบ', t),
                const SizedBox(height: 12),
                // Tips ให้ตรงสcopeรูปภาพ
                _bullet('ถ่าย/ครอบให้มี “วัตถุดิบเดียว” ชัด ๆ ในภาพ', t),
                _bullet('พื้นหลังเรียบ แสงเพียงพอ ไม่ย้อนแสง', t),
                _bullet('ขนาดภาพอย่างน้อย 224×224 พิกเซล และไฟล์ ≤ 10MB', t),
              ],
            ),
          );
        },
      );

  Widget _bullet(String text, TextTheme t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ', style: TextStyle(fontSize: 16)),
            Expanded(child: Text(text, style: t.bodyMedium)),
          ],
        ),
      );

  // ★ รวม logic สรุปผลที่ต้องส่งกลับ (กันเคสยังไม่ได้กด '+')
  List<String>? _finalizeSelection() {
    if (_selected.isNotEmpty) return _selected.toList();
    final lone = _inputCtrl.text.trim();
    if (lone.isNotEmpty) return [lone];
    return null;
  }

  void _onConfirm() {
    final out = _finalizeSelection();
    if (out == null || out.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยังไม่ได้เลือกวัตถุดิบ')),
      );
      return;
    }
    Navigator.pop(context, out);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text('ผลการสแกน'),
        leading: TextButton(
          child: const Text('ยกเลิก'),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpSheet,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // รูปตัวอย่าง
              Semantics(
                label: 'ภาพที่สแกน',
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      widget.imageFile,
                      height: 300,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // เตือนหลายวัตถุดิบ
              if (_multiObjectSuspected)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFEEA8)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.black87),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ความมั่นใจของผลลัพธ์อันดับ 1 และ 2 ใกล้กัน อาจมีหลายวัตถุดิบในภาพ\n'
                          'แนะนำให้ครอบภาพให้ชัดเจนขึ้นหรือถ่ายใหม่',
                          style: tt.bodyMedium?.copyWith(color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),
              // ช่องกรอก + ปุ่มเพิ่ม
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      decoration:
                          const InputDecoration(hintText: 'พิมพ์ชื่อวัตถุดิบ'),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addToList(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: _primaryBtn,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add),
                    tooltip: 'เพิ่มเข้ารายการ',
                    onPressed: _addToList,
                  ),
                ],
              ),

              const SizedBox(height: 16),
              _buildPredictionSection(tt),

              const SizedBox(height: 24),
              if (_selected.isNotEmpty) _buildSelectedItemsSection(tt),

              const SizedBox(height: 24),
              // ปุ่มยืนยัน
              ElevatedButton.icon(
                icon: const Icon(Icons.search),
                label: const Text('ดูสูตรอาหาร'),
                onPressed: _onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBtn,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const StadiumBorder(),
                  elevation: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* ────────────── UI helpers ────────────── */

  Widget _buildPredictionSection(TextTheme tt) => Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showPredictions = !_showPredictions),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ผลลัพธ์การทำนาย', style: tt.titleMedium),
                  Icon(
                      _showPredictions ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (_showPredictions && _topPredictions.isNotEmpty)
            Column(
              children: List.generate(
                _topPredictions.length,
                (i) => _buildPredictionBar(_topPredictions[i], i),
              ),
            ),
        ],
      );

  Widget _buildPredictionBar(Map<String, dynamic> p, int i) {
    final fill = _barColors[i % _barColors.length];
    final bg = fill.withOpacity(0.15);
    final label = _mapLabel(p['label'] as String);
    final score = (p['confidence'] as num).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        button: true,
        label: 'เลือก $label ความมั่นใจ ${(score * 100).toInt()} เปอร์เซ็นต์',
        child: InkWell(
          onTap: () => _inputCtrl.text = label, // กดเพื่อกรอกอัตโนมัติ
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: score.clamp(0.0, 1.0),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                Padding(
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedItemsSection(TextTheme tt) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('รายการวัตถุดิบ', style: tt.titleMedium),
          const SizedBox(height: 8),
          Container(
            height: 120,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _selected
                    .map((n) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0),
                          child: Chip(
                            backgroundColor: Colors.white,
                            label: Text(n),
                            deleteIcon: const Icon(Icons.cancel, size: 18),
                            onDeleted: () => _removeFromList(n),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      );
}
