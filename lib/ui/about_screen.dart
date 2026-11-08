import 'package:flutter/material.dart';

import '../game/textures.dart';
import 'widgets.dart';

/// Shown in the About page and in the licence page.
const appVersion = '1.2.0';
const appDeveloper = 'Binyam Bayu';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return MenuPage(
      title: 'ABOUT',
      onClose: onClose,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const SizedBox(height: 8),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset('assets/icon.png', width: 112, height: 112),
            ),
          ),
          const SizedBox(height: 16),
          const Center(child: GameLogo(size: 34)),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Version $appVersion',
              style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 24),
          _Card(
            child: Column(
              children: [
                const Text(
                  'DEVELOPED BY',
                  style: TextStyle(
                    color: ethYellow,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  appDeveloper,
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final c in const [ethGreen, ethYellow, ethRed])
                      Container(width: 36, height: 5, color: c),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _Card(
            child: Text(
              'Run with Meaza, Tadesse and Yoseph across the rail lines of Addis Ababa. '
              'Dodge the trains, jump the barriers, outrun the street goat, collect coins, '
              'gems and Meskel daisies, and spell the Daily Word on the way.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          const _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Credit(icon: Icons.code_rounded, title: 'Game design & development', who: appDeveloper),
                _Credit(icon: Icons.people_alt_rounded, title: 'Characters', who: 'Meaza, Tadesse & Yoseph'),
                _Credit(icon: Icons.music_note_rounded, title: 'Music', who: 'Adaptive soundtrack for Addis Surfers'),
                _Credit(icon: Icons.font_download_rounded, title: 'Amharic font', who: 'Noto Sans Ethiopic (SIL Open Font License)'),
                _Credit(icon: Icons.build_rounded, title: 'Built with', who: 'Flutter & Flame'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'Addis Surfers',
                applicationVersion: '$appVersion · by $appDeveloper',
              ),
              icon: const Icon(Icons.description_outlined, color: Colors.white70),
              label: const Text('Open-source licences', style: TextStyle(color: Colors.white70)),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '© ${DateTime.now().year} $appDeveloper. All rights reserved.\nMade with love for Addis Ababa  ·  አዲስ አበባ',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF14213D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12, width: 1.5),
      ),
      child: child,
    );
  }
}

class _Credit extends StatelessWidget {
  const _Credit({required this.icon, required this.title, required this.who});
  final IconData icon;
  final String title;
  final String who;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: ethYellow, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                Text(who,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
