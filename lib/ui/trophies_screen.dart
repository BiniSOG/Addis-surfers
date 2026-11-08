import 'package:flutter/material.dart';

import '../audio/audio_manager.dart';
import '../game/textures.dart';
import '../meta/achievements.dart';
import '../progress.dart';
import 'prize_view.dart';
import 'widgets.dart';

class TrophiesScreen extends StatelessWidget {
  const TrophiesScreen({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = Progress.instance;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final claimed = p.achievementsClaimed;
        final sorted = [...achievements]..sort((a, b) {
            int rank(Achievement x) =>
                p.achievementDone(x) && !claimed.contains(x.id) ? 0 : (claimed.contains(x.id) ? 2 : 1);
            return rank(a).compareTo(rank(b));
          });
        return MenuPage(
          title: 'TROPHIES',
          onClose: onClose,
          trailing: Text('${claimed.length}/${achievements.length}',
              style: const TextStyle(color: ethYellow, fontWeight: FontWeight.w900, fontSize: 18)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              for (final a in sorted)
                _TrophyTile(
                  achievement: a,
                  value: p.stat(a.stat),
                  claimed: claimed.contains(a.id),
                  onClaim: () async {
                    final text = await p.claimAchievement(a);
                    if (text != null && context.mounted) {
                      AudioManager.instance.sfx(Sfx.mission);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${a.title}: $text'), behavior: SnackBarBehavior.floating),
                      );
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TrophyTile extends StatelessWidget {
  const _TrophyTile({
    required this.achievement,
    required this.value,
    required this.claimed,
    required this.onClaim,
  });

  final Achievement achievement;
  final int value;
  final bool claimed;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final done = value >= achievement.target;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF14213D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: done && !claimed ? ethYellow : Colors.white12, width: 2),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_rounded,
              size: 40,
              color: claimed ? ethYellow : (done ? Colors.amberAccent : Colors.white24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(achievement.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                Text(achievement.description,
                    style: const TextStyle(color: Colors.white60, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (value / achievement.target).clamp(0, 1),
                          minHeight: 6,
                          color: ethYellow,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PrizeChip(prize: achievement.reward, size: 18),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (claimed)
            const Icon(Icons.check_circle_rounded, color: ethGreen, size: 30)
          else
            FilledButton(
              onPressed: done ? onClaim : null,
              style: FilledButton.styleFrom(backgroundColor: ethGreen),
              child: const Text('CLAIM', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
        ],
      ),
    );
  }
}
