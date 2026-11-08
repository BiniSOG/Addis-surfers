import 'package:flutter/material.dart';

import '../ads/ad_manager.dart';
import '../audio/audio_manager.dart';
import '../audio/haptics.dart';
import '../game/textures.dart';
import '../progress.dart';
import '../settings.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = GameSettings.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => MenuPage(
        title: 'SETTINGS',
        onClose: onClose,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const _Header('Sound'),
            _SliderTile(
              icon: Icons.music_note_rounded,
              label: 'Music',
              value: s.musicVolume,
              onChanged: s.setMusicVolume,
            ),
            _SliderTile(
              icon: Icons.volume_up_rounded,
              label: 'Sound effects',
              value: s.sfxVolume,
              onChanged: s.setSfxVolume,
              onChangeEnd: (_) => AudioManager.instance.sfx(Sfx.coin),
            ),
            const _Header('Gameplay'),
            _SwitchTile(
              icon: Icons.vibration_rounded,
              label: 'Vibration',
              value: s.haptics,
              onChanged: (v) async {
                await s.setHaptics(v);
                if (v) Haptics.instance.play(Haptic.powerUp);
              },
            ),
            if (s.haptics)
              _SliderTile(
                icon: Icons.graphic_eq_rounded,
                label: 'Vibration strength',
                value: s.vibrationStrength,
                onChanged: s.setVibrationStrength,
                onChangeEnd: (_) => Haptics.instance.play(Haptic.land),
              ),
            _SwitchTile(
              icon: Icons.battery_saver_rounded,
              label: 'Battery saver graphics',
              subtitle: 'Less scenery for older phones',
              value: s.lowGraphics,
              onChanged: s.setLowGraphics,
            ),
            _ActionTile(
              icon: Icons.school_rounded,
              label: 'Show controls tutorial again',
              onTap: () async {
                await Progress.instance.resetTutorial();
                if (context.mounted) _snack(context, 'The tutorial will show on your next run');
              },
            ),
            const _Header('Privacy'),
            ValueListenableBuilder<bool>(
              valueListenable: AdManager.instance.privacyOptionsRequired,
              builder: (context, required, _) => required
                  ? _ActionTile(
                      icon: Icons.privacy_tip_rounded,
                      label: 'Ad privacy choices',
                      onTap: AdManager.instance.showPrivacyOptions,
                    )
                  : const _Info('Ads are shown by Google AdMob.'),
            ),
            const _Header('Danger zone'),
            _ActionTile(
              icon: Icons.restart_alt_rounded,
              label: 'Reset all progress',
              color: ethRed,
              onTap: () => _confirmReset(context),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'Addis Surfers 1.1\nOriginal music in Ethiopian qenet:\n"Tezeta" and "Merkato Run"',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset all progress?'),
        content: const Text(
          'Coins, gems, characters, upgrades, missions and best score will be deleted. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ethRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await Progress.instance.resetAll();
      if (context.mounted) _snack(context, 'Progress reset');
    }
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6, left: 4),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(color: ethYellow, fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
      );
}

class _Info extends StatelessWidget {
  const _Info(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(text, style: const TextStyle(color: Colors.white60)),
      );
}

BoxDecoration get _tileDeco => BoxDecoration(
      color: const Color(0xFF14213D),
      borderRadius: BorderRadius.circular(16),
    );

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
  });

  final IconData icon;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: _tileDeco,
      child: Row(
        children: [
          Icon(value <= 0.001 ? Icons.volume_off_rounded : icon, color: Colors.white),
          const SizedBox(width: 12),
          SizedBox(
            width: 104,
            child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Slider(
              value: value,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
              activeColor: ethGreen,
              inactiveColor: Colors.white24,
            ),
          ),
          SizedBox(
            width: 38,
            child: Text('${(value * 100).round()}',
                textAlign: TextAlign.end, style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: _tileDeco,
      child: SwitchListTile(
        secondary: Icon(icon, color: Colors.white),
        title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        value: value,
        activeThumbColor: ethGreen,
        onChanged: (v) {
          AudioManager.instance.sfx(Sfx.click);
          onChanged(v);
        },
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: _tileDeco,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
        onTap: () {
          AudioManager.instance.sfx(Sfx.click);
          onTap();
        },
      ),
    );
  }
}
