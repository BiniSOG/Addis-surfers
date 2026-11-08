import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Ethiopian flag colours, used throughout the art.
const ethGreen = Color(0xFF078930);
const ethYellow = Color(0xFFFCDD09);
const ethRed = Color(0xFFDA121A);

/// Pre-rendered textures for trains and barriers. Drawing these once into
/// images keeps the per-frame cost low on budget phones.
class Textures {
  Textures._();

  static late List<ui.Image> trainSides;
  static late ui.Image trainFront;
  static late ui.Image lowBarrier;
  static late ui.Image highBarrier;
  static bool _built = false;

  static void build() {
    if (_built) return;
    _built = true;
    trainSides = [
      for (var v = 0; v < 4; v++) _render(800, 160, (c) => _trainSide(c, v)),
    ];
    trainFront = _render(260, 440, _trainFront);
    lowBarrier = _render(280, 160, _lowBarrier);
    highBarrier = _render(280, 520, _highBarrier);
  }

  static ui.Image _render(int w, int h, void Function(Canvas) paint) {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    paint(canvas);
    return rec.endRecording().toImageSync(w, h);
  }

  static TextPainter _text(
    String s,
    double size,
    Color color, {
    FontWeight weight = FontWeight.w900,
    Color? stroke,
    double strokeWidth = 0,
    double letterSpacing = 0,
  }) {
    final style = TextStyle(
      fontFamilyFallback: const ['NotoEthiopic'],
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      foreground: stroke == null
          ? (Paint()..color = color)
          : (Paint()
            ..color = stroke
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeJoin = StrokeJoin.round),
    );
    return TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  static void _drawOutlinedText(
    Canvas c,
    String s,
    Offset center,
    double size,
    Color fill,
    Color outline, {
    double angle = 0,
    double maxWidth = double.infinity,
  }) {
    final back = _text(s, size, outline, stroke: outline, strokeWidth: size * 0.28);
    final front = _text(s, size, fill);
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(angle);
    final scale = min(1.0, maxWidth / front.width);
    c.scale(scale);
    back.paint(c, Offset(-back.width / 2, -back.height / 2));
    front.paint(c, Offset(-front.width / 2, -front.height / 2));
    c.restore();
  }

  // ---------------------------------------------------------------------------

  static void _trainSide(Canvas c, int variant) {
    const w = 800.0, h = 160.0;
    final rnd = Random(variant * 31 + 7);
    // Body.
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, w, h), const Radius.circular(10)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF7F4EE), Color(0xFFDAD6CF)],
        ).createShader(const Rect.fromLTWH(0, 0, w, h)),
    );
    // Orange roof band (like the key art).
    c.drawRect(const Rect.fromLTWH(0, 0, w, 26), Paint()..color = const Color(0xFFF07C1F));
    c.drawRect(const Rect.fromLTWH(0, 26, w, 4), Paint()..color = const Color(0xFFB85A12));

    // Windows & doors.
    final glass = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6E9CC4), Color(0xFF203A55), Color(0xFF16283C)],
      ).createShader(const Rect.fromLTWH(0, 40, w, 50));
    final frame = Paint()
      ..color = const Color(0xFF55575C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    for (var i = 0; i < 6; i++) {
      final x = 30.0 + i * 128;
      final isDoor = i == 2 || i == 4;
      final r = isDoor
          ? Rect.fromLTWH(x + 14, 36, 70, 104)
          : Rect.fromLTWH(x, 40, 100, 50);
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(8));
      c.drawRRect(rr, glass);
      c.drawRRect(rr, frame);
      // Reflection streak.
      c.drawLine(
        Offset(r.left + 12, r.bottom - 8),
        Offset(r.left + 34, r.top + 6),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..strokeWidth = 5,
      );
      if (isDoor) {
        c.drawLine(Offset(r.center.dx, r.top), Offset(r.center.dx, r.bottom), frame);
      }
    }

    // Graffiti / livery band.
    const gTop = 96.0, gBottom = 134.0;
    final graffitiPalette = [
      const Color(0xFF8E44AD),
      const Color(0xFF27AE60),
      const Color(0xFFF1C40F),
      const Color(0xFF2E86DE),
      const Color(0xFFE84393),
      const Color(0xFFE67E22),
    ];
    // Spray blobs behind the lettering.
    for (var i = 0; i < 9; i++) {
      final col = graffitiPalette[rnd.nextInt(graffitiPalette.length)];
      c.drawOval(
        Rect.fromCenter(
          center: Offset(rnd.nextDouble() * w, gTop + 18 + rnd.nextDouble() * 10),
          width: 60 + rnd.nextDouble() * 120,
          height: 26 + rnd.nextDouble() * 18,
        ),
        Paint()..color = col.withValues(alpha: 0.55),
      );
    }
    const words = ['ADDIS', 'አዲስ አበባ', 'ETHIOPIA', 'ADDIS ABABA'];
    final word = words[variant % words.length];
    final fill = graffitiPalette[(variant * 2 + 1) % graffitiPalette.length];
    _drawOutlinedText(
      c,
      word,
      Offset(w * (0.3 + 0.4 * rnd.nextDouble()), (gTop + gBottom) / 2 + 2),
      36,
      fill,
      const Color(0xFF1B1B1B),
      angle: -0.04 + rnd.nextDouble() * 0.08,
      maxWidth: 420,
    );
    _drawOutlinedText(
      c,
      variant.isEven ? 'AS' : 'ሰርፍ',
      Offset(w * 0.1 + rnd.nextDouble() * 40, (gTop + gBottom) / 2),
      30,
      graffitiPalette[(variant + 3) % graffitiPalette.length],
      Colors.black,
      angle: -0.12,
    );

    // Ethiopian stripe + undercarriage.
    c.drawRect(const Rect.fromLTWH(0, 136, w, 5), Paint()..color = ethGreen);
    c.drawRect(const Rect.fromLTWH(0, 141, w, 5), Paint()..color = ethYellow);
    c.drawRect(const Rect.fromLTWH(0, 146, w, 5), Paint()..color = ethRed);
    c.drawRect(const Rect.fromLTWH(0, 151, w, 9), Paint()..color = const Color(0xFF2B2B2E));
    // Car joint at each end.
    final joint = Paint()..color = const Color(0xFF3A3A3E);
    c.drawRect(const Rect.fromLTWH(0, 30, 6, 130), joint);
    c.drawRect(const Rect.fromLTWH(w - 6, 30, 6, 130), joint);
  }

  static void _trainFront(Canvas c) {
    const w = 260.0, h = 440.0;
    final body = RRect.fromRectAndCorners(
      const Rect.fromLTWH(0, 0, w, h),
      topLeft: const Radius.circular(40),
      topRight: const Radius.circular(40),
      bottomLeft: const Radius.circular(10),
      bottomRight: const Radius.circular(10),
    );
    c.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF07C1F), Color(0xFFF7F4EE), Color(0xFFDAD6CF)],
          stops: [0.0, 0.16, 1.0],
        ).createShader(const Rect.fromLTWH(0, 0, w, h)),
    );
    // Destination sign.
    final sign = RRect.fromRectAndRadius(
      const Rect.fromLTWH(40, 30, 180, 34),
      const Radius.circular(6),
    );
    c.drawRRect(sign, Paint()..color = const Color(0xFF111111));
    final t = _text('አዲስ አበባ • ADDIS', 18, const Color(0xFFFFA726), weight: FontWeight.w700);
    c.save();
    c.translate(130, 47);
    c.scale(min(1.0, 170 / t.width));
    t.paint(c, Offset(-t.width / 2, -t.height / 2));
    c.restore();
    // Windshield.
    final wind = RRect.fromRectAndRadius(
      const Rect.fromLTWH(18, 76, 224, 150),
      const Radius.circular(22),
    );
    c.drawRRect(
      wind,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8DB6DA), Color(0xFF213B57), Color(0xFF101C2A)],
        ).createShader(wind.outerRect),
    );
    c.drawRRect(
      wind,
      Paint()
        ..color = const Color(0xFF444448)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7,
    );
    c.drawLine(
      const Offset(50, 210),
      const Offset(110, 92),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 12,
    );
    // Number.
    _drawOutlinedText(c, '19', const Offset(130, 270), 34, Colors.white, const Color(0xFF333333));
    // Headlights.
    for (final x in [48.0, 212.0]) {
      c.drawCircle(Offset(x, 320), 22, Paint()..color = const Color(0xFF333333));
      c.drawCircle(Offset(x, 320), 16, Paint()..color = const Color(0xFFFFF5C2));
      c.drawCircle(
        Offset(x, 320),
        30,
        Paint()
          ..color = const Color(0x55FFF5C2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
    // Flag stripe & bumper.
    c.drawRect(const Rect.fromLTWH(0, 360, w, 10), Paint()..color = ethGreen);
    c.drawRect(const Rect.fromLTWH(0, 370, w, 10), Paint()..color = ethYellow);
    c.drawRect(const Rect.fromLTWH(0, 380, w, 10), Paint()..color = ethRed);
    c.drawRect(const Rect.fromLTWH(10, 396, w - 20, 44), Paint()..color = const Color(0xFF2B2B2E));
    c.drawRect(const Rect.fromLTWH(90, 404, 80, 18), Paint()..color = const Color(0xFF555559));
  }

  static void _hazard(Canvas c, Rect r, Color a, Color b) {
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)));
    c.drawRect(r, Paint()..color = a);
    final p = Paint()..color = b;
    for (var x = r.left - r.height; x < r.right; x += 36) {
      c.drawPath(
        Path()
          ..moveTo(x, r.bottom)
          ..lineTo(x + 18, r.bottom)
          ..lineTo(x + 18 + r.height, r.top)
          ..lineTo(x + r.height, r.top)
          ..close(),
        p,
      );
    }
    c.restore();
    c.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(6)),
      Paint()
        ..color = Colors.black54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  static void _post(Canvas c, double x, double top, double bottom) {
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(x - 9, top, x + 9, bottom), const Radius.circular(4)),
      Paint()..color = const Color(0xFF6B6F76),
    );
    c.drawRect(Rect.fromLTRB(x - 9, top, x - 3, bottom), Paint()..color = const Color(0xFF9AA0A8));
  }

  static void _lowBarrier(Canvas c) {
    // 1.4 wide x 0.8 tall.
    _post(c, 30, 20, 160);
    _post(c, 250, 20, 160);
    _hazard(c, const Rect.fromLTWH(6, 24, 268, 50), ethYellow, const Color(0xFF1E1E1E));
    _hazard(c, const Rect.fromLTWH(6, 84, 268, 30), ethRed, Colors.white);
  }

  static void _highBarrier(Canvas c) {
    // 1.4 wide x 2.6 tall. Board covers y = 1.05 .. 2.6 (top 0..~300 px).
    _post(c, 22, 0, 520);
    _post(c, 258, 0, 520);
    final board = RRect.fromRectAndRadius(
      const Rect.fromLTWH(6, 10, 268, 180),
      const Radius.circular(12),
    );
    c.drawRRect(board, Paint()..color = ethRed);
    c.drawRRect(
      board,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );
    _drawOutlinedText(c, 'ቁም', const Offset(140, 70), 64, Colors.white, const Color(0xFF7A0A0E));
    _drawOutlinedText(c, 'STOP', const Offset(140, 140), 44, Colors.white, const Color(0xFF7A0A0E));
    _hazard(c, const Rect.fromLTWH(6, 206, 268, 104), Colors.white, ethRed);
  }
}
