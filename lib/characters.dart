import 'package:flutter/painting.dart';

/// Playable characters, based on the Addis Surfers key art.
enum CharacterId { meaza, tadesse, yoseph }

class CharacterInfo {
  const CharacterInfo({
    required this.id,
    required this.name,
    required this.nameAmharic,
    required this.tagline,
    required this.portrait,
    required this.price,
    required this.accent,
  });

  final CharacterId id;
  final String name;
  final String nameAmharic;
  final String tagline;
  final String portrait;

  /// Coin price to unlock (0 = unlocked from the start).
  final int price;
  final Color accent;
}

const characters = <CharacterInfo>[
  CharacterInfo(
    id: CharacterId.meaza,
    name: 'Meaza',
    nameAmharic: 'መዓዛ',
    tagline: 'Lion-hearted, never slows down.',
    portrait: 'assets/images/meaza.jpg',
    price: 0,
    accent: Color(0xFF2E9E44),
  ),
  CharacterInfo(
    id: CharacterId.tadesse,
    name: 'Tadesse',
    nameAmharic: 'ታደሰ',
    tagline: 'Skater from Piassa. Smooth on every rail.',
    portrait: 'assets/images/tadesse.jpg',
    price: 750,
    accent: Color(0xFFF2B705),
  ),
  CharacterInfo(
    id: CharacterId.yoseph,
    name: 'Yoseph',
    nameAmharic: 'ዮሴፍ',
    tagline: 'Beats on, Bole to Merkato in record time.',
    portrait: 'assets/images/yoseph.jpg',
    price: 2000,
    accent: Color(0xFFE0442B),
  ),
];

CharacterInfo characterInfo(CharacterId id) =>
    characters.firstWhere((c) => c.id == id);
