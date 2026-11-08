import 'package:flutter/material.dart';

import '../audio/audio_manager.dart';
import '../game/textures.dart';
import '../meta/daily.dart';
import '../meta/economy.dart';
import '../progress.dart';
import 'widgets.dart';

const missionSkipGems = 3;

class MissionsScreen extends StatelessWidget {
  const MissionsScreen({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = Progress.instance;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final ms = p.missions;
        final prog = p.missionProgress;
        final maxed = p.scoreMultiplier >= Economy.maxScoreMultiplier;
        return MenuPage(
          title: 'MISSIONS',
          onClose: onClose,
          trailing: GemBadge(amount: p.gems),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [ethGreen, Color(0xFF0B6B2A)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Text(
                      'x${p.scoreMultiplier}',
                      style: const TextStyle(color: ethYellow, fontSize: 48, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        maxed
                            ? 'Maximum score multiplier reached!'
                            : 'Score multiplier. Complete all 3 missions to raise it to '
                                'x${p.scoreMultiplier + 1} and earn a gem.',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < 3; i++)
                _MissionCard(
                  description: ms[i].description,
                  value: prog[i],
                  target: ms[i].target,
                  perRun: ms[i].perRun,
                  canSkip: p.gems >= missionSkipGems,
                  onSkip: () async {
                    if (await p.skipMission(i, missionSkipGems)) {
                      AudioManager.instance.sfx(Sfx.mission);
                    }
                  },
                ),
              const SizedBox(height: 18),
              _DailyWordCard(progress: p),
            ],
          ),
        );
      },
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.description,
    required this.value,
    required this.target,
    required this.perRun,
    required this.canSkip,
    required this.onSkip,
  });

  final String description;
  final int value;
  final int target;
  final bool perRun;
  final bool canSkip;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final done = value >= target;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF14213D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: done ? ethGreen : Colors.white12, width: 2),
      ),
      child: Row(
        children: [
          Icon(done ? Icons.check_circle_rounded : Icons.flag_rounded,
              color: done ? ethGreen : ethYellow, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (value / target).clamp(0, 1),
                    minHeight: 8,
                    color: done ? ethGreen : ethYellow,
                    backgroundColor: Colors.white12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${value.clamp(0, target)} / $target${perRun ? '  (best run)' : ''}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          if (!done) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: canSkip ? onSkip : null,
              icon: const Icon(Icons.diamond_rounded, size: 16, color: Color(0xFF8FD3FF)),
              label: const Text('$missionSkipGems skip'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

class _DailyWordCard extends StatelessWidget {
  const _DailyWordCard({required this.progress});
  final Progress progress;

  @override
  Widget build(BuildContext context) {
    final word = progress.dailyWord;
    final got = progress.dailyWordCollected;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14213D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ethRed, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DAILY WORD',
              style: TextStyle(color: ethYellow, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 4),
          Text(
            'Collect the letter tiles on the track, in order. Reward: '
            '$dailyWordCoins coins + $dailyWordGems gems.',
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 10),
          DailyWordTiles(word: word, collected: got, size: 34),
          if (got >= word.length) ...[
            const SizedBox(height: 8),
            Text('Done! ${dailyWordMeanings[word] ?? ''}',
                style: const TextStyle(color: ethGreen, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

/// Letter tiles of the Daily Word with the collected ones highlighted.
class DailyWordTiles extends StatelessWidget {
  const DailyWordTiles({super.key, required this.word, required this.collected, this.size = 24});
  final String word;
  final int collected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: size * 0.15,
      children: [
        for (var i = 0; i < word.length; i++)
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: i < collected ? ethRed : Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(size * 0.22),
              border: Border.all(color: i < collected ? Colors.white : Colors.white30, width: 1.5),
            ),
            child: Text(
              word[i],
              style: TextStyle(
                color: i < collected ? Colors.white : Colors.white38,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.55,
              ),
            ),
          ),
      ],
    );
  }
}
