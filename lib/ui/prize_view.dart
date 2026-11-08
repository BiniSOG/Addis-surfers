import 'package:flutter/material.dart';

import '../game/textures.dart';
import '../meta/rewards.dart';

(IconData, Color) prizeStyle(PrizeKind k) => switch (k) {
      PrizeKind.coins => (Icons.monetization_on_rounded, ethYellow),
      PrizeKind.gems => (Icons.diamond_rounded, const Color(0xFF5EC8FF)),
      PrizeKind.shield => (Icons.shield_rounded, const Color(0xFF26A69A)),
      PrizeKind.headStart => (Icons.rocket_launch_rounded, const Color(0xFFF08A00)),
      PrizeKind.mesob => (Icons.shopping_basket_rounded, const Color(0xFFE57373)),
      PrizeKind.character => (Icons.person_add_alt_1_rounded, const Color(0xFFBA68C8)),
    };

class PrizeChip extends StatelessWidget {
  const PrizeChip({super.key, required this.prize, this.size = 22});
  final Prize prize;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = prizeStyle(prize.kind);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: size),
        const SizedBox(width: 4),
        Text(prize.shortLabel,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * 0.7)),
      ],
    );
  }
}
