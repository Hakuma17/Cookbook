import 'package:flutter/material.dart';
import '../models/cart_ingredient.dart';
import '../models/unit_display_mode.dart';
import '../utils/unit_convert.dart';
import 'cart_ingredient_tile.dart';

/// โหมดเรียงลำดับ
enum _SortMode { nameAsc, group }

class CartIngredientListSection extends StatefulWidget {
  final List<CartIngredient> ingredients;

  /// ถ้าพาเรนต์อยาก “คุมเอง” ให้ส่งค่า unitMode มาด้วยและอัปเดตใน onUnitModeChanged
  final UnitDisplayMode unitMode;
  final ValueChanged<UnitDisplayMode>? onUnitModeChanged;

  const CartIngredientListSection({
    super.key,
    required this.ingredients,
    this.unitMode = UnitDisplayMode.original,
    this.onUnitModeChanged,
  });

  @override
  State<CartIngredientListSection> createState() =>
      _CartIngredientListSectionState();
}

class _CartIngredientListSectionState extends State<CartIngredientListSection>
    with AutomaticKeepAliveClientMixin {
  _SortMode _sort = _SortMode.nameAsc;

  /// ทำให้คอมโพเนนต์ “เก็บสถานะหน่วยเอง”
  late UnitDisplayMode _unitMode;

  List<CartIngredient> _displayIngredients = [];

  /// ★ เก็บสถานะ `_sort` และ `_unitMode` ลง PageStorage กันรีเซ็ตเวลาถูก remount
  static const _psSortKey = 'cart_sort_mode_v1';
  static const _psUnitKey = 'cart_unit_mode_v1';

  @override
  void initState() {
    super.initState();
    _unitMode = widget.unitMode; // sync ค่าเริ่มจากพาเรนต์
    _displayIngredients = _getProcessedAndSortedList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ★ ลองกู้ค่าที่เคยบันทึกไว้ใน PageStorage (ถ้ามี)
    final bucket = PageStorage.of(context);
    final savedSort = bucket.readState(context, identifier: _psSortKey);
    if (savedSort is int &&
        savedSort >= 0 &&
        savedSort < _SortMode.values.length &&
        _sort != _SortMode.values[savedSort]) {
      _sort = _SortMode.values[savedSort];
      _displayIngredients = _getProcessedAndSortedList();
    }
    final savedUnit = bucket.readState(context, identifier: _psUnitKey);
    if (savedUnit is int &&
        savedUnit >= 0 &&
        savedUnit < UnitDisplayMode.values.length &&
        _unitMode != UnitDisplayMode.values[savedUnit]) {
      _unitMode = UnitDisplayMode.values[savedUnit];
      _displayIngredients = _getProcessedAndSortedList();
    }
  }

  @override
  void didUpdateWidget(CartIngredientListSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    // ถ้าพาเรนต์ส่งรายการใหม่ หรือเปลี่ยน unitMode จากภายนอก → รีคอมพิวต์
    final listChanged = widget.ingredients != oldWidget.ingredients;
    final parentUnitChanged = widget.unitMode != oldWidget.unitMode;

    // ถ้าพาเรนต์ “บังคับ” หน่วยใหม่มาให้ (controlled) → sync เข้า _unitMode ด้วย
    if (parentUnitChanged && widget.unitMode != _unitMode) {
      _unitMode = widget.unitMode;
    }

    if (listChanged || parentUnitChanged) {
      setState(() {
        _displayIngredients = _getProcessedAndSortedList();
      });
    }
  }

  /// ให้คอมโพเนนต์ถูก keep-alive เวลาอยู่ใน TabBarView/ PageView
  @override
  bool get wantKeepAlive => true;

  /// ฟังก์ชันสำหรับรวมและเรียงข้อมูลทั้งหมด
  List<CartIngredient> _getProcessedAndSortedList() {
    if (widget.ingredients.isEmpty) return [];

    // ★ เปลี่ยนไปใช้ `_unitMode` (สถานะภายใน) ไม่ใช่ widget.unitMode
    final merged = _mergeForDisplay(widget.ingredients, _unitMode);

    merged.sort((a, b) {
      switch (_sort) {
        case _SortMode.nameAsc:
          return _thaiKey(a.name).compareTo(_thaiKey(b.name));
        case _SortMode.group:
          final ga = _groupOrder(a.groupCode);
          final gb = _groupOrder(b.groupCode);
          final c = ga.compareTo(gb);
          if (c != 0) return c;
          return _thaiKey(a.name).compareTo(_thaiKey(b.name));
      }
    });

    return merged;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // สำหรับ keep-alive
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    if (widget.ingredients.isEmpty) {
      return _buildEmptyState(textTheme, theme);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // ── แถวเครื่องมือ: เรียงตาม + โหมดหน่วย ────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // ★ ปุ่มเรียงตาม (แสดงเฉพาะชื่อแบบภาพตัวอย่าง)
              Flexible(
                child: _SortMenu(
                  mode: _sort,
                  onChanged: (newMode) {
                    if (_sort != newMode) {
                      setState(() {
                        _sort = newMode;
                        _displayIngredients = _getProcessedAndSortedList();
                      });
                      PageStorage.of(context).writeState(
                        context,
                        newMode.index,
                        identifier: _psSortKey,
                      );
                    }
                  },
                  compact: true,
                  labelOnly: true,
                ),
              ),
              const Spacer(),
              // ★ ปุ่มเลือกหน่วย (เดิม/กรัม) – แสดงเครื่องหมายถูกบนตัวเลือกที่เลือก
              SegmentedButton<UnitDisplayMode>(
                showSelectedIcon: true,
                segments: const [
                  ButtonSegment(
                    value: UnitDisplayMode.original,
                    icon: Icon(Icons.layers_outlined),
                    label: Text('เดิม'),
                  ),
                  ButtonSegment(
                    value: UnitDisplayMode.grams,
                    icon: Icon(Icons.scale),
                    label: Text('กรัม'),
                  ),
                ],
                selected: {_unitMode},
                onSelectionChanged: (s) {
                  final newMode = s.first;
                  if (newMode != _unitMode) {
                    setState(() {
                      _unitMode = newMode;
                      _displayIngredients = _getProcessedAndSortedList();
                    });
                    widget.onUnitModeChanged?.call(newMode);
                    PageStorage.of(context).writeState(
                      context,
                      newMode.index,
                      identifier: _psUnitKey,
                    );
                  }
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  // เปลี่ยนเป็น WidgetStatePropertyAll ตามชั้น Widgets
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── ★ ส่วนหัวคอลัมน์ “วัตถุดิบ” / “ปริมาณ(หน่วย)” ────────────────
          _buildColumnsHeader(context),

          const SizedBox(height: 6),

          // รายการวัตถุดิบ
          _buildIngredientListWidget(),
        ],
      ),
    );
  }

  /// ★ Header ของคอลัมน์ซ้าย/ขวา (อัปเดตข้อความตามโหมดหน่วย)
  Widget _buildColumnsHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // ข้อความฝั่งขวาจะเปลี่ยนตามโหมดหน่วย
    final rightLabel =
        _unitMode == UnitDisplayMode.grams ? 'น้ำหนัก (กรัม)' : 'ปริมาณตามสูตร';
    final totalCount = _displayIngredients.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest, // ขับให้เด่นขึ้น
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant, width: 1.2),
      ),
      child: Row(
        children: [
          // ซ้าย: “วัตถุดิบ”
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'วัตถุดิบ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ทั้งหมด $totalCount รายการ',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // ขวา: ปริมาณ/น้ำหนัก (ชิดขวา)
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                rightLabel,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// สร้าง Widget รายการวัตถุดิบ (มีโหมดย่อยตาม _sort)
  Widget _buildIngredientListWidget() {
    if (_sort != _SortMode.group) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _displayIngredients.length,
        itemBuilder: (_, i) => CartIngredientTile(
          ingredient: _displayIngredients[i],
          unitMode: _unitMode, // ★ ส่งหน่วยภายใน
        ),
      );
    } else {
      final List<Widget> groupedItems = [];
      String? currentGroup;

      // หมายเหตุ: header คอลัมน์แสดงด้านบนครั้งเดียวแล้ว (ไม่ต้องซ้ำในแต่ละกลุ่ม)
      for (final ingredient in _displayIngredients) {
        final groupName = ingredient.groupName ?? 'อื่นๆ';
        if (groupName != currentGroup) {
          if (currentGroup != null) {
            groupedItems
                .add(const Divider(height: 24, indent: 8, endIndent: 8));
          }
          groupedItems.add(_buildGroupHeader(groupName));
          currentGroup = groupName;
        }
        groupedItems.add(CartIngredientTile(
          ingredient: ingredient,
          unitMode: _unitMode, // ★ ส่งหน่วยภายใน
        ));
      }
      return Column(children: groupedItems);
    }
  }

  // Header ของกลุ่ม
  Widget _buildGroupHeader(String name) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0, top: 4.0),
      child: Text(
        name,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  List<CartIngredient> _mergeForDisplay(
    List<CartIngredient> src,
    UnitDisplayMode mode,
  ) {
    final byId = <int, List<CartIngredient>>{};
    for (final it in src) {
      byId.putIfAbsent(it.ingredientId, () => []).add(it);
    }
    final out = <CartIngredient>[];
    for (final items in byId.values) {
      final base = items.first;
      if (mode == UnitDisplayMode.original) {
        final byUnit = <String, CartIngredient>{};
        for (final it in items) {
          final key = it.unit.trim();
          byUnit.update(
            key,
            (ex) => ex.copyWith(quantity: ex.quantity + it.quantity),
            ifAbsent: () => it,
          );
        }
        out.addAll(byUnit.values);
      } else {
        double gramsSum = 0;
        final leftovers = <String, CartIngredient>{};
        for (final it in items) {
          final gActual = it.gramsActual;
          if (gActual != null && gActual > 0) {
            gramsSum += gActual;
            continue;
          }
          final gApprox = UnitConvert.approximateGrams(it.quantity, it.unit);
          if (gApprox != null) {
            gramsSum += gApprox;
            continue;
          }
          final key = it.unit.trim();
          leftovers.update(
            key,
            (ex) => ex.copyWith(quantity: ex.quantity + it.quantity),
            ifAbsent: () => it,
          );
        }
        if (gramsSum > 0) {
          out.add(CartIngredient(
            ingredientId: base.ingredientId,
            name: base.name,
            quantity: gramsSum,
            unit: 'กรัม',
            imageUrl: base.imageUrl,
            unitConflict: false,
            hasAllergy: items.any((e) => e.hasAllergy),
            gramsActual: gramsSum,
            groupCode: base.groupCode,
            groupName: base.groupName,
            nutritionId: base.nutritionId,
          ));
        }
        out.addAll(leftovers.values);
      }
    }
    return out;
  }

  String _thaiKey(String s) {
    final lowered = s.trim().toLowerCase();
    final diacritics = RegExp(r'[\u0E31\u0E34-\u0E3A\u0E47-\u0E4E]');
    return lowered.replaceAll(diacritics, '');
  }

  int _groupOrder(String? code) {
    final s = (code ?? '16').trim();
    return int.tryParse(s) ?? 16;
  }

  Widget _buildEmptyState(TextTheme textTheme, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48.0),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_basket_outlined,
              size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('ยังไม่มีวัตถุดิบในตะกร้า',
              style: textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
        ],
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  final _SortMode mode;
  final ValueChanged<_SortMode> onChanged;
  final bool compact; // ★ ใหม่: โหมดปุ่มสั้น (ใช้ไอคอนช่วย)
  final bool labelOnly; // ★ ใหม่: แสดงเฉพาะข้อความ (ไม่ขึ้นคำว่า "เรียงตาม:")

  const _SortMenu({
    required this.mode,
    required this.onChanged,
    this.compact = false,
    this.labelOnly = false,
  });

  String _getDisplayLabel(_SortMode m) {
    switch (m) {
      case _SortMode.nameAsc:
        return 'ชื่อ (ก–ฮ)';
      case _SortMode.group:
        return 'กลุ่มวัตถุดิบ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = _getDisplayLabel(mode);

    return PopupMenuButton<_SortMode>(
      tooltip: 'เรียงตาม',
      initialValue: mode,
      onSelected: onChanged,
      itemBuilder: (context) => const [
        PopupMenuItem(value: _SortMode.nameAsc, child: Text('ชื่อ (ก–ฮ)')),
        PopupMenuItem(value: _SortMode.group, child: Text('กลุ่มวัตถุดิบ')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(22),
          color: cs.surface,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort, size: 18),
            const SizedBox(width: 6),
            Text(
              labelOnly
                  ? label
                  : (compact ? 'เรียง: $label' : 'เรียงตาม: $label'),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}
