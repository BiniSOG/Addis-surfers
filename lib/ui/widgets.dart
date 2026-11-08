import 'package:flutter/material.dart';

import '../audio/audio_manager.dart';
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
        onTap: onPressed == null
            ? null
            : () {
                AudioManager.instance.sfx(Sfx.click);
                onPressed!();
              },
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

class GemBadge extends StatelessWidget {
  const GemBadge({super.key, required this.amount, this.big = false});
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
          Icon(Icons.diamond_rounded, color: const Color(0xFF5EC8FF), size: 20 * s),
          SizedBox(width: 6 * s),
          Text(
            '$amount',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18 * s),
          ),
        ],
      ),
    );
  }
}

/// Round icon button with an optional badge (e.g. a "claim" dot).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.label,
    this.badge,
    this.color = const Color(0xFF14213D),
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? label;
  final String? badge;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: color.withValues(alpha: 0.85),
                shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 2.5)),
                elevation: 4,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    AudioManager.instance.sfx(Sfx.click);
                    onPressed();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(11),
                    child: Icon(icon, color: Colors.white, size: 26),
                  ),
                ),
              ),
              if (badge != null)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: ethRed,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                label!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-screen page used by Shop, Missions, Settings and Crew.
class MenuPage extends StatelessWidget {
  const MenuPage({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
    this.trailing,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xF20B132B),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      AudioManager.instance.sfx(Sfx.click);
                      onClose();
                    },
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 32),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  ?trailing,
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
