import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'addis_game.dart';
import 'character_painter.dart';
import 'entities.dart';
import 'textures.dart';

/// Pseudo-3D renderer: a pinhole camera behind and above the runner,
/// projecting world (x, y, z) to the screen. Everything is drawn with the
/// Canvas API so the game has no heavy 3D engine dependency.
class WorldRenderer {
  WorldRenderer(this.g);
  final AddisGame g;

  static const camHeight = 4.6;
  static const camBack = 6.0;
  static const _haze = Color(0xFFD3E9F5);

  late double _w, _h, _cx, _f, _horizon, _camY, _zNear, _zFar;
  ui.Image? _sky;
  Size? _skySize;

  final Paint _paint = Paint()..isAntiAlias = true;
  final Paint _imgPaint = Paint()
    ..filterQuality = FilterQuality.medium
    ..isAntiAlias = true;
  final Path _path = Path();

  // ------------------------------------------------------------ projection

  Offset project(double x, double y, double z) {
    final d = max(0.05, z - g.pz + camBack);
    final s = _f / d;
    return Offset(_cx + (x - g.camX) * s, _horizon + (camHeight + _camY - y) * s);
  }

  double scaleAt(double z) => _f / max(0.05, z - g.pz + camBack);

  double _fog(double z) => ((z - g.pz - 55) / 75).clamp(0.0, 0.85);

  Color _fogged(Color c, double z) => Color.lerp(c, _haze, _fog(z))!;

  Paint _fill(Color c) => _paint
    ..color = c
    ..style = PaintingStyle.fill
    ..shader = null;

  void _quad(Canvas c, Offset a, Offset b, Offset d, Offset e, Paint p) {
    _path
      ..reset()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(d.dx, d.dy)
      ..lineTo(e.dx, e.dy)
      ..close();
    c.drawPath(_path, p);
  }

  // ---------------------------------------------------------------- render

  void render(Canvas canvas, Size size) {
    _w = size.width;
    _h = size.height;
    if (_w <= 0 || _h <= 0) return;
    _cx = _w / 2;
    _f = min(0.626 * _h, 1.4 * _w);
    _horizon = 0.84 * _h - camHeight * _f / camBack;
    _camY = g.camY;
    _zNear = g.pz - camBack + 0.6;
    _zFar = g.pz + 130;

    canvas.save();
    if (g.shake > 0) {
      canvas.translate(sin(g.time * 90) * g.shake * 6, cos(g.time * 77) * g.shake * 4);
    }
    _drawSky(canvas);
    _drawGround(canvas);
    _drawWorldObjects(canvas);
    _drawWires(canvas);
    canvas.restore();
  }

  // -------------------------------------------------------------------- sky

  void _drawSky(Canvas canvas) {
    final skyH = max(1.0, _horizon + 4 + 0.06 * _h);
    final skySize = Size(_w * 1.3, skyH);
    if (_sky == null || _skySize != skySize) {
      _sky?.dispose();
      _sky = _buildSky(skySize);
      _skySize = skySize;
    }
    // Light parallax with the camera, and with roof height.
    canvas.drawImage(_sky!, Offset(-_w * 0.15 - g.camX * 6, _camY * 6), _imgPaint);
    // Drifting clouds.
    for (var i = 0; i < 5; i++) {
      final span = _w * 1.6;
      final x = ((i * 0.37 * span + g.time * (6 + i * 2)) % span) - _w * 0.3;
      final y = _h * (0.05 + 0.045 * i);
      _cloud(canvas, Offset(x, y), _w * (0.10 + 0.02 * (i % 3)));
    }
  }

  void _cloud(Canvas c, Offset o, double r) {
    final p = _fill(Colors.white.withValues(alpha: 0.92));
    c.drawCircle(o, r * 0.55, p);
    c.drawCircle(o.translate(r * 0.55, r * 0.1), r * 0.45, p);
    c.drawCircle(o.translate(-r * 0.55, r * 0.15), r * 0.38, p);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(o.dx - r, o.dy, r * 2, r * 0.45),
        Radius.circular(r * 0.22),
      ),
      p,
    );
  }

  ui.Image _buildSky(Size s) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final rect = Offset.zero & s;
    c.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4FA8E8), Color(0xFF9FD3F5), Color(0xFFDFF1FB)],
          stops: [0, 0.6, 1],
        ).createShader(rect),
    );
    // Sun.
    final sun = Offset(s.width * 0.78, s.height * 0.22);
    c.drawCircle(
      sun,
      s.width * 0.09,
      Paint()
        ..color = const Color(0x66FFF3B0)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );
    c.drawCircle(sun, s.width * 0.04, Paint()..color = const Color(0xFFFFF6CF));

    final base = s.height;
    // Entoto hills.
    final rnd = Random(7);
    for (var layer = 0; layer < 2; layer++) {
      final p = Path()..moveTo(0, base);
      for (var x = 0.0; x <= s.width; x += s.width / 12) {
        p.lineTo(x, base - s.height * (0.16 + 0.06 * layer) - rnd.nextDouble() * s.height * 0.08);
      }
      p
        ..lineTo(s.width, base)
        ..close();
      c.drawPath(
        p,
        Paint()..color = layer == 0 ? const Color(0xFF8DB5A6) : const Color(0xFF6E9E86),
      );
    }

    // Colourful Addis skyline (palette from the key art).
    const palette = [
      Color(0xFFF4A261), Color(0xFFE76F51), Color(0xFF2A9D8F), Color(0xFFE9C46A),
      Color(0xFF8ECAE6), Color(0xFFB5838D), Color(0xFF90BE6D), Color(0xFFF28482),
      Color(0xFFCDB4DB), Color(0xFFFFB703),
    ];
    var x = -10.0;
    final unit = s.height;
    while (x < s.width) {
      final bw = unit * (0.08 + rnd.nextDouble() * 0.10);
      final bh = unit * (0.10 + rnd.nextDouble() * 0.22);
      final col = palette[rnd.nextInt(palette.length)];
      final r = Rect.fromLTWH(x, base - bh, bw, bh);
      c.drawRect(r, Paint()..color = col);
      c.drawRect(
        Rect.fromLTWH(r.right - bw * 0.18, r.top, bw * 0.18, bh),
        Paint()..color = Colors.black.withValues(alpha: 0.12),
      );
      final win = Paint()..color = Colors.white.withValues(alpha: 0.55);
      final ws = max(2.0, bw * 0.12);
      for (var wy = r.top + ws; wy < r.bottom - ws * 1.5; wy += ws * 2) {
        for (var wx = r.left + ws * 0.8; wx < r.right - ws * 1.5; wx += ws * 1.8) {
          c.drawRect(Rect.fromLTWH(wx, wy, ws, ws * 1.1), win);
        }
      }
      x += bw + unit * 0.01;
    }
    // A tall glass tower on the skyline.
    final tx = s.width * 0.42;
    final tower = Path()
      ..moveTo(tx, base)
      ..lineTo(tx + unit * 0.02, base - unit * 0.55)
      ..lineTo(tx + unit * 0.09, base - unit * 0.6)
      ..lineTo(tx + unit * 0.12, base)
      ..close();
    c.drawPath(
      tower,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF5C8DB8), Color(0xFFB8D8EE)],
        ).createShader(tower.getBounds()),
    );
    // Haze near horizon.
    c.drawRect(
      Rect.fromLTWH(0, base - s.height * 0.12, s.width, s.height * 0.12),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_haze.withValues(alpha: 0), _haze],
        ).createShader(Rect.fromLTWH(0, base - s.height * 0.12, s.width, s.height * 0.12)),
    );
    return rec.endRecording().toImageSync(s.width.ceil(), s.height.ceil());
  }

  // ----------------------------------------------------------------- ground

  void _drawGround(Canvas c) {
    final top = project(0, 0, _zFar).dy;
    final groundRect = Rect.fromLTRB(-50, top, _w + 50, _h + 50);
    c.drawRect(
      groundRect,
      _fill(const Color(0xFF7FA559))
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_haze, const Color(0xFF93B866), const Color(0xFF6E9A48)],
          stops: const [0, 0.25, 1],
        ).createShader(groundRect),
    );
    _paint.shader = null;

    void band(double x0, double x1, Color col) {
      _quad(
        c,
        project(x0, 0, _zNear),
        project(x1, 0, _zNear),
        project(x1, 0, _zFar),
        project(x0, 0, _zFar),
        _fill(col),
      );
    }

    // Platforms on both sides with yellow safety lines.
    band(-4.8, -2.45, const Color(0xFFC9C2B6));
    band(2.45, 4.8, const Color(0xFFC9C2B6));
    band(-2.62, -2.45, const Color(0xFFF2B705));
    band(2.45, 2.62, const Color(0xFFF2B705));
    // Ballast bed.
    band(-2.4, 2.4, const Color(0xFF8A7B6B));
    for (final l in [-1, 0, 1]) {
      band(laneX(l) - 0.78, laneX(l) + 0.78, const Color(0xFF766858));
    }

    // Sleepers, in distance bands so far ones fade into the haze.
    const spacing = 1.1;
    final first = (_zNear / spacing).floor() * spacing;
    final limit = g.pz + 75;
    for (var bandIdx = 0; bandIdx < 4; bandIdx++) {
      final zA = _zNear + (limit - _zNear) * bandIdx / 4;
      final zB = _zNear + (limit - _zNear) * (bandIdx + 1) / 4;
      _path.reset();
      for (var z = first; z < zB; z += spacing) {
        if (z < zA || z < _zNear) continue;
        for (final l in [-1, 0, 1]) {
          final x = laneX(l);
          final a = project(x - 0.7, 0, z);
          final b = project(x + 0.7, 0, z);
          final d = project(x + 0.7, 0, z + 0.28);
          final e = project(x - 0.7, 0, z + 0.28);
          _path
            ..moveTo(a.dx, a.dy)
            ..lineTo(b.dx, b.dy)
            ..lineTo(d.dx, d.dy)
            ..lineTo(e.dx, e.dy)
            ..close();
        }
      }
      c.drawPath(_path, _fill(_fogged(const Color(0xFF5A3E2B), (zA + zB) / 2)));
    }

    // Rails.
    for (final l in [-1, 0, 1]) {
      for (final side in [-0.42, 0.42]) {
        final x = laneX(l) + side;
        _quad(c, project(x - 0.05, 0.05, _zNear), project(x + 0.05, 0.05, _zNear),
            project(x + 0.05, 0.05, _zFar), project(x - 0.05, 0.05, _zFar),
            _fill(const Color(0xFF6F757C)));
        _quad(c, project(x - 0.02, 0.07, _zNear), project(x + 0.02, 0.07, _zNear),
            project(x + 0.02, 0.07, _zFar), project(x - 0.02, 0.07, _zFar),
            _fill(const Color(0xFFD6DCE2)));
      }
    }
  }

  void _drawWires(Canvas c) {
    final p = Paint()
      ..color = const Color(0xCC2B2B2B)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    for (final l in [-1, 0, 1]) {
      final a = project(laneX(l), 4.3, _zNear + 1.5);
      final b = project(laneX(l), 4.3, _zFar);
      c.drawLine(a, b, p);
    }
  }

  // ---------------------------------------------------------------- objects

  static double _hash(int i, int salt) {
    final v = sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return v - v.floorToDouble();
  }

  void _drawWorldObjects(Canvas c) {
    final items = <(double, int, Object?)>[];
    // 0 obstacle, 1 coin, 2 power-up, 3 player, 4 pole, 5 palm, 6 building, 7 shelter
    for (final o in g.obstacles) {
      if (o.end < _zNear || o.z > _zFar) continue;
      final key = (o.kind == ObstacleKind.train || o.kind == ObstacleKind.ramp)
          ? o.end
          : o.z;
      items.add((key, 0, o));
    }
    for (final coin in g.coins) {
      if (coin.collected || coin.z < _zNear || coin.z > g.pz + 90) continue;
      items.add((coin.z, 1, coin));
    }
    for (final p in g.powerUps) {
      if (p.collected || p.z < _zNear || p.z > g.pz + 90) continue;
      items.add((p.z, 2, p));
    }
    items.add((g.pz, 3, null));

    // Scenery is placed on fixed slots so it is stable as you run.
    const poleGap = 16.0;
    for (var i = (_zNear / poleGap).ceil(); i * poleGap < _zFar; i++) {
      items.add((i * poleGap, 4, i));
    }
    const palmGap = 6.0;
    for (var i = (_zNear / palmGap).ceil(); i * palmGap < _zFar; i++) {
      if (_hash(i, 1) > 0.3) items.add((i * palmGap, 5, i));
    }
    const bGap = 12.0;
    for (var i = ((_zNear - 10) / bGap).ceil(); i * bGap < _zFar; i++) {
      items.add((i * bGap, 6, i));
    }
    const shelterGap = 90.0;
    for (var i = ((_zNear - 20) / shelterGap).ceil(); i * shelterGap < _zFar; i++) {
      items.add((i * shelterGap + 30, 7, i));
    }

    items.sort((a, b) => b.$1.compareTo(a.$1));
    for (final (z, kind, ref) in items) {
      switch (kind) {
        case 0:
          _drawObstacle(c, ref! as Obstacle);
        case 1:
          _drawCoin(c, ref! as Coin);
        case 2:
          _drawPowerUp(c, ref! as PowerUp);
        case 3:
          _drawPlayer(c);
        case 4:
          _drawPoles(c, z);
        case 5:
          _drawPalm(c, ref! as int, z);
        case 6:
          _drawBuildings(c, ref! as int, z);
        case 7:
          _drawShelter(c, z);
      }
    }
  }

  // ----------------------------------------------------------- obstacles

  void _drawObstacle(Canvas c, Obstacle o) {
    switch (o.kind) {
      case ObstacleKind.train:
        _drawTrain(c, o);
      case ObstacleKind.ramp:
        _drawRamp(c, o);
      case ObstacleKind.lowBarrier:
        _drawBillboard(c, Textures.lowBarrier, laneX(o.lane), o.z, 1.4, 0.8);
      case ObstacleKind.highBarrier:
        _drawBillboard(c, Textures.highBarrier, laneX(o.lane), o.z, 1.4, 2.6);
    }
  }

  void _drawBillboard(Canvas c, ui.Image img, double x, double z, double w, double h) {
    if (z < _zNear) return;
    final tl = project(x - w / 2, h, z);
    final br = project(x + w / 2, 0, z);
    final dst = Rect.fromPoints(tl, br);
    c.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      dst,
      _imgPaint,
    );
    final fog = _fog(z);
    if (fog > 0.01) {
      c.drawRect(dst, _fill(_haze.withValues(alpha: fog)));
    }
  }

  void _drawTrain(Canvas c, Obstacle o) {
    final z0 = max(o.z, _zNear);
    final z1 = o.end;
    if (z1 <= z0) return;
    final x0 = laneX(o.lane) - trainWidth / 2;
    final x1 = laneX(o.lane) + trainWidth / 2;
    const h = trainHeight;
    final fogNear = _fog(z0);

    // Roof.
    if (camHeight + _camY > h) {
      _quad(c, project(x0, h, z0), project(x1, h, z0), project(x1, h, z1),
          project(x0, h, z1), _fill(_fogged(const Color(0xFFB9BCC2), z0)));
      final inset = 0.12;
      _quad(c, project(x0 + inset, h + 0.01, z0), project(x1 - inset, h + 0.01, z0),
          project(x1 - inset, h + 0.01, z1), project(x0 + inset, h + 0.01, z1),
          _fill(_fogged(const Color(0xFFA2A6AD), z0)));
      // Roof units at each car.
      for (var k = 0; k * carLength < o.length; k++) {
        final cz = o.z + k * carLength + carLength * 0.35;
        if (cz < _zNear || cz + 2 > z1) continue;
        _quad(c, project(x0 + 0.3, h + 0.02, cz), project(x1 - 0.3, h + 0.02, cz),
            project(x1 - 0.3, h + 0.02, cz + 2.5), project(x0 + 0.3, h + 0.02, cz + 2.5),
            _fill(_fogged(const Color(0xFF7F848C), cz)));
      }
    }

    // Visible side face, textured per car with a projective transform.
    final double? sideX = g.camX > x1 ? x1 : (g.camX < x0 ? x0 : null);
    if (sideX != null) {
      final rightFace = sideX == x1;
      final tex = Textures.trainSides[o.variant % Textures.trainSides.length];
      final tw = tex.width.toDouble(), th = tex.height.toDouble();
      for (var k = 0; k * carLength < o.length - 0.01; k++) {
        final cz0 = o.z + k * carLength;
        final cz1 = cz0 + carLength;
        if (cz1 <= _zNear || cz0 > _zFar) continue;
        final a0 = max(cz0, _zNear);
        final f0 = (a0 - cz0) / carLength; // fraction clipped at the near end
        final Rect src;
        final List<Offset> dst;
        if (rightFace) {
          // Screen left→right runs far→near, so texture u=0 is the far end.
          src = Rect.fromLTRB(0, 0, tw * (1 - f0), th);
          dst = [
            project(sideX, h, cz1),
            project(sideX, h, a0),
            project(sideX, 0, a0),
            project(sideX, 0, cz1),
          ];
        } else {
          src = Rect.fromLTRB(tw * f0, 0, tw, th);
          dst = [
            project(sideX, h, a0),
            project(sideX, h, cz1),
            project(sideX, 0, cz1),
            project(sideX, 0, a0),
          ];
        }
        if (src.width < 1) continue;
        c.save();
        c.transform(_rectToQuad(src, dst));
        c.drawImageRect(tex, src, src, _imgPaint);
        c.restore();
        final fog = _fog((a0 + cz1) / 2);
        if (fog > 0.01) {
          _quad(c, dst[0], dst[1], dst[2], dst[3], _fill(_haze.withValues(alpha: fog)));
        }
      }
    }

    // Front face.
    if (o.z >= _zNear) {
      final dst = Rect.fromPoints(project(x0, h, o.z), project(x1, 0, o.z));
      final img = Textures.trainFront;
      c.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        dst,
        _imgPaint,
      );
      if (o.speed > 0) {
        // Oncoming: glowing headlights as a warning.
        final glow = Paint()
          ..color = const Color(0x99FFF2A8)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, max(2, dst.width * 0.08));
        c.drawCircle(Offset(dst.left + dst.width * 0.18, dst.top + dst.height * 0.73),
            dst.width * 0.16, glow);
        c.drawCircle(Offset(dst.right - dst.width * 0.18, dst.top + dst.height * 0.73),
            dst.width * 0.16, glow);
      }
      if (fogNear > 0.01) {
        c.drawRect(dst, _fill(_haze.withValues(alpha: fogNear)));
      }
    }
  }

  void _drawRamp(Canvas c, Obstacle o) {
    final x0 = laneX(o.lane) - trainWidth / 2;
    final x1 = laneX(o.lane) + trainWidth / 2;
    const h = trainHeight;
    var z0 = o.z;
    var y0 = 0.0;
    if (z0 < _zNear) {
      if (o.end <= _zNear) return;
      y0 = h * (_zNear - o.z) / o.length;
      z0 = _zNear;
    }
    final z1 = o.end;
    // Side triangle (visible side).
    final double? sx = g.camX > x1 ? x1 : (g.camX < x0 ? x0 : null);
    if (sx != null) {
      _quad(c, project(sx, y0, z0), project(sx, h, z1), project(sx, 0, z1), project(sx, 0, z0),
          _fill(_fogged(const Color(0xFF4F555C), z0)));
    }
    // Sloped top.
    _quad(c, project(x0, y0, z0), project(x1, y0, z0), project(x1, h, z1), project(x0, h, z1),
        _fill(_fogged(const Color(0xFF9097A0), z0)));
    // Grip stripes.
    final stripe = Paint()
      ..color = _fogged(const Color(0xFFF2B705), z0)
      ..strokeWidth = max(1.0, scaleAt(z0) * 0.05);
    for (var t = 0.1; t < 1.0; t += 0.18) {
      final z = o.z + o.length * t;
      if (z < z0) continue;
      final y = h * t;
      c.drawLine(project(x0 + 0.08, y + 0.01, z), project(x1 - 0.08, y + 0.01, z), stripe);
    }
  }

  /// Projective transform mapping [src] onto the quad [q] (TL, TR, BR, BL).
  Float64List _rectToQuad(Rect src, List<Offset> q) {
    final x0 = q[0].dx, y0 = q[0].dy;
    final x1 = q[1].dx, y1 = q[1].dy;
    final x2 = q[2].dx, y2 = q[2].dy;
    final x3 = q[3].dx, y3 = q[3].dy;
    final dx1 = x1 - x2, dx2 = x3 - x2, dx3 = x0 - x1 + x2 - x3;
    final dy1 = y1 - y2, dy2 = y3 - y2, dy3 = y0 - y1 + y2 - y3;
    double a, b, cc, d, e, f, gg, hh;
    final den = dx1 * dy2 - dx2 * dy1;
    if (den.abs() < 1e-9) {
      gg = 0;
      hh = 0;
    } else {
      gg = (dx3 * dy2 - dx2 * dy3) / den;
      hh = (dx1 * dy3 - dx3 * dy1) / den;
    }
    a = x1 - x0 + gg * x1;
    b = x3 - x0 + hh * x3;
    cc = x0;
    d = y1 - y0 + gg * y1;
    e = y3 - y0 + hh * y3;
    f = y0;
    // Pre-multiply by the src->unit-square mapping.
    final sx = 1 / src.width, sy = 1 / src.height;
    final tx = -src.left * sx, ty = -src.top * sy;
    // Unit-square homography H = [[a,b,cc],[d,e,f],[gg,hh,1]]; M = H * S.
    final m00 = a * sx, m01 = b * sy, m02 = a * tx + b * ty + cc;
    final m10 = d * sx, m11 = e * sy, m12 = d * tx + e * ty + f;
    final m20 = gg * sx, m21 = hh * sy, m22 = gg * tx + hh * ty + 1;
    // Column-major 4x4.
    return Float64List.fromList([
      m00, m10, 0, m20, //
      m01, m11, 0, m21, //
      0, 0, 1, 0, //
      m02, m12, 0, m22, //
    ]);
  }

  // ---------------------------------------------------- coins & power-ups

  void _drawCoin(Canvas c, Coin coin) {
    final s = scaleAt(coin.z);
    final o = project(coin.x, coin.y, coin.z);
    final r = 0.24 * s;
    if (r < 0.6) return;
    final spin = cos(g.time * 5 + coin.z * 0.7).abs() * 0.85 + 0.15;
    final rect = Rect.fromCenter(center: o, width: r * 2 * spin, height: r * 2);
    c.drawOval(rect.inflate(r * 0.12), _fill(_fogged(const Color(0xFFB7770B), coin.z)));
    c.drawOval(rect, _fill(_fogged(const Color(0xFFFFC928), coin.z)));
    c.drawOval(rect.deflate(r * 0.3), _fill(_fogged(const Color(0xFFF2A90F), coin.z)));
    c.drawOval(
      Rect.fromCenter(center: o.translate(-r * 0.25 * spin, -r * 0.3), width: r * 0.5 * spin, height: r * 0.35),
      _fill(Colors.white.withValues(alpha: 0.6 * (1 - _fog(coin.z)))),
    );
  }

  static final _x2 = TextPainter(
    text: const TextSpan(
      text: 'x2',
      style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  void _drawPowerUp(Canvas c, PowerUp p) {
    final s = scaleAt(p.z);
    final o = project(laneX(p.lane), p.y + sin(g.time * 3) * 0.12, p.z);
    final r = 0.42 * s;
    if (r < 1) return;
    final color = switch (p.kind) {
      PowerKind.magnet => const Color(0xFFE53935),
      PowerKind.multiplier => const Color(0xFF8E24AA),
      PowerKind.sneakers => ethGreen,
    };
    c.drawCircle(
      o,
      r * 1.4,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.5),
    );
    c.drawCircle(o, r * 1.05, _fill(Colors.white));
    c.drawCircle(o, r, _fill(color));
    switch (p.kind) {
      case PowerKind.magnet:
        final m = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.28
          ..strokeCap = StrokeCap.butt;
        c.drawArc(Rect.fromCircle(center: o.translate(0, r * 0.1), radius: r * 0.45), 0, pi, false, m);
        c.drawLine(o.translate(-r * 0.45, r * 0.1), o.translate(-r * 0.45, -r * 0.45), m);
        c.drawLine(o.translate(r * 0.45, r * 0.1), o.translate(r * 0.45, -r * 0.45), m);
        c.drawRect(Rect.fromLTWH(o.dx - r * 0.6, o.dy - r * 0.55, r * 0.3, r * 0.2), _fill(const Color(0xFFCFD8DC)));
        c.drawRect(Rect.fromLTWH(o.dx + r * 0.3, o.dy - r * 0.55, r * 0.3, r * 0.2), _fill(const Color(0xFFCFD8DC)));
      case PowerKind.multiplier:
        c.save();
        c.translate(o.dx, o.dy);
        final k = r * 1.3 / _x2.width;
        c.scale(k);
        _x2.paint(c, Offset(-_x2.width / 2, -_x2.height / 2));
        c.restore();
      case PowerKind.sneakers:
        final shoe = Path()
          ..moveTo(o.dx - r * 0.6, o.dy + r * 0.3)
          ..lineTo(o.dx - r * 0.55, o.dy - r * 0.35)
          ..lineTo(o.dx - r * 0.1, o.dy - r * 0.3)
          ..quadraticBezierTo(o.dx + r * 0.1, o.dy, o.dx + r * 0.6, o.dy + r * 0.05)
          ..lineTo(o.dx + r * 0.62, o.dy + r * 0.3)
          ..close();
        c.drawPath(shoe, _fill(Colors.white));
        c.drawRect(Rect.fromLTWH(o.dx - r * 0.6, o.dy + r * 0.18, r * 1.22, r * 0.12), _fill(ethYellow));
        c.drawRect(Rect.fromLTWH(o.dx - r * 0.6, o.dy + r * 0.3, r * 1.22, r * 0.1), _fill(ethRed));
    }
  }

  // ------------------------------------------------------------- player

  void _drawPlayer(Canvas c) {
    if (g.invincible > 0 && (g.time * 10).floor().isEven) return;
    final s = scaleAt(g.pz);
    final surf = g.surfaceAt(g.physLane, g.pz);
    final shadow = project(g.px, surf + 0.01, g.pz);
    final air = (g.py - surf).clamp(0.0, 4.0);
    final sw = 0.75 * s * (1 - air * 0.12);
    c.drawOval(
      Rect.fromCenter(center: shadow, width: sw, height: sw * 0.28),
      _fill(Colors.black.withValues(alpha: 0.28)),
    );
    final feet = project(g.px, g.py, g.pz);
    final pose = switch (g.state.value) {
      GameState.menu => Pose.idle,
      GameState.crashed || GameState.over => Pose.crash,
      _ => g.rolling ? Pose.roll : (g.grounded ? Pose.run : Pose.jump),
    };
    c.save();
    c.translate(feet.dx, feet.dy);
    // Drawn ~20% larger than the hitbox so the character reads well on phones.
    final k = s * playerHeight * 1.2 / 100;
    c.scale(k);
    // Lean into lane changes.
    final lean = ((laneX(g.targetLane) - g.px) / laneWidth).clamp(-1.0, 1.0);
    c.rotate(lean * 0.12);
    CharacterPainter.paint(c, g.character, pose, phase: g.runPhase, t: g.time);
    c.restore();
  }

  // ------------------------------------------------------------ scenery

  void _drawPoles(Canvas c, double z) {
    if (z < _zNear + 0.5) return;
    final s = scaleAt(z);
    final col = _fogged(const Color(0xFF55595F), z);
    final p = Paint()
      ..color = col
      ..strokeWidth = max(1.0, 0.13 * s)
      ..strokeCap = StrokeCap.round;
    for (final side in [-1.0, 1.0]) {
      final x = side * 2.85;
      c.drawLine(project(x, 0, z), project(x, 4.6, z), p);
      final arm = Paint()
        ..color = col
        ..strokeWidth = max(1.0, 0.06 * s);
      c.drawLine(project(x, 4.45, z), project(side * 0.2, 4.45, z), arm);
    }
  }

  void _drawPalm(Canvas c, int i, double z) {
    if (z < _zNear + 0.5) return;
    final side = _hash(i, 2) > 0.5 ? 1.0 : -1.0;
    final x = side * (5.2 + _hash(i, 3) * 3.5);
    final height = 4.2 + _hash(i, 4) * 2.2;
    final s = scaleAt(z);
    final base = project(x, 0, z);
    final topW = Offset(x + side * 0.4, height);
    final top = project(topW.dx, topW.dy, z);
    final trunk = Paint()
      ..color = _fogged(const Color(0xFF8B6B4A), z)
      ..strokeWidth = max(1.0, 0.28 * s)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final mid = project(x + side * 0.05, height * 0.55, z);
    _path
      ..reset()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(mid.dx + side * 0.25 * s, mid.dy, top.dx, top.dy);
    c.drawPath(_path, trunk);
    final leaf = Paint()
      ..color = _fogged(const Color(0xFF2E8B3E), z)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = max(1.0, 0.32 * s);
    final leafDark = Paint()
      ..color = _fogged(const Color(0xFF1F6B2C), z)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = max(1.0, 0.22 * s);
    for (var k = 0; k < 7; k++) {
      final a = -pi / 2 + (k - 3) * 0.5 + sin(g.time * 1.3 + i) * 0.04;
      final len = (1.9 + (k.isEven ? 0.3 : 0)) * s;
      final end = top + Offset(cos(a) * len, sin(a) * len * 0.5 + len * 0.35);
      final ctrl = top + Offset(cos(a) * len * 0.5, sin(a) * len * 0.5 - len * 0.12);
      _path
        ..reset()
        ..moveTo(top.dx, top.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
      c.drawPath(_path, k.isEven ? leaf : leafDark);
    }
  }

  static const _buildingPalette = [
    Color(0xFFF4A261), Color(0xFFE76F51), Color(0xFF2A9D8F), Color(0xFFE9C46A),
    Color(0xFF8ECAE6), Color(0xFFB5838D), Color(0xFF90BE6D), Color(0xFFF28482),
    Color(0xFFCDB4DB), Color(0xFFFFB703), Color(0xFF6D9DC5),
  ];

  void _drawBuildings(Canvas c, int i, double z) {
    for (final side in [-1.0, 1.0]) {
      final salt = side > 0 ? 10 : 20;
      if (_hash(i, salt) < 0.15) continue;
      final bw = 5.0 + _hash(i, salt + 1) * 3;
      final bd = 8.0 + _hash(i, salt + 2) * 3;
      final bh = 6.0 + _hash(i, salt + 3) * 12;
      final xInner = side * (10.5 + _hash(i, salt + 4) * 2.5);
      final xOuter = xInner + side * bw;
      final col = _buildingPalette[(_hash(i, salt + 5) * _buildingPalette.length).floor()];
      final z0 = max(z, _zNear);
      final z1 = z + bd;
      if (z1 <= _zNear) continue;
      // Inner side face (towards the track).
      _quad(c, project(xInner, bh, z0), project(xInner, bh, z1), project(xInner, 0, z1),
          project(xInner, 0, z0), _fill(_fogged(Color.lerp(col, Colors.black, 0.22)!, z0)));
      // Side windows.
      final win = _fill(_fogged(const Color(0xFFEAF4FB), z0));
      for (var wy = 1.4; wy < bh - 0.8; wy += 2.2) {
        for (var wz = z + 1.0; wz < z1 - 1.0; wz += 2.0) {
          if (wz < _zNear + 0.5) continue;
          _quad(c, project(xInner, wy + 1.0, wz), project(xInner, wy + 1.0, wz + 1.0),
              project(xInner, wy, wz + 1.0), project(xInner, wy, wz), win);
        }
      }
      // Front face.
      if (z >= _zNear) {
        final r = Rect.fromPoints(project(xInner, bh, z), project(xOuter, 0, z));
        c.drawRect(r, _fill(_fogged(col, z)));
        final fw = _fill(_fogged(const Color(0xFFFFFFFF).withValues(alpha: 0.75), z));
        for (var wy = 1.4; wy < bh - 0.8; wy += 2.2) {
          for (var k = 0; k < 3; k++) {
            final wx0 = xInner + side * (0.8 + k * (bw - 1.2) / 3);
            final a = project(wx0, wy + 1.0, z);
            final b = project(wx0 + side * 0.9, wy, z);
            c.drawRect(Rect.fromPoints(a, b), fw);
          }
        }
        // Rooftop water tank / sign.
        if (_hash(i, salt + 6) > 0.6) {
          final t = Rect.fromPoints(
            project(xInner + side * 1.0, bh + 1.2, z),
            project(xInner + side * 2.2, bh, z),
          );
          c.drawRect(t, _fill(_fogged(const Color(0xFF3C6E9F), z)));
        }
      }
    }
  }

  void _drawShelter(Canvas c, double z) {
    // Station canopy on the left platform, like the key art.
    const len = 14.0;
    final z0 = max(z, _zNear);
    final z1 = z + len;
    if (z1 <= _zNear) return;
    const xa = -4.6, xb = -2.7, roofY = 3.4;
    final post = Paint()
      ..color = _fogged(const Color(0xFF3D4A5C), z0)
      ..strokeWidth = max(1.0, scaleAt(z0) * 0.12);
    for (var pz = z + 1; pz < z1; pz += 4.3) {
      if (pz < _zNear + 0.3) continue;
      c.drawLine(project(-3.4, 0, pz), project(-3.4, roofY, pz), post);
    }
    _quad(c, project(xa, roofY + 0.4, z0), project(xb, roofY, z0), project(xb, roofY, z1),
        project(xa, roofY + 0.4, z1), _fill(_fogged(const Color(0xFF5B4636), z0)));
    _quad(c, project(xa, roofY + 0.4, z0), project(xb, roofY, z0), project(xb, roofY - 0.25, z0),
        project(xa, roofY + 0.15, z0), _fill(_fogged(const Color(0xFF3B2C22), z0)));
    // Station sign.
    if (z >= _zNear) {
      final r = Rect.fromPoints(project(-4.4, 2.7, z + 0.2), project(-2.9, 2.0, z + 0.2));
      c.drawRect(r, _fill(_fogged(const Color(0xFF1E6B3A), z)));
      c.drawRect(
        r.deflate(max(0.5, r.height * 0.08)),
        Paint()
          ..color = _fogged(Colors.white, z)
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(0.5, r.height * 0.05),
      );
    }
  }
}
