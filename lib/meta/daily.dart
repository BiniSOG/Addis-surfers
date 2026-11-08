/// Daily login rewards and the Daily Word.
library;

enum RewardKind { coins, gems, shield, headStart }

class DailyReward {
  const DailyReward(this.kind, this.amount, [this.bonusGems = 0]);
  final RewardKind kind;
  final int amount;
  final int bonusGems;

  String get label => switch (kind) {
        RewardKind.coins => '$amount',
        RewardKind.gems => '$amount',
        RewardKind.shield => '$amount',
        RewardKind.headStart => '$amount',
      };
}

/// Seven-day streak calendar. Missing a day restarts at day 1.
const dailyRewards = [
  DailyReward(RewardKind.coins, 200),
  DailyReward(RewardKind.shield, 1),
  DailyReward(RewardKind.coins, 400),
  DailyReward(RewardKind.headStart, 1),
  DailyReward(RewardKind.coins, 700),
  DailyReward(RewardKind.gems, 2),
  DailyReward(RewardKind.coins, 1200, 1),
];

/// Words of Addis and Ethiopian culture, spelled in Latin letters so that
/// letter tiles are easy to read while running.
const dailyWords = [
  'BUNNA', // coffee
  'INJERA',
  'MESKEL',
  'TIMKAT',
  'KITFO',
  'SHIRO',
  'GENNA',
  'HARAR',
  'AXUM',
  'GONDAR',
  'ENTOTO',
  'BERBERE',
  'KOLO',
  'TEFF',
  'DORO',
  'MERKATO',
  'PIASSA',
  'ESKISTA',
  'KRAR',
  'WASHINT',
];

const dailyWordMeanings = {
  'BUNNA': 'Coffee - Ethiopia gave it to the world',
  'INJERA': 'The spongy teff flatbread at every meal',
  'MESKEL': 'Finding of the True Cross festival',
  'TIMKAT': 'Ethiopian Epiphany celebration',
  'KITFO': 'Minced beef with mitmita and butter',
  'SHIRO': 'Spiced chickpea stew',
  'GENNA': 'Ethiopian Christmas (and a hockey-like game)',
  'HARAR': 'Walled city of the east',
  'AXUM': 'Ancient kingdom of the obelisks',
  'GONDAR': 'City of castles',
  'ENTOTO': 'The hills above Addis Ababa',
  'BERBERE': 'The famous red spice blend',
  'KOLO': 'Roasted barley snack',
  'TEFF': 'Tiny grain used for injera',
  'DORO': 'Chicken - as in doro wat',
  'MERKATO': 'One of Africa\'s biggest open-air markets',
  'PIASSA': 'Historic heart of Addis',
  'ESKISTA': 'Shoulder dance of the Amhara',
  'KRAR': 'Five or six string lyre',
  'WASHINT': 'Bamboo flute of the highlands',
};

const dailyWordCoins = 1500;
const dailyWordGems = 2;

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int dayNumber(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

String wordForDate(DateTime d) => dailyWords[(dayNumber(d) * 7) % dailyWords.length];
