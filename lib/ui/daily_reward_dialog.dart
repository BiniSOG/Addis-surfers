import 'package:flutter/material.dart';

import '../audio/audio_manager.dart';
import '../game/textures.dart';
import '../meta/daily.dart';
import '../progress.dart';
import 'widgets.dart';

/// Seven-day login calendar. Shown automatically when a reward is waiting.
Future<void> showDailyRewardDialog(BuildContext context) async {
  final idx = Progress.instance.claimableDailyIndex;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Panel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'DAILY REWARDS',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Come back every day. Miss a day and the streak restarts.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < dailyRewards.length; i++)
                  _DayTile(
                    day: i + 1,
                    reward: dailyRewards[i],
                    state: idx == null
                        ? (i < Progress.instance.dailyStreak ? _DayState.claimed : _DayState.locked)
                        : i < idx
                            ? _DayState.claimed
                            : (i == idx ? _DayState.today : _DayState.locked),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            ChunkyButton(
              label: idx == null ? 'COME BACK TOMORROW' : 'CLAIM',
              icon: idx == null ? Icons.schedule_rounded : Icons.card_giftcard_rounded,
              onPressed: idx == null
                  ? () => Navigator.pop(ctx)
                  : () async {
                      await Progress.instance.claimDaily();
                      AudioManager.instance.sfx(Sfx.mission);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
            ),
          ],
        ),
      ),
    ),
  );
}

enum _DayState { claimed, today, locked }

class _DayTile extends StatelessWidget {
  const _DayTile({required this.day, required this.reward, required this.state});
  final int day;
  final DailyReward reward;
  final _DayState state;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (reward.kind) {
      RewardKind.coins => (Icons.monetization_on_rounded, ethYellow),
      RewardKind.gems => (Icons.diamond_rounded, const Color(0xFF5EC8FF)),
      RewardKind.shield => (Icons.shield_rounded, const Color(0xFF26A69A)),
      RewardKind.headStart => (Icons.rocket_launch_rounded, const Color(0xFFF08A00)),
    };
    final big = day == 7;
    return Container(
      width: big ? 150 : 70,
      height: 86,
      decoration: BoxDecoration(
        color: switch (state) {
          _DayState.claimed => ethGreen.withValues(alpha: 0.35),
          _DayState.today => const Color(0xFF2E86DE),
          _DayState.locked => Colors.white10,
        },
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: state == _DayState.today ? ethYellow : Colors.white24,
          width: state == _DayState.today ? 3 : 1,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('DAY $day',
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Icon(icon, color: color, size: 26),
                Text(
                  reward.bonusGems > 0 ? '${reward.label} + ${reward.bonusGems}💎' : reward.label,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          if (state == _DayState.claimed)
            const Positioned(
              right: 4,
              top: 4,
              child: Icon(Icons.check_circle_rounded, color: ethGreen, size: 18),
            ),
        ],
      ),
    );
  }
}
