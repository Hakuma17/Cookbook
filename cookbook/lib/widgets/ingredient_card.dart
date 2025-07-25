// lib/widgets/ingredient_card.dart
// ---------------------------------------------------------------------------
// ★ 2025‑07‑20 – responsive re‑tune
//   • เพิ่ม width option + auto‑responsive (28 % screen, clamp 96‑140)
//   • คำนวณ fontSize ตาม cardW (12‑16 px) แสดงชื่อได้ 2 บรรทัด
//   • ต่อ baseUrl ให้ imageUrl อัตโนมัติ + placeholder
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import '../models/ingredient.dart';
import '../services/api_service.dart';

class IngredientCard extends StatelessWidget {
  final Ingredient ingredient;
  final VoidCallback? onTap;
  final double? width; // optional override

  const IngredientCard({
    super.key,
    required this.ingredient,
    this.onTap,
    this.width,
  });

  /* ─────────── helpers ─────────── */
  double _clamp(double v, double min, double max) =>
      v < min ? min : (v > max ? max : v);

  @override
  Widget build(BuildContext context) {
    /* ═════════════ responsive size ═════════════ */
    final scrW = MediaQuery.of(context).size.width;
    final cardW = width ?? _clamp(scrW * 0.28, 96, 140); // px (auto 28 %)
    final fontSize = _clamp(cardW * 0.13, 12, 16); // 13 % of width

    /* ═════════════ image url resolve ═════════════ */
    final imgUrl = ingredient.imageUrl.isNotEmpty
        ? (ingredient.imageUrl.startsWith('http')
            ? ingredient.imageUrl
            : '${ApiService.baseUrl}${ingredient.imageUrl}')
        : '';

    final colorScheme = Theme.of(context).colorScheme;

    /* ═════════════ UI ═════════════ */
    final card = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- image ---------------------------------------------------
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: imgUrl.isEmpty
                    ? Image.asset(
                        'assets/images/default_ingredients.png',
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        imgUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (c, child, prog) =>
                            prog == null ? child : _loader(colorScheme),
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/images/default_ingredients.png',
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
            ),
            // --- name ----------------------------------------------------
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                ingredient.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600, fontSize: fontSize),
              ),
            ),
          ],
        ),
      ),
    );

    return SizedBox(width: cardW, child: card);
  }

  Widget _loader(ColorScheme scheme) => Container(
        color: scheme.surfaceVariant,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
}
