import 'package:flutter/material.dart';

import '../game/textures.dart';

/// The "ADDIS SURFERS" logotype in Ethiopian flag colours.
class GameLogo extends StatelessWidget {
  const GameLogo({super.key, this.size = 46});
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget word(String text, double fontSize) {
      final style = TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        height: 1.0,
        fontStyle: FontStyle.italic,
      );
      return Stack(
        children: [
          Text(
            text,
            style: style.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = fontSize * 0.22
                ..strokeJoin = StrokeJoin.round
                ..color = const Color(0xFF1B1B1B),
            ),
          ),
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [ethGreen, Color(0xFF3CCF5A), ethYellow, Color(0xFFFF8A00), ethRed],
              stops: [0, 0.3, 0.5, 0.72, 1],
            ).createShader(r),
            child: Text(text, style: style.copyWith(color: Colors.white)),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.rotate(angle: -0.05, child: word('ADDIS', size)),
        Transform.rotate(angle: -0.05, child: word('SURFERS', size * 0.92)),
        const SizedBox(height: 6),
        Text(
          'አዲስ ሰርፈርስ',
          style: TextStyle(
            fontFamily: 'NotoEthiopic',
            fontSize: size * 0.38,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
          ),
        ),
      ],
    );
  }
}

class CoinBadge extends StatelessWidget {
  const CoinBadge({super.key, required this.amount, this.big = false});
  final int amount;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final s = big ? 1.3 : 1.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 6 * s),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20 * s,
            height: 20 * s,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [Color(0xFFFFE27A), Color(0xFFF2A90F)]),
              border: Border.fromBorderSide(BorderSide(color: Color(0xFFB7770B), width: 2)),
            ),
          ),
          SizedBox(width: 6 * s),
          Text(
            '$amount',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18 * s,
            ),
          ),
        ],
      ),
    );
  }
}

class ChunkyButton extends StatelessWidget {
  const ChunkyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = ethGreen,
    this.icon,
    this.fontSize = 20,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;
  final double fontSize;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final child = Material(
      color: enabled ? color : Colors.grey.shade600,
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      shadowColor: Colors.black,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border(
              bottom: BorderSide(color: Colors.black.withValues(alpha: 0.3), width: 5),
            ),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: fontSize + 4),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: fontSize,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return child;
  }
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 380),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xEE14213D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ethYellow, width: 3),
        boxShadow: const [BoxShadow(blurRadius: 20, color: Colors.black45)],
      ),
      child: child,
    );
  }
}
