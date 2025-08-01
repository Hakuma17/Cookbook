import 'package:flutter/material.dart';
import '../models/ingredient.dart';
import '../services/api_service.dart';

// ★★★ [NEW] อ่านค่าสวิตช์ “ตัดคำภาษาไทย” จาก SettingsStore
import 'package:provider/provider.dart';
import '../stores/settings_store.dart';

// [CACHE] จำผลว่ามีเมนูจากวัตถุดิบนั้น ๆ ไหม เพื่อลดดีเลย์ครั้งถัดไป
final Map<String, bool> _ingredientExistenceCache = {};

// [TIMEOUT] จำกัดเวลาพรีเช็ค เพื่อไม่ให้ผู้ใช้รอเกินไป
const Duration _precheckTimeout = Duration(milliseconds: 1200);

class IngredientCard extends StatelessWidget {
  final Ingredient ingredient; // ข้อมูลวัตถุดิบแต่ละอัน
  final VoidCallback? onTap; // ฟังก์ชันตอนกดการ์ด (optional)
  final double? width; // ความกว้างของการ์ด (ถ้าไม่กำหนด จะ auto)

  const IngredientCard({
    super.key,
    required this.ingredient,
    this.onTap,
    this.width,
  });

  // ฟังก์ชัน clamp ค่าระหว่าง min–max (ใช้ใน responsive)
  double _clamp(double v, double min, double max) =>
      v < min ? min : (v > max ? max : v);

  @override
  Widget build(BuildContext context) {
    // คำนวณขนาดการ์ดตามหน้าจอ
    final scrW = MediaQuery.of(context).size.width;
    final cardW = width ?? _clamp(scrW * 0.28, 96, 140); // 28% ของหน้าจอ
    final fontSize = _clamp(cardW * 0.13, 12, 16); // ฟอนต์ 13% ของ cardW

    // เตรียม URL รูปภาพ (ต่อ baseUrl ถ้าไม่ใช่ http)
    final imgUrl = ingredient.imageUrl.isNotEmpty
        ? (ingredient.imageUrl.startsWith('http')
            ? ingredient.imageUrl
            : '${ApiService.baseUrl}${ingredient.imageUrl}')
        : '';

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // สร้างการ์ดวัตถุดิบ (ขนาดและสไตล์)
    return SizedBox(
      width: cardW, // กำหนดความกว้างการ์ด
      child: Card(
        clipBehavior: Clip.antiAlias, // ตัดมุมภาพให้นุ่ม
        child: InkWell(
          onTap: onTap ??
              () =>
                  _handleTap(context), // ถ้าไม่ได้ส่ง onTap → ใช้ auto-precheck
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // แสดงรูปภาพวัตถุดิบ
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1, // ทำให้รูปเป็นสี่เหลี่ยมจัตุรัส
                  child: imgUrl.isEmpty
                      ? Image.asset(
                          'assets/images/default_ingredients.png',
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          imgUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (c, child, prog) => prog == null
                              ? child
                              : _loader(cs), // แสดง loader ระหว่างโหลด
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/images/default_ingredients.png', // fallback ถ้าโหลดไม่สำเร็จ
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),

              // แสดงชื่อวัตถุดิบ
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  ingredient.displayName?.trim().isNotEmpty == true
                      ? ingredient
                          .displayName! // ถ้ามี displayName ให้แสดงแทน name
                      : ingredient.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis, // ตัดข้อความถ้ายาวเกิน
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: fontSize,
                    color: cs.onSurface, // ใช้สีจากธีม
                    height: 1.15, // ระยะห่างบรรทัด
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // วิดเจ็ตโหลดภาพระหว่าง loading
  Widget _loader(ColorScheme scheme) => Container(
        color: scheme.surfaceVariant, // สีพื้นหลังระหว่างโหลด
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );

  // ถ้าไม่ได้ส่ง onTap → ใช้อันนี้แทน (ตรวจวัตถุดิบก่อน navigate)
  Future<void> _handleTap(BuildContext context) async {
    // ★★★ [NEW] แจ้ง backend ว่าปัจจุบันเปิด/ปิด “ตัดคำภาษาไทย” อยู่หรือไม่
    //     - ดีฟอลต์: ปิด (ดู SettingsStore.initial ค่า false)
    final tokenize =
        context.read<SettingsStore>().searchTokenizeEnabled; // true/false

    // [FIX][UX] ใช้ชื่อที่ “แสดงผล” ถ้ามี เพื่อกันเคส alias ภาษาไทย
    // ================== บรรทัดที่แก้ไข ==================
    final nameForSearch = ingredient.name.trim();
    // =================================================

    // [CACHE] ถ้าเคยรู้ผลแล้ว ตอบสนองทันที
    final cached = _ingredientExistenceCache[nameForSearch];
    if (cached != null) {
      if (!context.mounted) return;
      if (cached) {
        // มีเมนู → ไปหน้า Search ทันที
        Navigator.pushNamed(context, '/search', arguments: {
          'ingredients': [nameForSearch]
        });
      } else {
        // ไม่มีเมนู → แจ้งทันที
        await _showNoResultDialog(context, nameForSearch);
      }
      return;
    }

    // [TIMEOUT] ถ้าพรีเช็คช้าเกินไป จะ "พาเข้า Search" เพื่อไม่ให้ผู้ใช้รอ/หงุดหงิด
    bool? hasAny;
    try {
      hasAny = await _precheckHasAny(nameForSearch, tokenize)
          .timeout(_precheckTimeout, onTimeout: () => null);
    } catch (_) {
      hasAny = null; // error = ไม่บล็อกผู้ใช้
    }

    if (!context.mounted) return;

    if (hasAny == true) {
      _ingredientExistenceCache[nameForSearch] = true; // [CACHE]
      Navigator.pushNamed(context, '/search', arguments: {
        'ingredients': [nameForSearch]
      });
      return;
    }

    if (hasAny == false) {
      _ingredientExistenceCache[nameForSearch] = false; // [CACHE]
      await _showNoResultDialog(context, nameForSearch);
      return;
    }

    // hasAny == null (timeout/exception) → อย่าบล็อก นำทางให้ค้นต่อ
    Navigator.pushNamed(context, '/search', arguments: {
      'ingredients': [nameForSearch]
    });
  }

  // [FALLBACK] พรีเช็ค 2 จังหวะ: include → ถ้าไม่พบลอง q
  Future<bool?> _precheckHasAny(String name, bool tokenize) async {
    try {
      final r1 = await ApiService.searchRecipes(
        ingredientNames: [name],
        limit: 1,
        tokenize: tokenize,
      );
      if (_hasResults(r1)) return true;

      final r2 = await ApiService.searchRecipes(
        query: name,
        limit: 1,
        tokenize: tokenize,
      );
      return _hasResults(r2);
    } catch (_) {
      return null; // ให้ผู้ใช้ไปดูในหน้า Search แทน (ไม่บล็อก)
    }
  }

  Future<void> _showNoResultDialog(BuildContext context, String name) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยังไม่พบสูตรที่ใช้วัตถุดิบนี้'),
        content: Text('วัตถุดิบ: $name'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
          // [UX] เสนอ “ลองค้นหา” ต่อได้ทันที
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (!context.mounted) return;
              Navigator.pushNamed(context, '/search', arguments: {
                'ingredients': [name]
              });
            },
            child: const Text('ลองค้นหา'),
          ),
        ],
      ),
    );
  }

  // ฟังก์ชันเช็คว่ามีผลลัพธ์จาก API หรือไม่
  bool _hasResults(dynamic r) {
    // [FIX] กัน false-negative: รองรับทั้ง SearchResponse, Map, List
    if (r == null) return false;

    // กรณีเป็น SearchResponse (ที่ ApiService คืน)
    try {
      final recs = (r as dynamic).recipes;
      if (recs is List && recs.isNotEmpty) return true;
      final t = (r as dynamic).total ??
          (r as dynamic).totalCount ??
          (r as dynamic).count;
      if (t is num && t > 0) return true;
    } catch (_) {}

    // กรณีเป็น List ตรง ๆ
    if (r is List) return r.isNotEmpty;

    // กรณีเป็น Map JSON ตรง ๆ { data:[...], total:... }
    if (r is Map) {
      final total = r['total'] ?? r['totalCount'] ?? r['count'];
      if (total is num && total > 0) return true;
      for (final k in const ['data', 'recipes', 'items', 'results']) {
        final v = r[k];
        if (v is List && v.isNotEmpty) return true;
      }
    }

    return false;
  }
}
