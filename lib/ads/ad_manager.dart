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

  /// Flips to true once the SDK is initialized and ads may be requested.
  final ValueNotifier<bool> sdkReady = ValueNotifier(false);

  /// True when the user must be offered a way to change consent (GDPR).
  final ValueNotifier<bool> privacyOptionsRequired = ValueNotifier(false);

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  bool _loadingInterstitial = false;
  bool _loadingRewarded = false;
  final ValueNotifier<bool> rewardedReady = ValueNotifier(false);

  int _runsSinceInterstitial = 0;
  DateTime _lastFullScreenAd = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastRewarded = DateTime.fromMillisecondsSinceEpoch(0);

  /// Gathers consent (UMP) and then initializes the Mobile Ads SDK.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final consentDone = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((FormError? e) {
          if (e != null) debugPrint('Consent form error: ${e.message}');
          if (!consentDone.isCompleted) consentDone.complete();
        });
      },
      (FormError e) {
        debugPrint('Consent info error: ${e.message}');
        if (!consentDone.isCompleted) consentDone.complete();
      },
    );

    // Consent from a previous session may already allow ads; start early.
    if (await ConsentInformation.instance.canRequestAds()) {
      await _startSdk();
    }
    await consentDone.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {},
    );
    if (await ConsentInformation.instance.canRequestAds()) {
      await _startSdk();
    }
    privacyOptionsRequired.value =
        await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
            PrivacyOptionsRequirementStatus.required;
  }

  Future<void> _startSdk() async {
    if (_canRequestAds) return;
    _canRequestAds = true;
    await MobileAds.instance.initialize();
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
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          _interstitial = ad;
        },
        onAdFailedToLoad: (err) {
          _loadingInterstitial = false;
          debugPrint('Interstitial failed: ${err.message}');
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
        done.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _loadInterstitial();
        done.complete();
      },
    );
    _runsSinceInterstitial = 0;
    _lastFullScreenAd = now;
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
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingRewarded = false;
          _rewarded = ad;
          rewardedReady.value = true;
        },
        onAdFailedToLoad: (err) {
          _loadingRewarded = false;
          debugPrint('Rewarded failed: ${err.message}');
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
        done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _loadRewarded();
        done.complete(false);
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    return done.future;
  }
}
