import 'package:flutter/material.dart';
import '../models/recipe.dart';

class MyRecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onTap;

  const MyRecipeCard({
    Key? key,
    required this.recipe,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1.2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          splashColor: const Color(0xFFFFF1E0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── รูปภาพ ───
              SizedBox(
                height: 140,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: _buildImage(),
                    ),
                    if (recipe.hasAllergy)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.redAccent,
                          ),
                          child: const Icon(Icons.priority_high,
                              size: 16, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),

              // ─── ชื่อเมนู ───
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Text(
                  recipe.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Montserrat',
                    color: Color(0xFF0A2533),
                  ),
                ),
              ),

              // ─── คะแนน + รีวิว ───
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Color(0xFFFF9B05)),
                    const SizedBox(width: 6),
                    Text(
                      recipe.averageRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF555555),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '| ${recipe.reviewCount} ความคิดเห็น',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF999999),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (recipe.imageUrl.isNotEmpty) {
      return Image.network(
        recipe.imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _fallbackImage(),
      );
    }
    return _fallbackImage();
  }

  Widget _fallbackImage() {
    return Image.asset(
      'assets/images/default_recipe.png',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }
}
