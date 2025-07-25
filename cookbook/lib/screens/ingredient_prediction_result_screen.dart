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

/* ────────────────────────────────────────────────────────────── */
/*  สีหลักตาม mock‑up                                            */
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
  _IngredientPredictionResultScreenState createState() =>
      _IngredientPredictionResultScreenState();
}

class _IngredientPredictionResultScreenState
    extends State<IngredientPredictionResultScreen> {
  final _inputCtrl = TextEditingController();
  final _selected = <String>{};
  List<Map<String, dynamic>> _topPredictions = [];
  bool _showPredictions = false;

  @override
  void initState() {
    super.initState();
    _topPredictions = widget.allPredictions.take(3).toList();

    if (widget.allPredictions.isNotEmpty) {
      final top = widget.allPredictions.first;
      if ((top['confidence'] as double) >= _kAutoFillThreshold) {
        _inputCtrl.text = _mapLabel(top['label'] as String);
      }
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  String _mapLabel(String raw) => _kLabelMap[raw.toLowerCase()] ?? raw;

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
          final textTheme = Theme.of(ctx).textTheme;
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📝 วิธีใช้หน้านี้', style: textTheme.titleLarge),
                const SizedBox(height: 16),
                _bullet('กดชื่อวัตถุดิบเพื่อกรอกอัตโนมัติ', textTheme),
                _bullet('พิมพ์ชื่อเองแล้วกด “+” เพื่อเพิ่ม', textTheme),
                _bullet('แตะ ✕ เพื่อลบออกจากรายการ', textTheme),
                _bullet('กด “ใช้รายการนี้” เมื่อเลือกครบ', textTheme),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

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
              Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(widget.imageFile,
                      height: 300, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      decoration:
                          const InputDecoration(hintText: 'พิมพ์ชื่อวัตถุดิบ'),
                      onSubmitted: (_) => _addToList(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                        backgroundColor: _primaryBtn,
                        foregroundColor: Colors.white),
                    icon: const Icon(Icons.add),
                    onPressed: _addToList,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildPredictionSection(textTheme),
              const SizedBox(height: 24),
              if (_selected.isNotEmpty) _buildSelectedItemsSection(textTheme),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.search),
                label: const Text('ดูสูตรอาหาร'),
                onPressed: () => Navigator.pop(context, _selected.toList()),
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
    final score = p['confidence'] as double;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _inputCtrl.text = label,
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
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('${(score * 100).toInt()}%',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
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
