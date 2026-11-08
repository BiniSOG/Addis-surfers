import 'dart:math';

import 'package:flutter/material.dart';

import '../characters.dart';
import 'textures.dart';

enum Pose { idle, run, jump, roll, crash }

/// Draws the three Addis Surfers characters from behind (the camera follows
/// the runner). Local units: 100 = standing height, feet at (0, 0), up is -y.
class CharacterPainter {
  CharacterPainter._();

  static final _textCache = <String, TextPainter>{};

  static TextPainter _label(String s, double size, Color color) =>
      _textCache.putIfAbsent('$s|$size|${color.toARGB32()}', () {
        return TextPainter(
          text: TextSpan(
            text: s,
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
      });

  static final Paint _p = Paint()..isAntiAlias = true;
  static final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  static Paint _fill(Color c) => _p
    ..color = c
    ..shader = null;
  static Paint _line(Color c, double w) => _stroke
    ..color = c
    ..strokeWidth = w;

  static const _outline = Color(0xFF231A16);

  /// [phase] advances with distance run; [t] is wall time (for idle/roll).
  static void paint(
    Canvas c,
    CharacterId id,
    Pose pose, {
    required double phase,
    required double t,
    bool jetpack = false,
  }) {
    if (pose == Pose.roll) {
      _roll(c, id, t);
      return;
    }
    final run = pose == Pose.run;
    final s = sin(phase);
    final bob = run ? -s.abs() * 3 : (pose == Pose.idle ? sin(t * 2.5) * 0.8 : 0.0);
    final liftL = run ? max(0.0, s) : (pose == Pose.jump ? 0.7 : 0.0);
    final liftR = run ? max(0.0, -s) : (pose == Pose.jump ? 0.5 : 0.0);
    final armSwing = run ? s : 0.0;
    final armsUp = pose == Pose.jump || pose == Pose.crash;

    c.save();
    if (pose == Pose.crash) {
      c.rotate(-0.25);
    }
    switch (id) {
      case CharacterId.meaza:
        _meaza(c, bob, liftL, liftR, armSwing, armsUp, phase);
      case CharacterId.tadesse:
        _tadesse(c, bob, liftL, liftR, armSwing, armsUp, phase);
      case CharacterId.yoseph:
        _yoseph(c, bob, liftL, liftR, armSwing, armsUp, phase);
    }
    if (jetpack) _jetpack(c, t);
    c.restore();
  }

  static void _jetpack(Canvas c, double t) {
    for (final side in [-1.0, 1.0]) {
      final tank = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(side * 8, -60), width: 11, height: 30),
        const Radius.circular(5),
      );
      c.drawRRect(tank.inflate(1.5), _fill(_outline));
      c.drawRRect(
        tank,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFE0E0E0), Color(0xFF9E9E9E)],
          ).createShader(tank.outerRect),
      );
      c.drawRect(Rect.fromLTWH(side * 8 - 5.5, -66, 11, 3), _fill(ethRed));
      // Flickering flame.
      final len = 16 + sin(t * 40 + side) * 4;
      final flame = Path()
        ..moveTo(side * 8 - 5, -45)
        ..lineTo(side * 8 + 5, -45)
        ..lineTo(side * 8, -45 + len)
        ..close();
      c.drawPath(flame, _fill(const Color(0xFFFF8A00)));
      final inner = Path()
        ..moveTo(side * 8 - 2.5, -45)
        ..lineTo(side * 8 + 2.5, -45)
        ..lineTo(side * 8, -45 + len * 0.6)
        ..close();
      c.drawPath(inner, _fill(ethYellow));
    }
  }

  // ---------------------------------------------------------------- helpers

  static void _leg(
    Canvas c,
    double side,
    double lift,
    double bob, {
    required Color upper,
    Color? lower,
    double splitY = -45,
    Color? sock,
    required Color shoe,
    Color shoeAccent = Colors.white,
    double width = 10,
  }) {
    final hip = Offset(side * 6.5, -45 + bob);
    final foot = Offset(side * 7.5, -5 - lift * 16);
    final knee = Offset(side * 8.5, (hip.dy + foot.dy) / 2 - lift * 3);
    c.drawLine(hip, knee, _line(_outline, width + 3));
    c.drawLine(knee, foot, _line(_outline, width + 2));
    c.drawLine(hip, knee, _line(upper, width));
    c.drawLine(knee, foot, _line(lower ?? upper, width - 1));
    if (lower != null && splitY > -45) {
      // Shorts: redraw upper part down to splitY.
      final t = (splitY - hip.dy) / (knee.dy - hip.dy);
      final mid = Offset.lerp(hip, knee, t.clamp(0, 1))!;
      c.drawLine(hip, mid, _line(upper, width + 2));
    }
    if (sock != null) {
      c.drawLine(foot.translate(0, -7), foot.translate(0, -2), _line(sock, width - 1));
    }
    final shoeRect = Rect.fromCenter(center: foot.translate(0, 1), width: 15, height: 10);
    c.drawRRect(
      RRect.fromRectAndRadius(shoeRect.inflate(1.5), const Radius.circular(5)),
      _fill(_outline),
    );
    c.drawRRect(RRect.fromRectAndRadius(shoeRect, const Radius.circular(5)), _fill(shoe));
    c.drawRect(
      Rect.fromLTWH(shoeRect.left, shoeRect.bottom - 3, shoeRect.width, 3),
      _fill(shoeAccent),
    );
  }

  static void _arm(
    Canvas c,
    double side,
    double swing,
    bool up,
    double bob, {
    required Color sleeve,
    required Color skin,
  }) {
    final shoulder = Offset(side * 14, -73 + bob);
    final Offset hand;
    if (up) {
      hand = Offset(side * 26, -96 + bob);
    } else {
      hand = Offset(side * (19 + swing.abs() * 2), -50 + bob - side * swing * 9);
    }
    final elbow = Offset.lerp(shoulder, hand, 0.5)!.translate(side * 3, 0);
    c.drawLine(shoulder, elbow, _line(_outline, 11));
    c.drawLine(elbow, hand, _line(_outline, 10));
    c.drawLine(shoulder, elbow, _line(sleeve, 8));
    c.drawLine(elbow, hand, _line(sleeve, 7));
    c.drawCircle(hand, 4.6, _fill(_outline));
    c.drawCircle(hand, 3.6, _fill(skin));
  }

  static Path _torsoPath(double bob, {double top = -78, double bottom = -42, double w = 15}) {
    return Path()
      ..moveTo(-w, top + 4 + bob)
      ..quadraticBezierTo(-w, top + bob, -w + 5, top + bob)
      ..lineTo(w - 5, top + bob)
      ..quadraticBezierTo(w, top + bob, w, top + 4 + bob)
      ..lineTo(w - 2, bottom + bob)
      ..lineTo(-w + 2, bottom + bob)
      ..close();
  }

  static void _torso(Canvas c, double bob, Paint fill, {double w = 15}) {
    final p = _torsoPath(bob, w: w);
    c.drawPath(p, _line(_outline, 3));
    c.drawPath(p, fill);
  }

  static void _head(Canvas c, double bob, Color skin) {
    c.drawLine(Offset(0, -80 + bob), Offset(0, -76 + bob), _line(skin, 7));
    c.drawCircle(Offset(0, -88 + bob), 11, _fill(_outline));
    c.drawCircle(Offset(0, -88 + bob), 10, _fill(skin));
    // Ears.
    c.drawCircle(Offset(-10, -87 + bob), 2.6, _fill(skin));
    c.drawCircle(Offset(10, -87 + bob), 2.6, _fill(skin));
  }

  // ----------------------------------------------------------------- Meaza

  static void _meaza(Canvas c, double bob, double lL, double lR, double sw,
      bool up, double phase) {
    const skin = Color(0xFF6E3F27);
    const pants = Color(0xFF5D6B35);
    const denim = Color(0xFF5F86B8);
    for (final side in [-1.0, 1.0]) {
      _leg(c, side, side < 0 ? lL : lR, bob,
          upper: pants, shoe: Colors.white, shoeAccent: ethGreen, width: 11);
    }
    // Cargo pockets.
    c.drawRect(Rect.fromLTWH(-15, -34 + bob - lL * 4, 5, 8), _fill(const Color(0xFF4E5A2C)));
    c.drawRect(Rect.fromLTWH(10, -34 + bob - lR * 4, 5, 8), _fill(const Color(0xFF4E5A2C)));
    for (final side in [-1.0, 1.0]) {
      _arm(c, side, sw, up, bob, sleeve: denim, skin: skin);
    }
    _torso(c, bob, _fill(denim));
    // Jacket seams.
    c.drawLine(Offset(0, -76 + bob), Offset(0, -43 + bob), _line(const Color(0xFF4A6E9C), 1.5));
    _head(c, bob, skin);
    // Hair: braids hanging down the back, swinging.
    final sway = sin(phase) * 2.5;
    for (var i = -3; i <= 3; i++) {
      final x0 = i * 2.8;
      final end = Offset(x0 * 1.4 + sway, -60 + bob + (i.abs() * 1.5));
      c.drawLine(Offset(x0, -88 + bob), end, _line(_outline, 4.2));
      c.drawLine(Offset(x0, -88 + bob), end, _line(const Color(0xFF1B1210), 3));
      c.drawCircle(end, 1.8, _fill(i.isEven ? ethYellow : ethRed));
    }
    c.drawCircle(Offset(0, -91 + bob), 11.5, _fill(const Color(0xFF1B1210)));
    c.drawCircle(Offset(-4, -95 + bob), 3, _fill(const Color(0xFF2E211C)));
    // Scarf in flag colours.
    final scarfY = -79 + bob;
    c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(-11, scarfY - 2, 22, 7), const Radius.circular(3)),
        _fill(ethGreen));
    c.drawRect(Rect.fromLTWH(-11, scarfY + 0.5, 22, 2), _fill(ethYellow));
    c.drawRect(Rect.fromLTWH(-11, scarfY + 2.5, 22, 2), _fill(ethRed));
    // Lion backpack.
    final bag = RRect.fromRectAndRadius(
      Rect.fromLTWH(-12, -74 + bob, 24, 28),
      const Radius.circular(7),
    );
    c.drawRRect(bag.inflate(1.6), _fill(_outline));
    c.save();
    c.clipRRect(bag);
    c.drawRect(Rect.fromLTWH(-12, -74 + bob, 24, 10), _fill(ethGreen));
    c.drawRect(Rect.fromLTWH(-12, -64 + bob, 24, 9), _fill(ethYellow));
    c.drawRect(Rect.fromLTWH(-12, -55 + bob, 24, 9), _fill(ethRed));
    c.restore();
    // Lion emblem: mane + face.
    final lc = Offset(0, -60 + bob);
    for (var a = 0; a < 10; a++) {
      final ang = a * pi / 5;
      c.drawCircle(lc + Offset(cos(ang), sin(ang)) * 5.5, 2.6, _fill(const Color(0xFF8A4B12)));
    }
    c.drawCircle(lc, 4.6, _fill(const Color(0xFFE0A030)));
    c.drawCircle(lc.translate(-1.5, -1), 0.8, _fill(_outline));
    c.drawCircle(lc.translate(1.5, -1), 0.8, _fill(_outline));
    // Straps.
    c.drawLine(Offset(-9, -76 + bob), Offset(-12, -72 + bob), _line(const Color(0xFF3A2A20), 2.5));
    c.drawLine(Offset(9, -76 + bob), Offset(12, -72 + bob), _line(const Color(0xFF3A2A20), 2.5));
  }

  // --------------------------------------------------------------- Tadesse

  static void _tadesse(Canvas c, double bob, double lL, double lR, double sw,
      bool up, double phase) {
    const skin = Color(0xFF6A3D24);
    const shorts = Color(0xFF7EA3C9);
    for (final side in [-1.0, 1.0]) {
      _leg(c, side, side < 0 ? lL : lR, bob,
          upper: shorts,
          lower: skin,
          splitY: -27,
          sock: const Color(0xFFF4C430),
          shoe: const Color(0xFF707070),
          shoeAccent: const Color(0xFFE07B2A),
          width: 10);
    }
    // Shorts cuffs.
    c.drawRect(Rect.fromLTWH(-15, -46 + bob, 30, 13), _fill(shorts));
    c.drawRect(Rect.fromLTWH(-15, -35 + bob, 30, 2), _fill(const Color(0xFFC9DCEE)));
    c.drawLine(Offset(-9, -42 + bob), Offset(-6, -40 + bob), _line(Colors.white70, 1.2));
    // Skateboard held in the right hand.
    final handY = up ? -96.0 : -50 + bob - sw * 9;
    final deck = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(up ? 28 : 25, handY + 4), width: 9, height: 44),
      const Radius.circular(4.5),
    );
    c.drawRRect(deck.inflate(1.5), _fill(_outline));
    c.drawRRect(
      deck,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE84393), Color(0xFF2E86DE), Color(0xFFF1C40F), Color(0xFF27AE60)],
        ).createShader(deck.outerRect),
    );
    for (final dy in [-15.0, 15.0]) {
      c.drawCircle(Offset(deck.outerRect.right + 1, deck.center.dy + dy), 2.2, _fill(_outline));
    }
    for (final side in [-1.0, 1.0]) {
      _arm(c, side, sw, up, bob, sleeve: const Color(0xFF283244), skin: skin);
    }
    _torso(c, bob, _fill(const Color(0xFF283244)));
    // Vest.
    final vest = _torsoPath(bob, top: -77, bottom: -44, w: 13);
    c.drawPath(vest, _fill(const Color(0xFF8D8466)));
    c.drawPath(vest, _line(const Color(0xFF5C5640), 1.4));
    c.drawLine(Offset(-13, -66 + bob), Offset(13, -66 + bob), _line(const Color(0xFF6F684F), 1.4));
    c.drawRect(Rect.fromLTWH(-8, -62 + bob, 16, 10), _fill(const Color(0xFF7C7459)));
    // Small flag patch.
    c.drawRect(Rect.fromLTWH(7, -73 + bob, 5, 1.3), _fill(ethGreen));
    c.drawRect(Rect.fromLTWH(7, -71.7 + bob, 5, 1.3), _fill(ethYellow));
    c.drawRect(Rect.fromLTWH(7, -70.4 + bob, 5, 1.3), _fill(ethRed));
    _head(c, bob, skin);
    // Beanie.
    final beanie = Path()
      ..moveTo(-11.5, -88 + bob)
      ..quadraticBezierTo(-12, -103 + bob, 0, -103 + bob)
      ..quadraticBezierTo(12, -103 + bob, 11.5, -88 + bob)
      ..close();
    c.drawPath(beanie, _fill(const Color(0xFF34352B)));
    c.drawPath(beanie, _line(_outline, 1.6));
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-12.5, -91 + bob, 25, 5), const Radius.circular(2)),
      _fill(const Color(0xFF2A2B22)),
    );
    c.drawLine(Offset(-12, -90 + bob), Offset(12, -90 + bob), _line(const Color(0xFFC8A72A), 1.2));
    // Neck hair line.
    c.drawLine(Offset(-6, -82 + bob), Offset(6, -82 + bob), _line(const Color(0xFF1B1210), 2.5));
  }

  // ---------------------------------------------------------------- Yoseph

  static void _yoseph(Canvas c, double bob, double lL, double lR, double sw,
      bool up, double phase) {
    const skin = Color(0xFF74452A);
    const jeans = Color(0xFF26262B);
    for (final side in [-1.0, 1.0]) {
      final lift = side < 0 ? lL : lR;
      _leg(c, side, lift, bob,
          upper: jeans, shoe: Colors.white, shoeAccent: ethRed, width: 11);
      // Ripped knees.
      c.drawOval(
        Rect.fromCenter(center: Offset(side * 8.3, -25 + bob - lift * 9), width: 5, height: 3),
        _fill(skin),
      );
    }
    for (final side in [-1.0, 1.0]) {
      _arm(c, side, sw, up, bob, sleeve: const Color(0xFF3A8FD0), skin: skin);
    }
    final hoodie = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2F8FD8), Color(0xFF8E7BC0), Color(0xFFF08A3C)],
      ).createShader(Rect.fromLTWH(-15, -78 + bob, 30, 36));
    _torso(c, bob, hoodie);
    // Hood lying on the back.
    c.drawOval(
      Rect.fromCenter(center: Offset(0, -73 + bob), width: 20, height: 9),
      _fill(const Color(0xFF2770AE)),
    );
    // "19 ETHIOPIA" on the back.
    final n = _label('19', 8, Colors.white);
    n.paint(c, Offset(-n.width / 2, -68 + bob));
    final e = _label('ETHIOPIA', 5.4, Colors.white);
    e.paint(c, Offset(-e.width / 2, -59 + bob));
    // Sweater tied round the waist, hanging down the back.
    final sweater = Path()
      ..moveTo(-15, -46 + bob)
      ..lineTo(15, -46 + bob)
      ..lineTo(13, -27 + bob + sin(phase) * 1.5)
      ..lineTo(-13, -27 + bob - sin(phase) * 1.5)
      ..close();
    c.drawPath(sweater, _fill(const Color(0xFFB83227)));
    c.drawPath(sweater, _line(_outline, 1.5));
    for (var i = 0; i < 6; i++) {
      final x = -12.0 + i * 5;
      c.drawLine(Offset(x, -38 + bob), Offset(x + 2.5, -35 + bob), _line(ethGreen, 1.6));
      c.drawLine(Offset(x + 2.5, -35 + bob), Offset(x + 5, -38 + bob), _line(ethYellow, 1.6));
    }
    c.drawRect(Rect.fromLTWH(-15, -47 + bob, 30, 4), _fill(const Color(0xFF8E2219)));
    _head(c, bob, skin);
    // Curly hair.
    for (var i = 0; i < 7; i++) {
      final a = pi + i * pi / 6;
      c.drawCircle(Offset(cos(a) * 8, -91 + bob + sin(a) * 7), 4.2, _fill(const Color(0xFF15100E)));
    }
    c.drawCircle(Offset(0, -91 + bob), 7.5, _fill(const Color(0xFF15100E)));
    // Headphones.
    final band = Rect.fromCenter(center: Offset(0, -89 + bob), width: 26, height: 26);
    c.drawArc(band, pi * 1.05, pi * 0.9, false, _line(const Color(0xFF3A3A3A), 4.5));
    c.drawArc(band, pi * 1.05, pi * 0.9, false, _line(const Color(0xFFD7D7D7), 2.8));
    for (final side in [-1.0, 1.0]) {
      final cup = Rect.fromCenter(center: Offset(side * 12, -87 + bob), width: 7, height: 11);
      c.drawRRect(RRect.fromRectAndRadius(cup.inflate(1.2), const Radius.circular(3)), _fill(_outline));
      c.drawRRect(RRect.fromRectAndRadius(cup, const Radius.circular(3)), _fill(const Color(0xFFDADADA)));
      c.drawCircle(cup.center, 2, _fill(const Color(0xFFE8743B)));
    }
  }

  // ------------------------------------------------------------------ roll

  static void _roll(Canvas c, CharacterId id, double t) {
    final (Color body, Color accent) = switch (id) {
      CharacterId.meaza => (const Color(0xFF5F86B8), ethGreen),
      CharacterId.tadesse => (const Color(0xFF8D8466), const Color(0xFFF4C430)),
      CharacterId.yoseph => (const Color(0xFF2F8FD8), const Color(0xFFF08A3C)),
    };
    const center = Offset(0, -22);
    c.drawCircle(center, 23, _fill(_outline));
    c.drawCircle(center, 21, _fill(body));
    final a = t * 14;
    c.drawArc(Rect.fromCircle(center: center, radius: 15), a, pi * 0.9, false, _line(accent, 6));
    c.drawArc(Rect.fromCircle(center: center, radius: 15), a + pi, pi * 0.6, false, _line(ethRed, 4));
    c.drawCircle(center + Offset(cos(-a) * 8, sin(-a) * 8), 6, _fill(const Color(0xFF1B1210)));
  }
}
