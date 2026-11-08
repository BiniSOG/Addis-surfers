import 'package:flutter/material.dart';

import '../ads/ad_config.dart';
import '../ads/ad_manager.dart';
import '../audio/audio_manager.dart';
import '../game/entities.dart';
import '../game/textures.dart';
import '../meta/economy.dart';
import '../meta/rewards.dart';
import '../progress.dart';
import 'mesob_dialog.dart';
import 'widgets.dart';

/// The marketplace: power-up upgrades, consumable boosts and currency.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _tab = 0;

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _buy(Future<bool> Function() purchase, String what) async {
    final ok = await purchase();
    if (ok) {
      AudioManager.instance.sfx(Sfx.purchase);
      _toast('$what purchased!');
    } else {
      _toast('Not enough coins');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Progress.instance;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) => MenuPage(
        title: 'SHOP',
        onClose: widget.onClose,
        trailing: Row(
          children: [
            CoinBadge(amount: p.coins),
            const SizedBox(width: 6),
            GemBadge(amount: p.gems),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Upgrades'), icon: Icon(Icons.upgrade_rounded)),
                  ButtonSegment(value: 1, label: Text('Boosts'), icon: Icon(Icons.bolt_rounded)),
                  ButtonSegment(value: 2, label: Text('Bank'), icon: Icon(Icons.account_balance_rounded)),
                ],
                selected: {_tab},
                showSelectedIcon: false,
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (s) => s.contains(WidgetState.selected) ? Colors.black : Colors.white,
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (s) => s.contains(WidgetState.selected) ? ethYellow : Colors.white10,
                  ),
                ),
                onSelectionChanged: (s) {
                  AudioManager.instance.sfx(Sfx.click);
                  setState(() => _tab = s.first);
                },
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: switch (_tab) {
                  0 => _upgrades(p),
                  1 => _boosts(p),
                  _ => _bank(p),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _upgrades(Progress p) => [
        const _Hint('Upgrades make power-ups last longer on every run.'),
        for (final k in Economy.upgradable) _UpgradeTile(kind: k, progress: p, onBuy: () {
          _buy(() => p.buyUpgrade(k), powerName(k));
        }),
      ];

  List<Widget> _boosts(Progress p) => [
        const _Hint('Boosts are used during a run from the buttons on the right.'),
        _ItemTile(
          icon: Icons.shopping_basket_rounded,
          color: const Color(0xFFE57373),
          title: 'Mesob Surprise',
          subtitle: 'A woven basket full of surprises: coins, gems, boosts, '
              'or even a new crew member!',
          owned: p.mesobs,
          price: mesobPrice,
          canAfford: p.coins >= mesobPrice,
          onBuy: () => _buy(p.buyMesob, 'Mesob Surprise'),
        ),
        if (p.mesobs > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ChunkyButton(
              label: 'OPEN A MESOB (${p.mesobs})',
              icon: Icons.card_giftcard_rounded,
              color: const Color(0xFFE57373),
              onPressed: () => openMesobDialog(context),
            ),
          ),
        _ItemTile(
          icon: Icons.shield_rounded,
          color: const Color(0xFF00897B),
          title: 'Gasha Shield',
          subtitle: 'Absorbs one crash. Lasts 30 s. Tap the shield button or double-tap the screen.',
          owned: p.shields,
          price: Economy.shieldPrice,
          canAfford: p.coins >= Economy.shieldPrice,
          onBuy: () => _buy(() async {
            if (!await p.spendCoins(Economy.shieldPrice)) return false;
            await p.addShields(1);
            return true;
          }, 'Shield'),
        ),
        _ItemTile(
          icon: Icons.rocket_launch_rounded,
          color: const Color(0xFFF08A00),
          title: 'Head Start',
          subtitle: 'Blast off with a jetpack at the start of a run and skip ahead.',
          owned: p.headStarts,
          price: Economy.headStartPrice,
          canAfford: p.coins >= Economy.headStartPrice,
          onBuy: () => _buy(() async {
            if (!await p.spendCoins(Economy.headStartPrice)) return false;
            await p.addHeadStarts(1);
            return true;
          }, 'Head Start'),
        ),
      ];

  List<Widget> _bank(Progress p) => [
        const _Hint('Gems revive you after a crash. Find them on the track, in daily rewards and missions.'),
        _ItemTile(
          icon: Icons.currency_exchange_rounded,
          color: const Color(0xFF2F80ED),
          title: '${Economy.gemsForCoinsGems} gems → ${Economy.gemsForCoinsCoins} coins',
          subtitle: 'Exchange gems for coins.',
          owned: null,
          priceLabel: '${Economy.gemsForCoinsGems}',
          priceIcon: Icons.diamond_rounded,
          canAfford: p.gems >= Economy.gemsForCoinsGems,
          onBuy: () async {
            if (await p.spendGems(Economy.gemsForCoinsGems)) {
              await p.addCoins(Economy.gemsForCoinsCoins);
              AudioManager.instance.sfx(Sfx.purchase);
              _toast('+${Economy.gemsForCoinsCoins} coins');
            } else {
              _toast('Not enough gems');
            }
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: AdManager.instance.rewardedReady,
          builder: (context, ready, _) => _ItemTile(
            icon: Icons.ondemand_video_rounded,
            color: const Color(0xFFF08A00),
            title: 'Free coins',
            subtitle: 'Watch a short video for +${AdConfig.rewardedCoinAmount} coins.',
            owned: null,
            priceLabel: 'FREE',
            canAfford: ready,
            onBuy: () async {
              if (await AdManager.instance.showRewarded()) {
                await p.addCoins(AdConfig.rewardedCoinAmount);
                AudioManager.instance.sfx(Sfx.purchase);
                _toast('+${AdConfig.rewardedCoinAmount} coins');
              }
            },
          ),
        ),
      ];
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: const TextStyle(color: Colors.white60, fontSize: 13)),
      );
}

IconData powerIcon(PowerKind k) => switch (k) {
      PowerKind.magnet => Icons.attractions_rounded,
      PowerKind.multiplier => Icons.looks_two_rounded,
      PowerKind.sneakers => Icons.directions_run_rounded,
      PowerKind.jetpack => Icons.rocket_launch_rounded,
      PowerKind.shield => Icons.shield_rounded,
    };

Color powerColor(PowerKind k) => switch (k) {
      PowerKind.magnet => const Color(0xFFE53935),
      PowerKind.multiplier => const Color(0xFF8E24AA),
      PowerKind.sneakers => ethGreen,
      PowerKind.jetpack => const Color(0xFFF08A00),
      PowerKind.shield => const Color(0xFF00897B),
    };

class _UpgradeTile extends StatelessWidget {
  const _UpgradeTile({required this.kind, required this.progress, required this.onBuy});
  final PowerKind kind;
  final Progress progress;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final lvl = progress.upgradeLevel(kind);
    final maxed = lvl >= Economy.maxUpgradeLevel;
    final now = Economy.duration(kind, lvl);
    final next = maxed ? now : Economy.duration(kind, lvl + 1);
    final price = maxed ? 0 : Economy.upgradeCosts[lvl];
    return _Card(
      icon: powerIcon(kind),
      color: powerColor(kind),
      title: powerName(kind),
      subtitleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            maxed ? '${now.toStringAsFixed(1)} s · MAX' : '${now.toStringAsFixed(1)} s → ${next.toStringAsFixed(1)} s',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < Economy.maxUpgradeLevel; i++)
                Container(
                  width: 22,
                  height: 8,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: i < lvl ? powerColor(kind) : Colors.white12,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ),
      action: maxed
          ? const Text('MAX', style: TextStyle(color: ethYellow, fontWeight: FontWeight.w900))
          : _PriceButton(label: '$price', enabled: progress.coins >= price, onTap: onBuy),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.owned,
    required this.canAfford,
    required this.onBuy,
    this.price,
    this.priceLabel,
    this.priceIcon = Icons.monetization_on_rounded,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final int? owned;
  final int? price;
  final String? priceLabel;
  final IconData priceIcon;
  final bool canAfford;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return _Card(
      icon: icon,
      color: color,
      title: owned == null ? title : '$title  ×$owned',
      subtitleWidget: Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      action: _PriceButton(
        label: priceLabel ?? '$price',
        icon: priceLabel == 'FREE' ? null : priceIcon,
        enabled: canAfford,
        onTap: onBuy,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitleWidget,
    required this.action,
  });

  final IconData icon;
  final Color color;
  final String title;
  final Widget subtitleWidget;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF14213D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 3),
                subtitleWidget,
              ],
            ),
          ),
          const SizedBox(width: 8),
          action,
        ],
      ),
    );
  }
}

class _PriceButton extends StatelessWidget {
  const _PriceButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.icon = Icons.monetization_on_rounded,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? ethGreen : Colors.grey.shade700,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 18,
                    color: icon == Icons.diamond_rounded ? const Color(0xFF8FD3FF) : ethYellow),
                const SizedBox(width: 4),
              ],
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}
