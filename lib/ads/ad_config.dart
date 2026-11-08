import 'dart:io' show Platform;

/// AdMob ad unit configuration.
///
/// By default every unit is one of Google's public TEST ids, so you can
/// develop safely without risking your AdMob account. For store builds pass
/// your real ids with --dart-define (see README.md), e.g.
///
///   flutter build appbundle --release \
///     --dart-define=ADMOB_ANDROID_BANNER=ca-app-pub-XXXX/YYYY ...
class AdConfig {
  const AdConfig._();

  // ---- Android -------------------------------------------------------------
  static const _androidBanner = String.fromEnvironment(
    'ADMOB_ANDROID_BANNER',
    defaultValue: 'ca-app-pub-3940256099942544/9214589741',
  );
  static const _androidInterstitial = String.fromEnvironment(
    'ADMOB_ANDROID_INTERSTITIAL',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );
  static const _androidRewarded = String.fromEnvironment(
    'ADMOB_ANDROID_REWARDED',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );

  // ---- iOS -----------------------------------------------------------------
  static const _iosBanner = String.fromEnvironment(
    'ADMOB_IOS_BANNER',
    defaultValue: 'ca-app-pub-3940256099942544/2435281174',
  );
  static const _iosInterstitial = String.fromEnvironment(
    'ADMOB_IOS_INTERSTITIAL',
    defaultValue: 'ca-app-pub-3940256099942544/4411468910',
  );
  static const _iosRewarded = String.fromEnvironment(
    'ADMOB_IOS_REWARDED',
    defaultValue: 'ca-app-pub-3940256099942544/1712485313',
  );

  static String get banner => Platform.isIOS ? _iosBanner : _androidBanner;
  static String get interstitial =>
      Platform.isIOS ? _iosInterstitial : _androidInterstitial;
  static String get rewarded => Platform.isIOS ? _iosRewarded : _androidRewarded;

  static bool get usingTestIds =>
      banner.startsWith('ca-app-pub-3940256099942544');

  // ---- Placement rules -----------------------------------------------------
  // These are the "systematic" rules that decide when ads appear. They are
  // tuned to keep retention high: no ads during a run, banners only on
  // menu-style screens, full-screen ads only between runs and rate-limited.

  /// Show a banner during gameplay too. Off by default: swipes near the
  /// bottom of the screen cause accidental clicks, which AdMob penalises.
  static const bannerDuringGameplay = false;

  /// Brand-new players get this many runs with no interstitials at all.
  static const interstitialGraceRuns = 2;

  /// Show an interstitial at most once every N finished runs...
  static const interstitialEveryNRuns = 3;

  /// ...and never more often than this.
  static const interstitialMinInterval = Duration(seconds: 150);

  /// Don't follow a rewarded ad with an interstitial too quickly.
  static const afterRewardedCooldown = Duration(seconds: 60);

  /// Coins granted for watching a rewarded ad from the menu.
  static const rewardedCoinAmount = 150;
}
