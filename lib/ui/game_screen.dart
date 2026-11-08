import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../ads/ad_config.dart';
import '../ads/ad_manager.dart';
import '../ads/banner_ad.dart';
import '../game/addis_game.dart';
import '../game/entities.dart';
import '../game/textures.dart';
import '../progress.dart';
import 'character_select.dart';
import 'widgets.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final AddisGame _game;
  bool _showCharacters = false;

  // Swipe detection.
  Offset? _swipeStart;
  bool _swipeUsed = false;

  // Per-run results.
  bool _runRecorded = false;
  bool _newBest = false;
  bool _doubled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = AddisGame(character: Progress.instance.selected);
    _game.state.addListener(_onStateChanged);
    Progress.instance.addListener(_onProgress);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _game.state.removeListener(_onStateChanged);
    Progress.instance.removeListener(_onProgress);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _game.pause();
  }

  void _onProgress() => _game.character = Progress.instance.selected;

  Future<void> _onStateChanged() async {
    if (_game.state.value == GameState.over && !_runRecorded) {
      _runRecorded = true;
      final best = await Progress.instance.recordRun(
        score: _game.finalScore,
        coinsCollected: _game.coinsThisRun,
      );
      if (mounted) setState(() => _newBest = best);
    }
  }

  void _startRun() {
    _runRecorded = false;
    _newBest = false;
    _doubled = false;
    _game.startRun();
    if (!Progress.instance.tutorialSeen) {
      Future.delayed(const Duration(seconds: 8), Progress.instance.markTutorialSeen);
    }
  }

  /// Leaving the game-over screen is the natural break where an
  /// interstitial may show (subject to the rules in [AdConfig]).
  Future<void> _leaveGameOver({required bool playAgain}) async {
    await AdManager.instance.onRunFinished(totalRuns: Progress.instance.runsPlayed);
    if (!mounted) return;
    if (playAgain) {
      _startRun();
    } else {
      _game.goToMenu();
    }
  }

  // ------------------------------------------------------------- input

  void _onPointerDown(PointerDownEvent e) {
    _swipeStart = e.position;
    _swipeUsed = false;
  }

  void _onPointerMove(PointerMoveEvent e) {
    final start = _swipeStart;
    if (start == null || _swipeUsed) return;
    final d = e.position - start;
    const threshold = 22.0;
    if (d.distance < threshold) return;
    _swipeUsed = true;
    if (d.dx.abs() > d.dy.abs()) {
      _game.handle(d.dx > 0 ? InputAction.right : InputAction.left);
    } else {
      _game.handle(d.dy < 0 ? InputAction.jump : InputAction.roll);
    }
  }

  // ------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Listener(
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: (_) => _swipeStart = null,
            child: GameWidget(game: _game, autofocus: true),
          ),
          ValueListenableBuilder<GameState>(
            valueListenable: _game.state,
            builder: (context, state, _) {
              return switch (state) {
                GameState.menu => _showCharacters
                    ? CharacterSelect(onClose: () => setState(() => _showCharacters = false))
                    : _MenuOverlay(
                        onPlay: _startRun,
                        onCharacters: () => setState(() => _showCharacters = true),
                      ),
                GameState.playing => _Hud(game: _game),
                GameState.paused => _PauseOverlay(
                    game: _game,
                    onHome: () => _game.goToMenu(),
                  ),
                GameState.crashed => _ContinueOverlay(game: _game),
                GameState.over => _GameOverOverlay(
                    game: _game,
                    newBest: _newBest,
                    doubled: _doubled,
                    onDouble: () async {
                      final ok = await AdManager.instance.showRewarded();
                      if (ok && !_doubled) {
                        await Progress.instance.addCoins(_game.coinsThisRun);
                        if (mounted) setState(() => _doubled = true);
                      }
                    },
                    onPlayAgain: () => _leaveGameOver(playAgain: true),
                    onHome: () => _leaveGameOver(playAgain: false),
                  ),
              };
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- menu

class _MenuOverlay extends StatelessWidget {
  const _MenuOverlay({required this.onPlay, required this.onCharacters});
  final VoidCallback onPlay;
  final VoidCallback onCharacters;

  @override
  Widget build(BuildContext context) {
    final progress = Progress.instance;
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) => Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _BestBadge(best: progress.bestScore),
                        const Spacer(),
                        CoinBadge(amount: progress.coins),
                        ValueListenableBuilder<bool>(
                          valueListenable: AdManager.instance.privacyOptionsRequired,
                          builder: (context, required, _) => required
                              ? IconButton(
                                  tooltip: 'Privacy settings',
                                  onPressed: AdManager.instance.showPrivacyOptions,
                                  icon: const Icon(Icons.privacy_tip_outlined, color: Colors.white),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const GameLogo(),
                    const Spacer(),
                    _PulsingPlay(onTap: onPlay),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: ChunkyButton(
                            label: 'CREW',
                            icon: Icons.people_alt_rounded,
                            color: const Color(0xFF2E86DE),
                            fontSize: 17,
                            onPressed: onCharacters,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ValueListenableBuilder<bool>(
                            valueListenable: AdManager.instance.rewardedReady,
                            builder: (context, ready, _) => ChunkyButton(
                              label: '+${AdConfig.rewardedCoinAmount} FREE',
                              icon: Icons.ondemand_video_rounded,
                              color: const Color(0xFFF08A00),
                              fontSize: 17,
                              onPressed: ready
                                  ? () async {
                                      final ok = await AdManager.instance.showRewarded();
                                      if (ok) {
                                        await progress.addCoins(AdConfig.rewardedCoinAmount);
                                      }
                                    }
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
          const AdBanner(),
        ],
      ),
    );
  }
}

class _BestBadge extends StatelessWidget {
  const _BestBadge({required this.best});
  final int best;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded, color: ethYellow, size: 20),
          const SizedBox(width: 6),
          Text(
            '$best',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _PulsingPlay extends StatefulWidget {
  const _PulsingPlay({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_PulsingPlay> createState() => _PulsingPlayState();
}

class _PulsingPlayState extends State<_PulsingPlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: SizedBox(
        width: 260,
        child: ChunkyButton(
          label: 'TAP TO RUN',
          icon: Icons.play_arrow_rounded,
          fontSize: 26,
          onPressed: widget.onTap,
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- HUD

class _Hud extends StatelessWidget {
  const _Hud({required this.game});
  final AddisGame game;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: game.scoreN,
                    builder: (context, s, _) => Text(
                      s.toString().padLeft(6, '0'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        fontFeatures: [FontFeature.tabularFigures()],
                        shadows: [Shadow(blurRadius: 4, color: Colors.black87, offset: Offset(2, 2))],
                      ),
                    ),
                  ),
                  const Spacer(),
                  ValueListenableBuilder<int>(
                    valueListenable: game.coinsN,
                    builder: (context, c, _) => CoinBadge(amount: c),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: game.pause,
                      icon: const Icon(Icons.pause_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                top: 48,
                child: ValueListenableBuilder<Map<PowerKind, double>>(
                  valueListenable: game.powersN,
                  builder: (context, powers, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final e in powers.entries) _PowerBar(kind: e.key, remaining: e.value),
                    ],
                  ),
                ),
              ),
              if (!Progress.instance.tutorialSeen)
                const Align(alignment: Alignment(0, 0.1), child: IgnorePointer(child: _Tutorial())),
            ],
          ),
        ),
      ),
    );
  }
}

class _PowerBar extends StatelessWidget {
  const _PowerBar({required this.kind, required this.remaining});
  final PowerKind kind;
  final double remaining;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String label) = switch (kind) {
      PowerKind.magnet => (Icons.attractions_rounded, const Color(0xFFE53935), 'MAGNET'),
      PowerKind.multiplier => (Icons.close_rounded, const Color(0xFF8E24AA), 'x2 SCORE'),
      PowerKind.sneakers => (Icons.directions_run_rounded, ethGreen, 'SUPER JUMP'),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: LinearProgressIndicator(
              value: (remaining / AddisGame.powerDuration).clamp(0, 1),
              color: color,
              backgroundColor: Colors.white24,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tutorial extends StatefulWidget {
  const _Tutorial();

  @override
  State<_Tutorial> createState() => _TutorialState();
}

class _TutorialState extends State<_Tutorial> {
  bool _visible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 600),
      child: _content(),
    );
  }

  Widget _content() {
    Widget row(IconData i, String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(i, color: ethYellow),
              const SizedBox(width: 8),
              Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(Icons.swap_horiz_rounded, 'Swipe left / right to switch tracks'),
          row(Icons.arrow_upward_rounded, 'Swipe up to jump'),
          row(Icons.arrow_downward_rounded, 'Swipe down to roll'),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- pause

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.game, required this.onHome});
  final AddisGame game;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black45,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Panel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'PAUSED',
                      style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 20),
                    ChunkyButton(label: 'RESUME', icon: Icons.play_arrow_rounded, onPressed: game.resume),
                    const SizedBox(height: 12),
                    ChunkyButton(
                      label: 'HOME',
                      icon: Icons.home_rounded,
                      color: const Color(0xFF2E86DE),
                      onPressed: onHome,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const AdBanner(),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ continue

class _ContinueOverlay extends StatefulWidget {
  const _ContinueOverlay({required this.game});
  final AddisGame game;

  @override
  State<_ContinueOverlay> createState() => _ContinueOverlayState();
}

class _ContinueOverlayState extends State<_ContinueOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _timer;
  bool _offer = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _offer = !widget.game.continuedThisRun && AdManager.instance.rewardedReady.value;
    _timer = AnimationController(
      vsync: this,
      duration: _offer ? const Duration(seconds: 5) : const Duration(milliseconds: 1100),
    )
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && !_busy) widget.game.endRun();
      })
      ..forward();
  }

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  Future<void> _watch() async {
    _busy = true;
    _timer.stop();
    final ok = await AdManager.instance.showRewarded();
    if (!mounted) return;
    if (ok) {
      widget.game.continueRun();
    } else {
      widget.game.endRun();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_offer) return const SizedBox.shrink();
    return Container(
      color: Colors.black38,
      alignment: Alignment.center,
      child: Panel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'KEEP RUNNING?',
              style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 90,
              height: 90,
              child: AnimatedBuilder(
                animation: _timer,
                builder: (context, _) => Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: 1 - _timer.value,
                      strokeWidth: 8,
                      color: ethYellow,
                      backgroundColor: Colors.white12,
                    ),
                    Center(
                      child: Text(
                        '${(5 * (1 - _timer.value)).ceil()}',
                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            ChunkyButton(
              label: 'WATCH AD TO CONTINUE',
              icon: Icons.ondemand_video_rounded,
              fontSize: 17,
              onPressed: _busy ? null : _watch,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : widget.game.endRun,
              child: const Text('No thanks', style: TextStyle(color: Colors.white70, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- game over

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({
    required this.game,
    required this.newBest,
    required this.doubled,
    required this.onDouble,
    required this.onPlayAgain,
    required this.onHome,
  });

  final AddisGame game;
  final bool newBest;
  final bool doubled;
  final VoidCallback onDouble;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Panel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        newBest ? 'NEW BEST!' : 'GAME OVER',
                        style: TextStyle(
                          color: newBest ? ethYellow : Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${game.finalScore}',
                        style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'BEST  ${Progress.instance.bestScore}',
                        style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      CoinBadge(amount: doubled ? game.coinsThisRun * 2 : game.coinsThisRun, big: true),
                      const SizedBox(height: 18),
                      if (game.coinsThisRun > 0 && !doubled)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ValueListenableBuilder<bool>(
                            valueListenable: AdManager.instance.rewardedReady,
                            builder: (context, ready, _) => ChunkyButton(
                              label: 'DOUBLE COINS',
                              icon: Icons.ondemand_video_rounded,
                              color: const Color(0xFFF08A00),
                              fontSize: 18,
                              onPressed: ready ? onDouble : null,
                            ),
                          ),
                        ),
                      ChunkyButton(label: 'RUN AGAIN', icon: Icons.replay_rounded, onPressed: onPlayAgain),
                      const SizedBox(height: 12),
                      ChunkyButton(
                        label: 'HOME',
                        icon: Icons.home_rounded,
                        color: const Color(0xFF2E86DE),
                        onPressed: onHome,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const AdBanner(),
        ],
      ),
    );
  }
}
