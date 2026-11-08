import 'daily.dart';
import 'rewards.dart';

/// Weekly "Meskel Daisy" event: collect adey abeba flowers on the track to
/// unlock reward tiers. Progress resets every Monday.
class EventTier {
  const EventTier(this.flowers, this.prize);
  final int flowers;
  final Prize prize;
}

const eventName = 'Meskel Daisies';
const eventNameAmharic = 'አደይ አበባ';

const eventTiers = [
  EventTier(25, Prize(PrizeKind.coins, 500)),
  EventTier(75, Prize(PrizeKind.mesob, 1)),
  EventTier(150, Prize(PrizeKind.gems, 2)),
  EventTier(250, Prize(PrizeKind.headStart, 2)),
  EventTier(400, Prize(PrizeKind.mesob, 2)),
  EventTier(600, Prize(PrizeKind.gems, 5)),
  EventTier(900, Prize(PrizeKind.character, 1)),
];

/// Week index, starting on Mondays (1970-01-01 was a Thursday).
int weekNumber(DateTime d) => (dayNumber(d) + 3) ~/ 7;

/// Time left in the current event week.
Duration eventTimeLeft(DateTime now) {
  final nextWeekDay = (weekNumber(now) + 1) * 7 - 3;
  final end = DateTime.fromMillisecondsSinceEpoch(nextWeekDay * 86400000, isUtc: true);
  final localEnd = DateTime(end.year, end.month, end.day);
  return localEnd.difference(now);
}
