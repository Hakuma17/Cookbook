import 'package:flutter/material.dart';

class RankBadge extends StatelessWidget {
  final int? rank; // 1 = gold, 2 = silver, 3 = bronze
  final bool showWarning;

  const RankBadge({
    Key? key,
    this.rank,
    this.showWarning = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: _buildBadge(),
    );
  }

  Widget _buildBadge() {
    if (showWarning) {
      return Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.redAccent,
        ),
        child: const Center(
          child: Icon(Icons.priority_high, size: 16, color: Colors.white),
        ),
      );
    }

    if (rank == null || rank! > 3) {
      return const SizedBox.shrink();
    }

    final color = _getBadgeColor(rank!);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          rank.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _getBadgeColor(int rank) {
    return switch (rank) {
      1 => const Color(0xFFFFD700), // gold
      2 => const Color(0xFFB0B0B0), // silver
      3 => const Color(0xFFCD7F32), // bronze
      _ => Colors.grey,
    };
  }
}
