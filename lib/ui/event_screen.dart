import 'package:flutter/material.dart';

import '../audio/audio_manager.dart';
import '../game/textures.dart';
import '../meta/event.dart';
import '../progress.dart';
import 'prize_view.dart';
import 'widgets.dart';

class EventScreen extends StatelessWidget {
  const EventScreen({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = Progress.instance;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final flowers = p.eventFlowers;
        final claimed = p.eventClaimed;
        final left = eventTimeLeft(DateTime.now());
        return MenuPage(
          title: 'WEEKLY EVENT',
          onClose: onClose,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFFC107), Color(0xFFF57F17)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_florist_rounded, color: Colors.white, size: 56),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('$eventName  ·  $eventNameAmharic',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          const Text(
                            'Pick the yellow Meskel daisies on the tracks to unlock rewards.',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Ends in ${left.inDays}d ${left.inHours % 24}h  ·  You have $flowers',
                            style: const TextStyle(color: Color(0xFF3E2723), fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < eventTiers.length; i++)
                _TierRow(
                  tier: eventTiers[i],
                  flowers: flowers,
                  claimed: claimed.contains(i),
                  onClaim: () async {
                    final text = await p.claimEventTier(i);
                    if (text != null && context.mounted) {
                      AudioManager.instance.sfx(Sfx.mission);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('You got: $text'), behavior: SnackBarBehavior.floating),
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

class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.tier,
    required this.flowers,
    required this.claimed,
    required this.onClaim,
  });

  final EventTier tier;
  final int flowers;
  final bool claimed;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final reached = flowers >= tier.flowers;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF14213D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: reached && !claimed ? ethYellow : Colors.white12, width: 2),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Column(
              children: [
                const Icon(Icons.local_florist_rounded, color: Color(0xFFFFD21F)),
                Text('${tier.flowers}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PrizeChip(prize: tier.prize, size: 26),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (flowers / tier.flowers).clamp(0, 1),
                    minHeight: 6,
                    color: const Color(0xFFFFC107),
                    backgroundColor: Colors.white12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (claimed)
            const Icon(Icons.check_circle_rounded, color: ethGreen, size: 32)
          else
            FilledButton(
              onPressed: reached ? onClaim : null,
              style: FilledButton.styleFrom(backgroundColor: ethGreen),
              child: const Text('CLAIM', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
        ],
      ),
    );
  }
}
