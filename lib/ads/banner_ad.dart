import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';
import 'ad_manager.dart';

/// An anchored adaptive banner ("small bar") that sizes itself to the screen
/// width. Renders nothing until an ad has loaded, so layouts never jump to a
/// blank box.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_requested) {
      _requested = true;
      _load();
    }
  }

  void _onSdkReady() {
    if (AdManager.instance.sdkReady.value && mounted && _ad == null) _load();
  }

  Future<void> _load() async {
    if (!AdManager.instance.canRequestAds) {
      AdManager.instance.sdkReady.addListener(_onSdkReady);
      return;
    }
    AdManager.instance.sdkReady.removeListener(_onSdkReady);
    final width = MediaQuery.sizeOf(context).width.truncate();
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (!mounted || size == null) return;
    final ad = BannerAd(
      adUnitId: AdConfig.banner,
      size: size,
      request: AdManager.instance.request,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          AdManager.log('banner loaded (${size.width}x${size.height})');
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          AdManager.log('banner failed ${err.code}: ${err.message}');
          ad.dispose();
          if (mounted) setState(() => _ad = null);
          // Try again a little later (no fill / flaky network).
          Future.delayed(const Duration(seconds: 30), () {
            if (mounted && _ad == null) _load();
          });
        },
      ),
    );
    setState(() => _ad = ad);
    await ad.load();
  }

  @override
  void dispose() {
    AdManager.instance.sdkReady.removeListener(_onSdkReady);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
