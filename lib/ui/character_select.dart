import 'package:flutter/material.dart';

import '../characters.dart';
import '../progress.dart';
import 'widgets.dart';

class CharacterSelect extends StatefulWidget {
  const CharacterSelect({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<CharacterSelect> createState() => _CharacterSelectState();
}

class _CharacterSelectState extends State<CharacterSelect> {
  late final PageController _pc;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = characters.indexWhere((c) => c.id == Progress.instance.selected);
    _pc = PageController(initialPage: _page, viewportFraction: 0.78);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Progress.instance,
      builder: (context, _) {
        final progress = Progress.instance;
        return Container(
          color: const Color(0xE60B132B),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 32),
                      ),
                      const Text(
                        'CREW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      CoinBadge(amount: progress.coins),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pc,
                    itemCount: characters.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) => _card(characters[i], i == _page, progress),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _card(CharacterInfo c, bool focused, Progress progress) {
    final owned = progress.unlocked.contains(c.id);
    final selected = progress.selected == c.id;
    return AnimatedScale(
      duration: const Duration(milliseconds: 200),
      scale: focused ? 1 : 0.9,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: c.accent,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: const [BoxShadow(blurRadius: 16, color: Colors.black54)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(c.portrait, fit: BoxFit.cover, alignment: Alignment.topCenter),
                  if (!owned)
                    Container(
                      color: Colors.black45,
                      child: const Icon(Icons.lock_rounded, color: Colors.white, size: 64),
                    ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: const Color(0xFF14213D),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Text(
                    '${c.name.toUpperCase()}  ·  ${c.nameAmharic}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.tagline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  if (selected)
                    const ChunkyButton(label: 'SELECTED', onPressed: null, icon: Icons.check_rounded)
                  else if (owned)
                    ChunkyButton(
                      label: 'SELECT',
                      onPressed: () => progress.select(c.id),
                    )
                  else
                    ChunkyButton(
                      label: 'UNLOCK  ${c.price}',
                      icon: Icons.monetization_on_rounded,
                      color: const Color(0xFFF08A00),
                      onPressed: progress.coins >= c.price
                          ? () => progress.unlock(c.id)
                          : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
