import 'dart:io';
import 'package:flutter/material.dart';

/// ─── แผนที่ Label → ชื่อภาษาไทย ─────────────────────────────────────
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
/*  โทนสี (นุ่ม เข้าธีมครีม)                                    */
/* ────────────────────────────────────────────────────────────── */
const _bgColor = Color(0xFFFFE8CB); // ครีมอ่อน
const _ink = Color(0xFF3D2B1F); // น้ำตาลเข้ม
const _cta = Color(0xFF8C5E3C); // Cocoa (ปุ่มหลัก/บวก)
const _ctaHover = Color(0xFF7A4E2D); // Cocoa เข้มตอนกด
const _chipBg = Color(0xFFFFF7EE); // พื้นหลังชิป (เดิม) – ยังเก็บไว้เผื่อใช้
const _chipLine = Color(0xFFB58763); // เส้นขอบชิป (เดิม)
const _chipText = Color(0xFF5B3E2B); // ตัวอักษรชิป

// ★ สีแท่งผลทำนาย (สดขึ้น) – ใช้โทนอุ่น/ชัดขึ้น แต่ยังเข้าธีม
const _barColors = [
  Color(0xFFF59E0B), // Amber 500 (ส้มสด)
  Color(0xFFEF4444), // Red 500 (คอรัลสด)
  Color(0xFF8B5CF6), // Violet 500 (ม่วงสด)
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
  bool _showPredictions = false; // ⬅️ ปิดไว้ก่อน ต้องกดลูกศรลงเพื่อเปิด

  // ★ ธงเตือน ‘หลายวัตถุดิบ’
  bool _multiObjectSuspected = false;

  @override
  void initState() {
    super.initState();

    _topPredictions = widget.allPredictions.take(3).toList();

    if (widget.allPredictions.isNotEmpty) {
      final top = widget.allPredictions.first;
      final conf = (top['confidence'] as num).toDouble();
      //   Autofill เฉพาะ ≥ 80%
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

    _inputCtrl.addListener(() => setState(() {}));
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

  // ─────────────────── Logic: เพิ่ม / ลบ / สรุป ───────────────────
  void _addToList({String? valueOverride}) {
    final value = (valueOverride ?? _inputCtrl.text).trim();
    if (value.isEmpty) return;

    if (_selected.contains(value)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('มี “$value” อยู่ในรายการแล้ว'),
          duration: const Duration(milliseconds: 900),
        ),
      );
      _inputCtrl.clear();
      return;
    }

    setState(() => _selected.add(value));
    _inputCtrl.clear();
    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('เพิ่ม “$value” แล้ว'),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  void _removeFromList(String n) => setState(() => _selected.remove(n));
  void _clearAll() => setState(() => _selected.clear());

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

  // ─── ออกจากหน้า: เตือนถ้ามีรายการวัตถุดิบ ──────────────────────
  Future<bool> _confirmCancelIfNeeded() async {
    if (_selected.isEmpty) return true; // ไม่มีรายการ → ออกได้เลย
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ทิ้งรายการวัตถุดิบ?'),
        content: Text(
            'คุณเพิ่มไว้ทั้งหมด ${_selected.length} รายการ ต้องการออกจากหน้านี้หรือไม่'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('อยู่ต่อ')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: _cta, foregroundColor: Colors.white),
            child: const Text('ออก'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<bool> _onWillPop() async => _confirmCancelIfNeeded();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;

    final canAdd = _inputCtrl.text.trim().isNotEmpty;
    final canConfirm = canAdd || _selected.isNotEmpty;

    return WillPopScope(
      onWillPop: _onWillPop, // ⬅️ จัดการปุ่ม Back ของระบบ
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _bgColor,
          foregroundColor: _ink,
          elevation: 0,
          title: const Text('ผลการสแกน'),
          // ★ แก้ “ยกเลิก” ให้เป็นปุ่มกากบาท ดูเนียน/คุ้นตา และยังถามยืนยันก่อนออก
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'ยกเลิก',
            onPressed: () async {
              if (await _confirmCancelIfNeeded()) {
                // ignore: use_build_context_synchronously
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              color: _ink,
              onPressed: _showHelpSheet,
              tooltip: 'วิธีใช้งาน',
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ───────── รูปตัวอย่าง ─────────
                Semantics(
                  label: 'ภาพที่สแกน',
                  child: Material(
                    color: Colors.white,
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

                // ───────── เตือนหลายวัตถุดิบ ─────────
                if (_multiObjectSuspected)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
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
                            'ความมั่นใจอันดับ 1 และ 2 ใกล้กัน อาจมีหลายวัตถุดิบในภาพ\n'
                            'แนะนำให้ครอบภาพให้ชัดเจนขึ้นหรือถ่ายใหม่',
                            style:
                                tt.bodyMedium?.copyWith(color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // ★ ข้อความบอกเกณฑ์ ≥80%
                Row(
                  children: [
                    Icon(Icons.tips_and_updates_outlined,
                        size: 18, color: _ink.withOpacity(.7)),
                    const SizedBox(width: 6),
                    Text(
                      'กรอกให้อัตโนมัติเมื่อความมั่นใจ ≥ ${(_kAutoFillThreshold * 100).toInt()}%',
                      style:
                          tt.bodySmall?.copyWith(color: _ink.withOpacity(.75)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ───────── ช่องกรอก + ปุ่มบวก ─────────
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputCtrl,
                        decoration: InputDecoration(
                          hintText: 'พิมพ์ชื่อวัตถุดิบ',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addToList(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: canAdd ? _cta : _cta.withOpacity(.35),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _cta.withOpacity(.25),
                      ),
                      icon: const Icon(Icons.add),
                      tooltip: 'เพิ่มเข้ารายการ',
                      onPressed: canAdd ? () => _addToList() : null,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ───────── ผลลัพธ์การทำนาย (ปิดไว้ก่อน) ─────────
                _buildPredictionSection(tt),

                const SizedBox(height: 24),

                // ───────── รายการวัตถุดิบที่เลือก ─────────
                _buildSelectedItemsSection(tt),

                const SizedBox(height: 24),

                // ───────── ปุ่มยืนยัน ─────────
                FilledButton.icon(
                  onPressed: canConfirm ? _onConfirm : null,
                  icon: const Icon(Icons.search),
                  label: Text(
                    _selected.isNotEmpty
                        ? 'ดูสูตรอาหาร (${_selected.length})'
                        : 'ดูสูตรอาหาร',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: canConfirm ? _cta : _cta.withOpacity(.35),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _cta.withOpacity(.25),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: const StadiumBorder(),
                  ).copyWith(
                    overlayColor: WidgetStateProperty.resolveWith(
                      (s) => s.contains(WidgetState.pressed)
                          ? _ctaHover.withOpacity(.18)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /* ────────────── UI helpers ────────────── */

  // ส่วน: แท่งผลทำนาย (แตะ = เพิ่มลงรายการทันที)
  Widget _buildPredictionSection(TextTheme tt) => Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showPredictions = !_showPredictions),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ผลลัพธ์การทำนาย',
                      style: tt.titleMedium?.copyWith(color: _ink)),
                  Icon(_showPredictions ? Icons.expand_less : Icons.expand_more,
                      color: _ink),
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
    final bg = fill.withOpacity(0.12); // ★ ทำแทร็กจางลง เพื่อให้สีแท่งดู “สด”
    final label = _mapLabel(p['label'] as String);
    final score = (p['confidence'] as num).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        button: true,
        label:
            'เพิ่ม $label ลงในรายการ ความมั่นใจ ${(score * 100).toInt()} เปอร์เซ็นต์',
        child: InkWell(
          onTap: () =>
              _addToList(valueOverride: label), // ➕ แตะ = เพิ่มเข้ารายการ
          borderRadius: BorderRadius.circular(18),
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
                            fontWeight: FontWeight.bold,
                          )),
                      Text('${(score * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          )),
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

  // ส่วน: รายการวัตถุดิบที่เลือก (Wrap ชิป + ปุ่ม “ล้างทั้งหมด”)
  Widget _buildSelectedItemsSection(TextTheme tt) {
    if (_selected.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('รายการวัตถุดิบ', style: tt.titleMedium?.copyWith(color: _ink)),
          const SizedBox(height: 8),
          Text(
            'ยังไม่มีรายการ — พิมพ์แล้วกดปุ่ม + หรือเปิด “ผลลัพธ์การทำนาย” เพื่อเลือก',
            style: tt.bodyMedium?.copyWith(color: _ink.withOpacity(.7)),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: Text('รายการวัตถุดิบ',
                    style: tt.titleMedium?.copyWith(color: _ink))),
            TextButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('ล้างทั้งหมด'),
              style: TextButton.styleFrom(foregroundColor: _cta),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // ★ เอากรอบพื้นหลังขาวของ “กล่อง” ออก เหลือเฉพาะชิป
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Wrap(
            key: ValueKey(_selected.length),
            spacing: 8,
            runSpacing: 8,
            children: _selected
                .map(
                  (n) => Chip(
                    label: Text(
                      n,
                      // ★ ใช้โทนเข้มอ่านชัด และคุมโทนกับขอบน้ำตาล
                      style: TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // ★ ทำชิป “ขอบน้ำตาล – พื้นขาว”
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: _cta, width: 1.2),
                    deleteIcon: const Icon(Icons.close, size: 18, color: _cta),
                    onDeleted: () => _removeFromList(n),
                    shape: const StadiumBorder(),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  // ชีทช่วยเหลือ
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
                _bullet('ผลลัพธ์การทำนายถูกปิดไว้ก่อน — กดหัวข้อเพื่อเปิด', t),
                _bullet('แตะแท่งผลลัพธ์เพื่อ “เพิ่ม” ลงในรายการวัตถุดิบ', t),
                _bullet('Autofill จะกรอกให้เองถ้าอันดับ 1 ≥ 80%', t),
                _bullet('พิมพ์ชื่อเองแล้วกด “+” เพื่อเพิ่มได้เช่นกัน', t),
                _bullet('แตะ ✕ เพื่อลบออกจากรายการ หรือกด “ล้างทั้งหมด”', t),
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
}
