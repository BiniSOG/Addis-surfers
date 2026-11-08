import 'dart:math';

import 'package:flutter/material.dart';

import '../ads/ad_manager.dart';
import '../audio/audio_manager.dart';
import '../game/textures.dart';
import '../meta/rewards.dart';
import '../progress.dart';
import 'prize_view.dart';
import 'widgets.dart';

/// Daily Lucky Spin: one free spin a day plus a few extra for watching ads.
Future<void> showLuckySpin(BuildContext context) => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(12),
        child: _LuckySpin(),
      ),
    );

class _LuckySpin extends StatefulWidget {
  const _LuckySpin();

  @override
  State<_LuckySpin> createState() => _LuckySpinState();
}

class _LuckySpinState extends State<_LuckySpin> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );
  double _from = 0, _to = 0;
  int _lastTick = 0;
  bool _spinning = false;
  String? _result;

  static const _segments = 8;
  static const _segAngle = 2 * pi / _segments;

  double get _angle => _from + (_to - _from) * Curves.easeOutCubic.transform(_anim.value);

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      final tick = (_angle / _segAngle).floor();
      if (tick != _lastTick) {
        _lastTick = tick;
        AudioManager.instance.sfx(Sfx.spinTick, volume: 0.6);
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _spin({required bool viaAd}) async {
    if (_spinning) return;
    if (viaAd && !await AdManager.instance.showRewarded()) return;
    final res = await Progress.instance.spin(viaAd: viaAd);
    if (res == null || !mounted) return;
    final (index, text) = res;
    setState(() {
      _spinning = true;
      _result = null;
      _from = _angle % (2 * pi);
      // Segment i is centred at angle i*seg (clockwise from the top); rotate
      // the wheel so that it ends under the pointer.
      final target = -index * _segAngle + (Random().nextDouble() - 0.5) * _segAngle * 0.6;
      var to = target;
      while (to < _from + 5 * 2 * pi) {
        to += 2 * pi;
      }
      _to = to;
    });
    await _anim.forward(from: 0);
    if (!mounted) return;
    AudioManager.instance.sfx(Sfx.mission);
    setState(() {
      _spinning = false;
      _result = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Progress.instance;
    return Panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('LUCKY SPIN',
              style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          SizedBox(
            width: 280,
            height: 300,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: 18,
                  child: Transform.rotate(
                    angle: _angle,
                    child: const SizedBox(width: 270, height: 270, child: _Wheel()),
                  ),
                ),
                // Pointer.
                const Icon(Icons.arrow_drop_down_rounded, size: 64, color: Colors.white,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black)]),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: _result == null
                ? null
                : Text('You won: $_result',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: ethYellow, fontSize: 18, fontWeight: FontWeight.w900)),
          ),
          if (p.freeSpinAvailable)
            ChunkyButton(
              label: 'FREE SPIN',
              icon: Icons.casino_rounded,
              onPressed: _spinning ? null : () => _spin(viaAd: false),
            )
          else if (p.adSpinsLeft > 0)
            ValueListenableBuilder<bool>(
              valueListenable: AdManager.instance.rewardedReady,
              builder: (context, ready, _) => ChunkyButton(
                label: 'SPIN AGAIN (${p.adSpinsLeft} left)',
                icon: Icons.ondemand_video_rounded,
                color: const Color(0xFFF08A00),
                fontSize: 17,
                onPressed: _spinning || !ready ? null : () => _spin(viaAd: true),
              ),
            )
          else
            const Text('Come back tomorrow for a free spin!',
                style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _spinning ? null : () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white70, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: _WheelPainter())),
        for (var i = 0; i < spinPrizes.length; i++)
          Positioned.fill(
            child: Transform.rotate(
              angle: i * 2 * pi / spinPrizes.length,
              child: Align(
                alignment: const Alignment(0, -0.62),
                child: PrizeChip(prize: spinPrizes[i], size: 20),
              ),
            ),
          ),
        Center(
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF14213D),
              shape: BoxShape.circle,
              border: Border.all(color: ethYellow, width: 4),
            ),
          ),
        ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  const _WheelPainter();

  static const _colors = [ethGreen, Color(0xFFB8860B), ethRed, Color(0xFF2E86DE)];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    final n = spinPrizes.length;
    final seg = 2 * pi / n;
    for (var i = 0; i < n; i++) {
      canvas.drawArc(rect, -pi / 2 - seg / 2 + i * seg, seg, true,
          Paint()..color = _colors[i % _colors.length]);
    }
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = Colors.white,
    );
    for (var i = 0; i < n; i++) {
      final a = -pi / 2 - seg / 2 + i * seg;
      canvas.drawCircle(c + Offset(cos(a), sin(a)) * (r - 3), 4, Paint()..color = ethYellow);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
