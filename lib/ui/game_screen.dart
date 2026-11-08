import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../ads/ad_config.dart';
import '../ads/ad_manager.dart';
import '../ads/banner_ad.dart';
import '../audio/audio_manager.dart';
import '../audio/haptics.dart';
import '../game/addis_game.dart';
import '../game/entities.dart';
import '../game/textures.dart';
import '../meta/daily.dart';
import '../meta/economy.dart';
import '../meta/missions.dart';
import '../progress.dart';
import '../settings.dart';
import 'character_select.dart';
import 'about_screen.dart';
import 'daily_reward_dialog.dart';
import 'event_screen.dart';
import 'lucky_spin.dart';
import 'missions_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'trophies_screen.dart';
import 'widgets.dart';

enum _Page { home, crew, shop, missions, settings, event, trophies, about }

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final AddisGame _game;
  _Page _page = _Page.home;
  bool _dailyShownThisSession = false;

  // Swipe / double-tap detection.
  Offset? _swipeStart;
  bool _swipeUsed = false;
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _downAt = DateTime.fromMillisecondsSinceEpoch(0);

  // Per-run results.
  bool _runRecorded = false;
  bool _newBest = false;
  bool _doubled = false;
  MissionUpdate? _missionResult;
  final Set<int> _toastedMissions = {};

  /// Short messages shown during a run ("Mission complete!", letters...).
  final ValueNotifier<String?> _toast = ValueNotifier(null);
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final p = Progress.instance;
    _game = AddisGame(character: p.selected)
      ..onEvent = _onGameEvent
      ..onCrash = () {};
    _applyConfig();
    _game.state.addListener(_onStateChanged);
    _game.scoreN.addListener(_checkLiveMissions);
    _game.powersN.addListener(_updateMusicMode);
    p.addListener(_onProgress);
    GameSettings.instance.addListener(_applyConfig);
    AudioManager.instance.setMode(MusicMode.menu);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowDaily());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _game.state.removeListener(_onStateChanged);
    _game.scoreN.removeListener(_checkLiveMissions);
    _game.powersN.removeListener(_updateMusicMode);
    Progress.instance.removeListener(_onProgress);
    GameSettings.instance.removeListener(_applyConfig);
    _toastTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _game.pause();
  }

  void _applyConfig() {
    final p = Progress.instance;
    final s = GameSettings.instance;
    _game
      ..character = p.selected
      ..powerDurations = p.powerDurations
      ..scoreMultiplier = p.scoreMultiplier
      ..lowGraphics = s.lowGraphics;
  }

  void _onProgress() {
    if (_game.state.value == GameState.menu) _applyConfig();
    _game.character = Progress.instance.selected;
  }

  Future<void> _maybeShowDaily() async {
    if (_dailyShownThisSession || !mounted) return;
    if (Progress.instance.claimableDailyIndex == null) return;
    _dailyShownThisSession = true;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted && _game.state.value == GameState.menu) await showDailyRewardDialog(context);
  }

  void _showToast(String text) {
    _toast.value = text;
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 1800), () => _toast.value = null);
  }

  // ------------------------------------------------------------ game events

  void _onGameEvent(GameEvent e, Object? data) {
    final a = AudioManager.instance;
    final h = Haptics.instance;
    switch (e) {
      case GameEvent.coin:
        a.sfx(Sfx.coin, volume: 0.55);
        h.play(Haptic.coin);
      case GameEvent.jump:
        if (data == true) {
          a.sfx(Sfx.superJump, volume: 0.8);
          h.play(Haptic.superJump);
        } else {
          a.sfx(Sfx.jump, volume: 0.7);
          h.play(Haptic.jump);
        }
      case GameEvent.roll:
        a.sfx(Sfx.roll, volume: 0.75);
        a.duck();
        h.play(Haptic.roll);
      case GameEvent.laneChange:
        a.sfx(Sfx.swipe, volume: 0.45);
        h.play(Haptic.laneChange);
      case GameEvent.stumble:
        a.sfx(Sfx.stumble);
        h.play(Haptic.stumble);
      case GameEvent.crash:
        a.sfx(Sfx.crash);
        h.play(Haptic.crash);
      case GameEvent.powerUp:
        if (data == PowerKind.magnet) {
          a.sfx(Sfx.magnet);
          h.play(Haptic.magnetOn);
        } else {
          a.sfx(Sfx.powerup);
          h.play(Haptic.powerUp);
        }
        if (data is PowerKind) _showToast(powerName(data).toUpperCase());
      case GameEvent.jetpack:
        a.sfx(Sfx.fly);
        a.sfx(Sfx.jetpack, volume: 0.6);
        h.play(Haptic.flyOn);
        _showToast('JETPACK!');
      case GameEvent.headStart:
        a.sfx(Sfx.fly);
        a.sfx(Sfx.jetpack, volume: 0.6);
        h.play(Haptic.flyOn);
        _showToast('HEAD START!');
      case GameEvent.land:
        a.sfx(Sfx.land);
        h.play(Haptic.land);
      case GameEvent.gem:
        a.sfx(Sfx.gem);
        h.play(Haptic.gem);
        _showToast('+1 GEM');
      case GameEvent.letter:
        a.sfx(Sfx.letter);
        h.play(Haptic.gem);
        _collectLetter(data as String);
      case GameEvent.shieldOn:
        a.sfx(Sfx.powerup);
        h.play(Haptic.powerUp);
      case GameEvent.shieldBreak:
        a.sfx(Sfx.shieldBreak);
        h.play(Haptic.shieldBreak);
        _showToast('SHIELD SAVED YOU!');
      case GameEvent.flower:
        a.sfx(Sfx.flower, volume: 0.5);
        h.play(Haptic.coin);
      case GameEvent.chase:
        a.sfx(Sfx.bleat, volume: 0.8);
      case GameEvent.newBest:
        a.sfx(Sfx.mission);
        h.play(Haptic.reward);
        _showToast('NEW BEST SCORE!');
    }
    _checkLiveMissions();
  }

  /// Picks the version of the soundtrack that matches what the runner is
  /// doing: flying beats shoes beats magnet beats plain running.
  MusicMode get _runMode {
    final p = _game.powers;
    if (_game.flying) return MusicMode.fly;
    if ((p[PowerKind.sneakers] ?? 0) > 0) return MusicMode.shoes;
    if ((p[PowerKind.magnet] ?? 0) > 0) return MusicMode.magnet;
    return MusicMode.run;
  }

  void _updateMusicMode() {
    if (_game.state.value == GameState.playing) AudioManager.instance.setMode(_runMode);
  }

  Future<void> _collectLetter(String letter) async {
    final p = Progress.instance;
    final done = await p.collectLetter(letter);
    _game.setNextLetter(p.nextDailyLetter);
    if (done) {
      AudioManager.instance.sfx(Sfx.mission);
      Haptics.instance.play(Haptic.reward);
      _showToast('${p.dailyWord} COMPLETE! +$dailyWordCoins');
    } else {
      _showToast('LETTER  $letter');
    }
    if (mounted) setState(() {});
  }

  List<int> _runValues({required bool includeRun}) {
    final s = _game.stats;
    return [
      for (final m in Progress.instance.missions)
        m.type == MissionType.runsTotal && !includeRun
            ? 0
            : runValue(
                m.type,
                coins: s.coins,
                score: _game.finalScore,
                roof: s.roofDistance,
                jumps: s.jumps,
                rolls: s.rolls,
                powerUps: s.powerUps,
                laneChanges: s.laneChanges,
              ),
    ];
  }

  void _checkLiveMissions() {
    if (_game.state.value != GameState.playing) return;
    final p = Progress.instance;
    final ms = p.missions;
    final stored = p.missionProgress;
    final live = p.liveProgress(_runValues(includeRun: false));
    for (var i = 0; i < 3; i++) {
      if (!_toastedMissions.contains(i) && stored[i] < ms[i].target && live[i] >= ms[i].target) {
        _toastedMissions.add(i);
        AudioManager.instance.sfx(Sfx.mission);
        Haptics.instance.play(Haptic.reward);
        _showToast('MISSION COMPLETE!\n${ms[i].description}');
      }
    }
  }

  Future<void> _onStateChanged() async {
    final s = _game.state.value;
    final audio = AudioManager.instance;
    switch (s) {
      case GameState.menu:
        audio.setMode(MusicMode.menu);
      case GameState.playing:
        // From the muffled menu mix the song "opens up" into the full track.
        audio.setMode(_runMode);
      case GameState.paused:
        audio.pauseMusic();
      case GameState.crashed:
        audio.tapeStop();
      case GameState.over:
        audio.setMode(MusicMode.menu);
    }
    if (s == GameState.over && !_runRecorded) {
      _runRecorded = true;
      final p = Progress.instance;
      final best = await p.recordRun(
        score: _game.finalScore,
        coinsCollected: _game.stats.coins,
        gemsCollected: _game.stats.gems,
        jetpacks: _game.stats.jetpacks,
        roofDistance: _game.stats.roofDistance,
        flowers: _game.stats.flowers,
      );
      final mission = await p.commitMissionRun(_runValues(includeRun: true));
      if (mission.setCompleted) AudioManager.instance.sfx(Sfx.mission);
      if (mounted) {
        setState(() {
          _newBest = best;
          _missionResult = mission;
        });
      }
    }
  }

  void _startRun() {
    _applyConfig();
    _game.nextLetter = Progress.instance.nextDailyLetter;
    _game.bestScore = Progress.instance.bestScore;
    _runRecorded = false;
    _newBest = false;
    _doubled = false;
    _missionResult = null;
    _toastedMissions.clear();
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
      _maybeShowDaily();
    }
  }

  Future<void> _useShield() async {
    if (_game.shielded || _game.state.value != GameState.playing) return;
    if (await Progress.instance.useShield()) {
      _game.activateShield();
      _showToast('SHIELD ON');
    }
  }

  Future<void> _useHeadStart() async {
    if (await Progress.instance.useHeadStart()) _game.useHeadStart();
  }

  // ------------------------------------------------------------- input

  void _onPointerDown(PointerDownEvent e) {
    _swipeStart = e.position;
    _swipeUsed = false;
    _downAt = DateTime.now();
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

  void _onPointerUp(PointerUpEvent e) {
    _swipeStart = null;
    if (_swipeUsed || _game.state.value != GameState.playing) return;
    final now = DateTime.now();
    if (now.difference(_downAt) > const Duration(milliseconds: 250)) return;
    if (now.difference(_lastTap) < const Duration(milliseconds: 320)) {
      _lastTap = DateTime.fromMillisecondsSinceEpoch(0);
      _useShield(); // double-tap
    } else {
      _lastTap = now;
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
            onPointerUp: _onPointerUp,
            child: GameWidget(game: _game, autofocus: true),
          ),
          ValueListenableBuilder<GameState>(
            valueListenable: _game.state,
            builder: (context, state, _) {
              return switch (state) {
                GameState.menu => _menuPage(),
                GameState.playing => _Hud(
                    game: _game,
                    toast: _toast,
                    onShield: _useShield,
                    onHeadStart: _useHeadStart,
                  ),
                GameState.paused => _PauseOverlay(game: _game, onHome: _game.goToMenu),
                GameState.crashed => _ContinueOverlay(game: _game),
                GameState.over => _GameOverOverlay(
                    game: _game,
                    newBest: _newBest,
                    doubled: _doubled,
                    missionResult: _missionResult,
                    onDouble: () async {
                      final ok = await AdManager.instance.showRewarded();
                      if (ok && !_doubled) {
                        await Progress.instance.addCoins(_game.stats.coins);
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

  Widget _menuPage() {
    void home() => setState(() => _page = _Page.home);
    return switch (_page) {
      _Page.home => _MenuOverlay(
          onPlay: _startRun,
          onOpen: (p) => setState(() => _page = p),
          onDaily: () => showDailyRewardDialog(context),
          onSpin: () => showLuckySpin(context),
        ),
      _Page.crew => CharacterSelect(onClose: home),
      _Page.shop => ShopScreen(onClose: home),
      _Page.missions => MissionsScreen(onClose: home),
      _Page.settings => SettingsScreen(
          onClose: home,
          onAbout: () => setState(() => _page = _Page.about),
        ),
      _Page.about => AboutScreen(onClose: () => setState(() => _page = _Page.settings)),
      _Page.event => EventScreen(onClose: home),
      _Page.trophies => TrophiesScreen(onClose: home),
    };
  }
}

// ---------------------------------------------------------------- menu

class _MenuOverlay extends StatelessWidget {
  const _MenuOverlay({
    required this.onPlay,
    required this.onOpen,
    required this.onDaily,
    required this.onSpin,
  });
  final VoidCallback onPlay;
  final ValueChanged<_Page> onOpen;
  final VoidCallback onDaily;
  final VoidCallback onSpin;

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
                padding: const EdgeInsets.all(14),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Row(
                          children: [
                            _BestBadge(best: progress.bestScore),
                            const Spacer(),
                            CoinBadge(amount: progress.coins),
                            const SizedBox(width: 6),
                            GemBadge(amount: progress.gems),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const GameLogo(),
                        const SizedBox(height: 12),
                        if (!progress.dailyWordDone)
                          _WordStrip(word: progress.dailyWord, collected: progress.dailyWordCollected),
                        const Spacer(),
                        _PulsingPlay(onTap: onPlay),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ChunkyButton(
                                label: 'CREW',
                                icon: Icons.people_alt_rounded,
                                color: const Color(0xFF2E86DE),
                                fontSize: 16,
                                onPressed: () => onOpen(_Page.crew),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ChunkyButton(
                                label: 'SHOP',
                                icon: Icons.storefront_rounded,
                                color: const Color(0xFFF08A00),
                                fontSize: 16,
                                onPressed: () => onOpen(_Page.shop),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                    Positioned(
                      left: 0,
                      top: 56,
                      child: Column(
                        children: [
                          RoundIconButton(
                            icon: Icons.settings_rounded,
                            label: 'Settings',
                            onPressed: () => onOpen(_Page.settings),
                          ),
                          RoundIconButton(
                            icon: Icons.flag_rounded,
                            label: 'Missions',
                            badge: 'x${progress.scoreMultiplier}',
                            color: ethGreen,
                            onPressed: () => onOpen(_Page.missions),
                          ),
                          RoundIconButton(
                            icon: Icons.card_giftcard_rounded,
                            label: 'Daily',
                            badge: progress.claimableDailyIndex != null ? '!' : null,
                            color: ethRed,
                            onPressed: onDaily,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 56,
                      child: Column(
                        children: [
                          RoundIconButton(
                            icon: Icons.casino_rounded,
                            label: 'Spin',
                            badge: progress.freeSpinAvailable ? 'FREE' : null,
                            color: const Color(0xFF8E24AA),
                            onPressed: onSpin,
                          ),
                          RoundIconButton(
                            icon: Icons.local_florist_rounded,
                            label: 'Event',
                            badge: progress.eventClaimable > 0 ? '${progress.eventClaimable}' : null,
                            color: const Color(0xFFF9A825),
                            onPressed: () => onOpen(_Page.event),
                          ),
                          RoundIconButton(
                            icon: Icons.emoji_events_rounded,
                            label: 'Trophies',
                            badge: progress.achievementsClaimable > 0
                                ? '${progress.achievementsClaimable}'
                                : null,
                            color: const Color(0xFF2E86DE),
                            onPressed: () => onOpen(_Page.trophies),
                          ),
                          ValueListenableBuilder<bool>(
                            valueListenable: AdManager.instance.rewardedReady,
                            builder: (context, ready, _) => ready
                                ? RoundIconButton(
                                    icon: Icons.ondemand_video_rounded,
                                    label: '+${AdConfig.rewardedCoinAmount}',
                                    color: const Color(0xFFF08A00),
                                    onPressed: () async {
                                      if (await AdManager.instance.showRewarded()) {
                                        await progress.addCoins(AdConfig.rewardedCoinAmount);
                                        AudioManager.instance.sfx(Sfx.purchase);
                                      }
                                    },
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
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

class _WordStrip extends StatelessWidget {
  const _WordStrip({required this.word, required this.collected});
  final String word;
  final int collected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('DAILY WORD',
              style: TextStyle(color: ethYellow, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 4),
          DailyWordTiles(word: word, collected: collected, size: 24),
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
  const _Hud({
    required this.game,
    required this.toast,
    required this.onShield,
    required this.onHeadStart,
  });

  final AddisGame game;
  final ValueNotifier<String?> toast;
  final VoidCallback onShield;
  final VoidCallback onHeadStart;

  @override
  Widget build(BuildContext context) {
    final p = Progress.instance;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: ethGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'x${game.scoreMultiplier}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                ValueListenableBuilder<int>(
                  valueListenable: game.coinsN,
                  builder: (context, c, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      CoinBadge(amount: c),
                      const SizedBox(height: 4),
                      ValueListenableBuilder<int>(
                        valueListenable: game.flowersN,
                        builder: (context, f, _) => _FlowerCount(count: f),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: () {
                      AudioManager.instance.sfx(Sfx.click);
                      game.pause();
                    },
                    icon: const Icon(Icons.pause_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              top: 80,
              child: ValueListenableBuilder<Map<PowerKind, double>>(
                valueListenable: game.powersN,
                builder: (context, powers, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in powers.entries)
                      _PowerBar(
                        kind: e.key,
                        label: e.key == PowerKind.jetpack && game.headStarting ? 'HEAD START' : null,
                        fraction: e.value / (game.powerMax[e.key] ?? 10),
                      ),
                  ],
                ),
              ),
            ),
            if (!p.dailyWordDone)
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 52),
                  child: ListenableBuilder(
                    listenable: p,
                    builder: (context, _) => p.dailyWordDone
                        ? const SizedBox.shrink()
                        : DailyWordTiles(word: p.dailyWord, collected: p.dailyWordCollected, size: 18),
                  ),
                ),
              ),
            Align(
              alignment: const Alignment(0, -0.45),
              child: IgnorePointer(
                child: ValueListenableBuilder<String?>(
                  valueListenable: toast,
                  builder: (context, t, _) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                    child: t == null
                        ? const SizedBox.shrink()
                        : Container(
                            key: ValueKey(t),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: ethYellow, width: 2),
                            ),
                            child: Text(
                              t,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 24,
              child: ListenableBuilder(
                listenable: Listenable.merge([p, game.powersN]),
                builder: (context, _) => Column(
                  children: [
                    if (p.headStarts > 0 && game.runTime < 6 && !game.flying)
                      _BoostButton(
                        icon: Icons.rocket_launch_rounded,
                        color: const Color(0xFFF08A00),
                        count: p.headStarts,
                        label: 'HEAD START',
                        onTap: onHeadStart,
                      ),
                    if (p.shields > 0 && !game.shielded)
                      _BoostButton(
                        icon: Icons.shield_rounded,
                        color: const Color(0xFF00897B),
                        count: p.shields,
                        label: 'SHIELD',
                        onTap: onShield,
                      ),
                  ],
                ),
              ),
            ),
            if (!p.tutorialSeen)
              const Align(alignment: Alignment(0, 0.1), child: IgnorePointer(child: _Tutorial())),
          ],
        ),
      ),
    );
  }
}

class _FlowerCount extends StatelessWidget {
  const _FlowerCount({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_florist_rounded, color: Color(0xFFFFD21F), size: 16),
          const SizedBox(width: 4),
          Text('$count',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
        ],
      ),
    );
  }
}

class _BoostButton extends StatelessWidget {
  const _BoostButton({
    required this.icon,
    required this.color,
    required this.count,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: RoundIconButton(icon: icon, color: color, badge: '$count', label: label, onPressed: onTap),
    );
  }
}

class _PowerBar extends StatelessWidget {
  const _PowerBar({required this.kind, required this.fraction, this.label});
  final PowerKind kind;
  final double fraction;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final color = powerColor(kind);
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
          Icon(powerIcon(kind), color: color, size: 18),
          const SizedBox(width: 6),
          Text((label ?? powerName(kind)).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: LinearProgressIndicator(
              value: fraction.clamp(0, 1),
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
    _timer = Timer(const Duration(seconds: 7), () {
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
    Widget row(IconData i, String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(i, color: ethYellow),
              const SizedBox(width: 8),
              Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
        );
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 600),
      child: Container(
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
            row(Icons.touch_app_rounded, 'Double-tap to use a shield'),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- pause

class _PauseOverlay extends StatefulWidget {
  const _PauseOverlay({required this.game, required this.onHome});
  final AddisGame game;
  final VoidCallback onHome;

  @override
  State<_PauseOverlay> createState() => _PauseOverlayState();
}

class _PauseOverlayState extends State<_PauseOverlay> {
  int? _count;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _resume() {
    setState(() => _count = 3);
    AudioManager.instance.sfx(Sfx.tick);
    _timer = Timer.periodic(const Duration(milliseconds: 750), (t) {
      final next = (_count ?? 1) - 1;
      if (next <= 0) {
        t.cancel();
        AudioManager.instance.sfx(Sfx.go);
        widget.game.resume();
      } else {
        AudioManager.instance.sfx(Sfx.tick);
        if (mounted) setState(() => _count = next);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_count != null) {
      return Container(
        color: Colors.black26,
        alignment: Alignment.center,
        child: Text(
          '$_count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 120,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(blurRadius: 12, color: Colors.black)],
          ),
        ),
      );
    }
    final p = Progress.instance;
    final ms = p.missions;
    final stored = p.missionProgress;
    return Container(
      color: Colors.black45,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Panel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'PAUSED',
                        style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < 3; i++)
                        _MiniMission(text: ms[i].description, done: stored[i] >= ms[i].target),
                      const SizedBox(height: 16),
                      ChunkyButton(label: 'RESUME', icon: Icons.play_arrow_rounded, onPressed: _resume),
                      const SizedBox(height: 12),
                      ChunkyButton(
                        label: 'HOME',
                        icon: Icons.home_rounded,
                        color: const Color(0xFF2E86DE),
                        onPressed: widget.onHome,
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

class _MiniMission extends StatelessWidget {
  const _MiniMission({required this.text, required this.done});
  final String text;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(done ? Icons.check_circle_rounded : Icons.flag_outlined,
              color: done ? ethGreen : ethYellow, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                  color: done ? Colors.white54 : Colors.white,
                  fontSize: 13,
                  decoration: done ? TextDecoration.lineThrough : null,
                )),
          ),
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
  late final bool _adOffer;
  late final int _gemCost;
  late final bool _gemOffer;
  bool _busy = false;

  bool get _offer => _adOffer || _gemOffer;

  @override
  void initState() {
    super.initState();
    _adOffer = !widget.game.continuedThisRun && AdManager.instance.rewardedReady.value;
    _gemCost = Economy.reviveCost(widget.game.revives);
    _gemOffer = Progress.instance.gems >= _gemCost;
    _timer = AnimationController(
      vsync: this,
      duration: _offer ? const Duration(seconds: 6) : const Duration(milliseconds: 1100),
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
      await Progress.instance.addRevive();
      widget.game.continueRun(viaAd: true);
    } else {
      widget.game.endRun();
    }
  }

  Future<void> _useGems() async {
    _busy = true;
    _timer.stop();
    if (await Progress.instance.spendGems(_gemCost)) {
      AudioManager.instance.sfx(Sfx.gem);
      await Progress.instance.addRevive();
      widget.game.continueRun(viaAd: false);
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
                        '${(6 * (1 - _timer.value)).ceil()}',
                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (_gemOffer) ...[
              ChunkyButton(
                label: 'REVIVE FOR $_gemCost',
                icon: Icons.diamond_rounded,
                color: const Color(0xFF2F80ED),
                fontSize: 17,
                onPressed: _busy ? null : _useGems,
              ),
              const SizedBox(height: 10),
            ],
            if (_adOffer)
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
    required this.missionResult,
    required this.onDouble,
    required this.onPlayAgain,
    required this.onHome,
  });

  final AddisGame game;
  final bool newBest;
  final bool doubled;
  final MissionUpdate? missionResult;
  final VoidCallback onDouble;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final coins = game.stats.coins;
    final mr = missionResult;
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
                      const SizedBox(height: 8),
                      Text(
                        '${game.finalScore}',
                        style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'BEST  ${Progress.instance.bestScore}   ·   x${game.scoreMultiplier} multiplier',
                        style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CoinBadge(amount: doubled ? coins * 2 : coins, big: true),
                          if (game.stats.gems > 0) ...[
                            const SizedBox(width: 8),
                            GemBadge(amount: game.stats.gems, big: true),
                          ],
                        ],
                      ),
                      if (mr != null && (mr.newlyCompleted.isNotEmpty || mr.setCompleted)) ...[
                        const SizedBox(height: 12),
                        for (final m in mr.newlyCompleted)
                          _MiniMission(text: m.description, done: false),
                        if (mr.setCompleted)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Mission set complete! Multiplier is now x${Progress.instance.scoreMultiplier}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: ethGreen, fontWeight: FontWeight.w900),
                            ),
                          ),
                      ],
                      const SizedBox(height: 18),
                      if (coins > 0 && !doubled)
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
