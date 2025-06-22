import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../utils/format_utils.dart';
import 'rank_badge.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onTap;
  final bool compact;
  final bool expanded;

  const RecipeCard({
    Key? key,
    required this.recipe,
    this.onTap,
    this.compact = false,
    this.expanded = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompactCard(context);
    if (expanded) return _buildExpandedCard(context);
    return _buildVerticalCard(context);
  }

  Widget _buildVerticalCard(BuildContext context) {
    const cardWidth = 116.0;
    const cardHeight = 177.0;
    const imageSize = 116.0;
    const borderRadius = 16.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth,
        height: cardHeight,
        margin: const EdgeInsets.only(right: 12),
        decoration: _cardDecoration(borderRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _buildImageWidget(
                    width: imageSize,
                    height: imageSize,
                    borderRadius: borderRadius),
                _buildBadge(),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Text(
                recipe.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _titleStyle(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: _buildRatingRow(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCard(BuildContext context) {
    const borderRadius = 16.0;
    const imageHeight = 160.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: _cardDecoration(borderRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _buildImageWidget(
                    width: double.infinity,
                    height: imageHeight,
                    borderRadius: borderRadius),
                _buildBadge(),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Text(
                recipe.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _titleStyle(),
              ),
            ),
            if (recipe.shortIngredients.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  recipe.shortIngredients,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF818181),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: _buildRatingRow(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedCard(BuildContext context) {
    const borderRadius = 16.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: _cardDecoration(borderRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageWidget(
                width: double.infinity,
                height: 160,
                borderRadius: borderRadius),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _titleStyle(),
                  ),
                  const SizedBox(height: 4),
                  if (recipe.shortIngredients.isNotEmpty)
                    Text(
                      recipe.shortIngredients,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF818181),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (recipe.prepTime > 0) ...[
                        const Icon(Icons.access_time,
                            size: 14, color: Color(0xFF888888)),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.prepTime} นาที',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF888888),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      const Icon(Icons.star,
                          size: 14, color: Color(0xFFFF9B05)),
                      const SizedBox(width: 4),
                      Text(
                        recipe.averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFA6A6A6),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.comment,
                          size: 14, color: Color(0xFFA6A6A6)),
                      const SizedBox(width: 4),
                      Text(
                        formatCount(recipe.reviewCount),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFA6A6A6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget(
      {required double width,
      required double height,
      double borderRadius = 0}) {
    final image = recipe.imageUrl.isNotEmpty
        ? Image.network(
            recipe.imageUrl,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallbackImage(width, height),
          )
        : _fallbackImage(width, height);

    return borderRadius > 0
        ? ClipRRect(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(borderRadius)),
            child: image,
          )
        : image;
  }

  Widget _buildBadge() {
    if (recipe.rank == null && !recipe.hasAllergy)
      return const SizedBox.shrink();
    return Positioned(
      top: 8,
      left: 8,
      child: RankBadge(
        rank: recipe.rank,
        showWarning: recipe.hasAllergy,
      ),
    );
  }

  BoxDecoration _cardDecoration(double borderRadius) {
    return BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFFBFBFB)),
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF063336).withOpacity(0.1),
          blurRadius: 16,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  TextStyle _titleStyle() {
    return const TextStyle(
      fontFamily: 'Montserrat',
      fontWeight: FontWeight.w600,
      fontSize: 14,
      color: Color(0xFF0A2533),
    );
  }

  Widget _buildRatingRow() {
    return Row(
      children: [
        const Icon(Icons.star, size: 15, color: Color(0xFFFF9B05)),
        const SizedBox(width: 4),
        Text(
          recipe.averageRating.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFFA6A6A6),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${recipe.reviewCount} รีวิว',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFFA6A6A6),
          ),
        ),
      ],
    );
  }

  Widget _fallbackImage(double width, double height) {
    return Image.asset(
      'assets/images/default_recipe.png',
      width: width,
      height: height,
      fit: BoxFit.cover,
    );
  }
}
