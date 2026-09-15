import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../../core/ads/ad_ids.dart';
import '../../core/ads/ads_service.dart';

/// Full-width anchored adaptive banner for the bottom of a screen.
///
/// Takes no space until an ad has loaded. It always keeps the bottom
/// safe-area padding, so it sits directly on top of the system navigation bar
/// with only a few pixels of space above it.
class BannerAdView extends StatefulWidget {
  const BannerAdView({super.key});

  @override
  State<BannerAdView> createState() => _BannerAdViewState();
}

class _BannerAdViewState extends State<BannerAdView> {
  BannerAd? _ad;
  bool _loaded = false;
  int? _width;
  Timer? _retry;
  AdsService? _ads;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!AdsService.supported) return;
    _ads ??= context.read<AdsService>()..ready.addListener(_load);
    final width = MediaQuery.sizeOf(context).width.truncate();
    if (width != _width) {
      _width = width;
      _load();
    }
  }

  Future<void> _load() async {
    final ads = _ads;
    final width = _width;
    if (!mounted || ads == null || !ads.ready.value || width == null) return;
    _retry?.cancel();
    // Standard anchored adaptive height (about 50-60 dp on phones), so the
    // ad fills its slot without empty space around it.
    // ignore: deprecated_member_use
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (!mounted || size == null) return;

    final previous = _ad;
    final banner = BannerAd(
      adUnitId: AdIds.banner,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted || ad != _ad) {
            ad.dispose();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner failed to load: ${error.message}');
          ad.dispose();
          if (!mounted || ad != _ad) return;
          setState(() {
            _ad = null;
            _loaded = false;
          });
          _retry = Timer(const Duration(seconds: 45), _load);
        },
      ),
    );
    setState(() {
      _ad = banner;
      _loaded = false;
    });
    previous?.dispose();
    await banner.load();
  }

  @override
  void dispose() {
    _retry?.cancel();
    _ads?.ready.removeListener(_load);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    return SafeArea(
      top: false,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: Alignment.bottomCenter,
        child: ad != null && _loaded
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SizedBox(
                  width: double.infinity,
                  height: ad.size.height.toDouble(),
                  child: Center(
                    child: SizedBox(
                      width: ad.size.width.toDouble(),
                      height: ad.size.height.toDouble(),
                      child: AdWidget(ad: ad),
                    ),
                  ),
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
    );
  }
}
