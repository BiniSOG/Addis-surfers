import 'dart:math';

import 'package:flutter/material.dart';

import '../audio/audio_manager.dart';
import '../game/textures.dart';
import '../meta/rewards.dart';
import '../progress.dart';
import 'prize_view.dart';
import 'widgets.dart';

/// Opens one Mesob Surprise basket with a little reveal animation.
Future<void> openMesobDialog(BuildContext context) async {
  final res = await Progress.instance.openMesob();
  if (res == null || !context.mounted) return;
  final (index, text) = res;
  await showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: _MesobReveal(prize: mesobPrizes[index], text: text),
    ),
  );
}

class _MesobReveal extends StatefulWidget {
  const _MesobReveal({required this.prize, required this.text});
  final Prize prize;
  final String text;

  @override
  State<_MesobReveal> createState() => _MesobRevealState();
}

class _MesobRevealState extends State<_MesobReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();
  bool _played = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (!_played && _c.value > 0.55) {
        _played = true;
        AudioManager.instance.sfx(Sfx.boxOpen);
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _c.value;
    final shake = t < 0.55 ? sin(t * 60) * 0.12 * (t / 0.55) : 0.0;
    final open = ((t - 0.55) / 0.2).clamp(0.0, 1.0);
    final reveal = Curves.elasticOut.transform(((t - 0.6) / 0.4).clamp(0.0, 1.0));
    final (icon, color) = prizeStyle(widget.prize.kind);
    return Panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('MESOB SURPRISE',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (reveal > 0)
                  Transform.scale(
                    scale: reveal,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [color.withValues(alpha: 0.6), Colors.transparent]),
                      ),
                      child: Icon(icon, color: color, size: 80),
                    ),
                  ),
                Opacity(
                  opacity: 1 - open,
                  child: Transform.rotate(
                    angle: shake,
                    child: CustomPaint(
                      size: const Size(150, 170),
                      painter: _MesobPainter(lidLift: open),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Opacity(
            opacity: reveal.clamp(0.0, 1.0),
            child: Text(widget.text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: ethYellow, fontSize: 20, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 16),
          ChunkyButton(
            label: 'NICE!',
            onPressed: t < 1 ? null : () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

/// A woven mesob basket with a conical lid.
class _MesobPainter extends CustomPainter {
  _MesobPainter({required this.lidLift});
  final double lidLift;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final bands = [ethGreen, ethYellow, ethRed, const Color(0xFF8D6E63)];
    // Base (bowl + foot).
    final base = Path()
      ..moveTo(w * 0.12, h * 0.55)
      ..lineTo(w * 0.88, h * 0.55)
      ..quadraticBezierTo(w * 0.85, h * 0.78, w * 0.62, h * 0.82)
      ..lineTo(w * 0.7, h)
      ..lineTo(w * 0.3, h)
      ..lineTo(w * 0.38, h * 0.82)
      ..quadraticBezierTo(w * 0.15, h * 0.78, w * 0.12, h * 0.55)
      ..close();
    canvas.save();
    canvas.clipPath(base);
    for (var i = 0; i < 8; i++) {
      canvas.drawRect(Rect.fromLTWH(0, h * 0.55 + i * h * 0.06, w, h * 0.06),
          Paint()..color = bands[i % bands.length]);
    }
    canvas.restore();
    canvas.drawPath(base, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = const Color(0xFF3E2723));
    // Lid.
    canvas.save();
    canvas.translate(0, -lidLift * h * 0.4);
    final lid = Path()
      ..moveTo(w * 0.08, h * 0.56)
      ..quadraticBezierTo(w * 0.5, h * 0.48, w * 0.92, h * 0.56)
      ..lineTo(w * 0.52, h * 0.04)
      ..lineTo(w * 0.48, h * 0.04)
      ..close();
    canvas.save();
    canvas.clipPath(lid);
    for (var i = 0; i < 9; i++) {
      canvas.drawRect(Rect.fromLTWH(0, h * 0.04 + i * h * 0.06, w, h * 0.06),
          Paint()..color = bands[(i + 1) % bands.length]);
    }
    canvas.restore();
    canvas.drawPath(lid, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = const Color(0xFF3E2723));
    canvas.drawCircle(Offset(w * 0.5, h * 0.04), 6, Paint()..color = ethYellow);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MesobPainter old) => old.lidLift != lidLift;
}
