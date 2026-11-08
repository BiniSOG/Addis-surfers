import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

/// Central place for consent, initialization and full-screen ads.
///
/// Banner ads are handled by [AdBanner] (see banner_ad.dart).
class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  bool _initialized = false;
  bool _canRequestAds = false;
  bool get canRequestAds => _canRequestAds;

  /// Serve non-personalised ads (used when consent could not be gathered).
  bool _nonPersonalized = false;

  /// The request every ad in the app uses.
  AdRequest get request => AdRequest(nonPersonalizedAds: _nonPersonalized);

  static void log(String m) => debugPrint('AddisAds: $m');

  /// Flips to true once the SDK is initialized and ads may be requested.
  final ValueNotifier<bool> sdkReady = ValueNotifier(false);

  /// True when the user must be offered a way to change consent (GDPR).
  final ValueNotifier<bool> privacyOptionsRequired = ValueNotifier(false);

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  bool _loadingInterstitial = false;
  bool _loadingRewarded = false;
  final ValueNotifier<bool> rewardedReady = ValueNotifier(false);

  /// Called with true when a full-screen ad opens and false when it closes.
  void Function(bool showing)? onFullScreenChange;

  int _runsSinceInterstitial = 0;
  DateTime _lastFullScreenAd = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastRewarded = DateTime.fromMillisecondsSinceEpoch(0);

  /// Gathers consent (UMP) and then initializes the Mobile Ads SDK.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    var consentFailed = false;
    final consentDone = Completer<void>();
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          log('consent info updated: ${await ConsentInformation.instance.getConsentStatus()}');
          await ConsentForm.loadAndShowConsentFormIfRequired((FormError? e) {
            if (e != null) log('consent form error ${e.errorCode}: ${e.message}');
            if (!consentDone.isCompleted) consentDone.complete();
          });
        },
        (FormError e) {
          // Typical with test ids or before a privacy message is published in
          // AdMob ("Privacy & messaging").
          log('consent info error ${e.errorCode}: ${e.message}');
          consentFailed = true;
          if (!consentDone.isCompleted) consentDone.complete();
        },
      );
    } catch (e) {
      log('consent request threw: $e');
      consentFailed = true;
      if (!consentDone.isCompleted) consentDone.complete();
    }

    // Consent from a previous session may already allow ads; start early.
    if (await _safeCanRequestAds()) {
      await _startSdk();
    }
    var timedOut = false;
    await consentDone.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => timedOut = true,
    );
    if (await _safeCanRequestAds()) {
      await _startSdk();
    } else if (consentFailed || timedOut) {
      // Never leave the game without ads because the consent service could
      // not be reached: fall back to non-personalised ads, which do not rely
      // on personal data.
      log('consent unavailable (failed=$consentFailed, timedOut=$timedOut): '
          'serving non-personalised ads');
      _nonPersonalized = true;
      await _startSdk();
    } else {
      log('ads not allowed yet (waiting for the user\'s consent choice)');
    }
    try {
      privacyOptionsRequired.value =
          await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
              PrivacyOptionsRequirementStatus.required;
    } catch (_) {}
  }

  Future<bool> _safeCanRequestAds() async {
    try {
      return await ConsentInformation.instance.canRequestAds();
    } catch (e) {
      log('canRequestAds threw: $e');
      return false;
    }
  }

  Future<void> _startSdk() async {
    if (_canRequestAds) return;
    _canRequestAds = true;
    final status = await MobileAds.instance.initialize();
    log('SDK started (non-personalised: $_nonPersonalized, adapters: '
        '${status.adapterStatuses.map((k, v) => MapEntry(k, v.state.name))})');
    sdkReady.value = true;
    if (kDebugMode && !AdConfig.usingTestIds) {
      debugPrint('WARNING: real ad unit ids in a debug build. '
          'Register your device as a test device to avoid policy issues.');
    }
    _loadInterstitial();
    _loadRewarded();
  }

  Future<void> showPrivacyOptions() async {
    await ConsentForm.showPrivacyOptionsForm((e) {
      if (e != null) debugPrint('Privacy options error: ${e.message}');
    });
  }

  // ---------------------------------------------------------------------------
  // Interstitial

  void _loadInterstitial() {
    if (!_canRequestAds || _interstitial != null || _loadingInterstitial) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: AdConfig.interstitial,
      request: request,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          _interstitial = ad;
          log('interstitial loaded');
        },
        onAdFailedToLoad: (err) {
          _loadingInterstitial = false;
          log('interstitial failed ${err.code}: ${err.message}');
          Future.delayed(const Duration(seconds: 30), _loadInterstitial);
        },
      ),
    );
  }

  /// Call once at the end of every run. Applies the placement rules from
  /// [AdConfig] and shows an interstitial only when they all pass.
  /// Completes when the ad is dismissed (or immediately if none is shown).
  Future<void> onRunFinished({required int totalRuns}) async {
    _runsSinceInterstitial++;
    final now = DateTime.now();
    final eligible = totalRuns > AdConfig.interstitialGraceRuns &&
        _runsSinceInterstitial >= AdConfig.interstitialEveryNRuns &&
        now.difference(_lastFullScreenAd) >= AdConfig.interstitialMinInterval &&
        now.difference(_lastRewarded) >= AdConfig.afterRewardedCooldown;
    final ad = _interstitial;
    if (!eligible || ad == null) {
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    final done = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial();
        onFullScreenChange?.call(false);
        done.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _loadInterstitial();
        onFullScreenChange?.call(false);
        done.complete();
      },
    );
    _runsSinceInterstitial = 0;
    _lastFullScreenAd = now;
    onFullScreenChange?.call(true);
    await ad.show();
    return done.future;
  }

  // ---------------------------------------------------------------------------
  // Rewarded

  void _loadRewarded() {
    if (!_canRequestAds || _rewarded != null || _loadingRewarded) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: AdConfig.rewarded,
      request: request,
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingRewarded = false;
          _rewarded = ad;
          rewardedReady.value = true;
          log('rewarded loaded');
        },
        onAdFailedToLoad: (err) {
          _loadingRewarded = false;
          log('rewarded failed ${err.code}: ${err.message}');
          Future.delayed(const Duration(seconds: 30), _loadRewarded);
        },
      ),
    );
  }

  /// Shows a rewarded ad. Completes with true if the user earned the reward.
  Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      return false;
    }
    _rewarded = null;
    rewardedReady.value = false;
    var earned = false;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _lastRewarded = DateTime.now();
        _lastFullScreenAd = _lastRewarded;
        _loadRewarded();
        onFullScreenChange?.call(false);
        done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _loadRewarded();
        onFullScreenChange?.call(false);
        done.complete(false);
      },
    );
    onFullScreenChange?.call(true);
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    return done.future;
  }
}
