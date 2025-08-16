// lib/widgets/ingredient_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ingredient.dart';
import '../models/ingredient_group.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../stores/settings_store.dart';
import '../utils/safe_image.dart';
import 'empty_result_dialog.dart';

// ===== Cache & Config ===================================================

// จำผลว่ามีสูตรจากวัตถุดิบ/กลุ่มนั้น ๆ ไหม (กันยิงซ้ำ ๆ)
final Map<String, bool> _ingredientExistenceCache = {};
final Map<String, bool> _groupExistenceCache = {};

// จำกัดเวลาพรีเช็ค (ไม่ให้ผู้ใช้รอนานก่อนนำทาง)
const Duration _precheckTimeout = Duration(milliseconds: 1200);

// อัตราส่วนรูป 4:3 ใช้ร่วมหลายหน้า
const double kIngredientImageAspectRatio = 4 / 3;

// ===== Main Card ========================================================

class IngredientCard extends StatelessWidget {
  /// รองรับได้ทั้ง “วัตถุดิบเดี่ยว” และ “กลุ่มวัตถุดิบ” (ต้องส่งอย่างใดอย่างหนึ่ง)
  final Ingredient? ingredient;
  final IngredientGroup? group;

  /// ถ้าส่ง onTap มา จะ override พฤติกรรม default
  final VoidCallback? onTap;

  /// บางหน้าควบคุมความกว้างเองได้ (ปกติปล่อยให้ parent layout ทำงาน)
  final double? width;

  const IngredientCard({
    super.key,
    this.ingredient,
    this.group,
    this.onTap,
    this.width,
  }) : assert(
          (ingredient != null) ^ (group != null),
          'IngredientCard ต้องรับ ingredient หรือ group อย่างใดอย่างหนึ่ง',
        );

  // คำนวณความสูงกล่องชื่อ 2 บรรทัด (ตามสไตล์จริง)
  static double titleBoxHeightOf(BuildContext context) {
    final theme = Theme.of(context);
    final scale = MediaQuery.textScaleFactorOf(context);
    final s =
        (theme.textTheme.titleMedium ?? const TextStyle(fontSize: 16)).copyWith(
      height: 1.15,
    );
    final lineH = (s.fontSize ?? 16) * (s.height ?? 1.2) * scale;
    return lineH * 2;
  }

  double _clamp(double v, double min, double max) =>
      v < min ? min : (v > max ? max : v);

  @override
  Widget build(BuildContext context) {
    final scrW = MediaQuery.of(context).size.width;
    final cardW = width ?? _clamp(scrW * 0.28, 96, 140);

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final titleBase =
        (theme.textTheme.titleMedium ?? const TextStyle(fontSize: 16))
            .copyWith(height: 1.15, color: cs.onSurface);
    final titleBoxH = IngredientCard.titleBoxHeightOf(context);

    final bool isGroupCard = group != null;

    // ชื่อ display (พยายามใช้ที่ “อ่านง่าย” ก่อน)
    final String displayName = isGroupCard
        ? ([
            group!.displayName,
            group!.groupName, // บางโมเดลตั้งชื่อโชว์ไว้ใน groupName
            group!.name,
          ].firstWhere(
            (s) => (s?.trim().isNotEmpty ?? false),
            orElse: () => group!.name,
          )!)
            .trim()
        : ([
            ingredient!.displayName,
            ingredient!.name,
          ].firstWhere(
            (s) => (s?.trim().isNotEmpty ?? false),
            orElse: () => ingredient!.name,
          )!)
            .trim();

    // URL รูป (ถ้าเว้นว่างและเป็น "กลุ่ม" → ใช้ asset เป็นภาพหลักทันที)
    final String rawUrl = isGroupCard
        ? (group!.coverUrl?.trim().isNotEmpty == true
            ? group!.coverUrl!
            : (group!.imageUrl ?? ''))
        : (ingredient!.imageUrl ?? '');
    final bool hasRemoteImage = rawUrl.trim().isNotEmpty;

    // จำนวนสูตรบนการ์ด (เฉพาะกลุ่ม)
    final int recipeCount =
        (group?.recipeCount ?? group?.totalRecipes ?? 0).clamp(0, 1 << 31);

    return SizedBox(
      width: cardW,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap ??
              () => isGroupCard
                  ? _handleTapGroup(context)
                  : _handleTapIngredient(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // รูป 4:3 (SafeImage หรือ Asset fallback สำหรับกลุ่ม)
              AspectRatio(
                aspectRatio: kIngredientImageAspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (isGroupCard && !hasRemoteImage)
                      // กลุ่มที่ไม่มีรูป → ใช้รูป default_group เป็น "ภาพหลัก"
                      Image.asset(
                        'assets/images/default_group.png',
                        fit: BoxFit.cover,
                      )
                    else
                      SafeImage(
                        url: rawUrl,
                        fit: BoxFit.cover,
                        // ถ้าโหลดรูปพัง → fallback ตามชนิด
                        fallbackAsset: isGroupCard
                            ? 'assets/images/default_group.png'
                            : 'assets/images/default_ingredients.png',
                      ),

                    // มุมซ้ายบน: ป้าย "สูตร N" — ย้ายมุมซ้ายแทนไอคอนเดิม
                    if (isGroupCard && recipeCount > 0)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _RecipeCountBadge(count: recipeCount),
                      ),
                  ],
                ),
              ),

              // ชื่อ (คงไว้สองบรรทัด)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SizedBox(
                  height: titleBoxH,
                  child: Center(
                    child: Text(
                      displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: titleBase,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== Tap handlers ====================================================

  // วัตถุดิบเดี่ยว: พรีเช็คก่อน ถ้าไม่มีสูตรให้เด้ง dialog (ยกเลิกไม่ทำอะไร)
  Future<void> _handleTapIngredient(BuildContext context) async {
    final tokenize = context.read<SettingsStore>().searchTokenizeEnabled;
    final nameForSearch = ingredient!.name.trim();

    final cached = _ingredientExistenceCache[nameForSearch];
    if (cached != null) {
      if (!context.mounted) return;
      if (cached) {
        Navigator.pushNamed(context, '/search', arguments: {
          'ingredients': [nameForSearch]
        });
      } else {
        await _showNoResultDialog(context, nameForSearch);
      }
      return;
    }

    bool? hasAny;
    try {
      hasAny = await _precheckHasAny(nameForSearch, tokenize)
          .timeout(_precheckTimeout, onTimeout: () => null);
    } catch (_) {
      hasAny = null;
    }

    if (!context.mounted) return;

    if (hasAny == true) {
      _ingredientExistenceCache[nameForSearch] = true;
      Navigator.pushNamed(context, '/search', arguments: {
        'ingredients': [nameForSearch]
      });
      return;
    }
    if (hasAny == false) {
      _ingredientExistenceCache[nameForSearch] = false;
      await _showNoResultDialog(context, nameForSearch);
      return;
    }

    // เช็คไม่ทันเวลา/พลาด → นำทางไปก่อน
    Navigator.pushNamed(context, '/search', arguments: {
      'ingredients': [nameForSearch]
    });
  }

  // กลุ่มวัตถุดิบ: ใช้ apiGroupValue ถ้ามี (แม็ปตรงกับ backend)
  Future<void> _handleTapGroup(BuildContext context) async {
    final groupValue = (group!.apiGroupValue?.trim().isNotEmpty == true)
        ? group!.apiGroupValue!.trim()
        : group!.name.trim();

    final cached = _groupExistenceCache[groupValue];
    if (cached != null) {
      if (!context.mounted) return;
      if (cached) {
        Navigator.pushNamed(context, '/search',
            arguments: {'group': groupValue});
      } else {
        await _showNoGroupResultDialog(context, _friendlyGroupName());
      }
      return;
    }

    bool? hasAny;
    try {
      final List<Recipe> list = await ApiService.fetchRecipesByGroup(
        group: groupValue,
        page: 1,
        limit: 1,
        sort: 'latest',
      ).timeout(_precheckTimeout, onTimeout: () => const <Recipe>[]);
      hasAny = list.isNotEmpty;
    } catch (_) {
      hasAny = null; // ถ้าเช็คพลาด → อนุญาตให้นำทางไปก่อน
    }

    if (!context.mounted) return;

    if (hasAny == true) {
      _groupExistenceCache[groupValue] = true;
      Navigator.pushNamed(context, '/search', arguments: {'group': groupValue});
      return;
    }
    if (hasAny == false) {
      _groupExistenceCache[groupValue] = false;
      await _showNoGroupResultDialog(context, _friendlyGroupName());
      return;
    }

    Navigator.pushNamed(context, '/search', arguments: {'group': groupValue});
  }

  String _friendlyGroupName() => (group!.displayName?.trim().isNotEmpty == true
      ? group!.displayName!.trim()
      : (group!.groupName?.trim().isNotEmpty == true
          ? group!.groupName!.trim()
          : group!.name.trim()));

  // ===== Prechecks =======================================================

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
      return null;
    }
  }

  // ===== Dialogs =========================================================

  Future<void> _showNoResultDialog(BuildContext context, String name) async {
    await showDialog(
      context: context,
      builder: (_) => EmptyResultDialog(
        subject: name, // ไม่ต้องเติมคำว่า "กลุ่ม"
        onProceed: () {
          if (!context.mounted) return;
          Navigator.pushNamed(context, '/search', arguments: {
            'ingredients': [name]
          });
        },
      ),
    );
  }

  Future<void> _showNoGroupResultDialog(
      BuildContext context, String displayName) async {
    await showDialog(
      context: context,
      builder: (_) => EmptyResultDialog(
        subject: displayName, // แสดงชื่ออ่านง่าย เช่น กุ้งทะเล
        onProceed: () {
          if (!context.mounted) return;
          final groupValue = (group!.apiGroupValue?.trim().isNotEmpty == true)
              ? group!.apiGroupValue!.trim()
              : group!.name.trim();
          Navigator.pushNamed(context, '/search',
              arguments: {'group': groupValue});
        },
      ),
    );
  }

  // ===== Utils ===========================================================

  bool _hasResults(dynamic r) {
    if (r == null) return false;
    try {
      final recs = (r as dynamic).recipes;
      if (recs is List && recs.isNotEmpty) return true;
      final t = (r as dynamic).total ??
          (r as dynamic).totalCount ??
          (r as dynamic).count;
      if (t is num && t > 0) return true;
    } catch (_) {}
    if (r is List) return r.isNotEmpty;
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

// ===== Badge ============================================================

/// ป้ายจำนวนสูตร: "สูตร N"
class _RecipeCountBadge extends StatelessWidget {
  const _RecipeCountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: 'จำนวนสูตร $count สูตร',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              offset: const Offset(0, 2),
              color: Colors.black.withOpacity(.12),
            ),
          ],
        ),
        child: Text(
          'สูตร $count',
          style: TextStyle(
            fontSize: 11,
            height: 1.0,
            fontWeight: FontWeight.w800,
            color: cs.onPrimary,
          ),
        ),
      ),
    );
  }
}
