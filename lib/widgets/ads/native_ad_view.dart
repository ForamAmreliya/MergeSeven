import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../../core/ads/ad_ids.dart';
import '../../core/ads/ads_service.dart';
import '../../core/theme/app_colors.dart';

/// Native ad drawn with Google's medium template, styled to the app theme.
/// Takes no space until the ad has loaded.
class NativeAdView extends StatefulWidget {
  const NativeAdView({super.key});

  @override
  State<NativeAdView> createState() => _NativeAdViewState();
}

class _NativeAdViewState extends State<NativeAdView> {
  NativeAd? _ad;
  bool _loaded = false;
  Brightness? _brightness;
  Timer? _retry;
  AdsService? _ads;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!AdsService.supported) return;
    _ads ??= context.read<AdsService>()..ready.addListener(_load);
    final brightness = Theme.of(context).brightness;
    if (brightness != _brightness) {
      _brightness = brightness;
      _load();
    }
  }

  void _load() {
    final ads = _ads;
    if (!mounted || ads == null || !ads.ready.value) return;
    _retry?.cancel();
    final p = context.palette;
    final previous = _ad;
    final ad = NativeAd(
      adUnitId: AdIds.native,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: p.card,
        cornerRadius: 16,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: p.accent,
          style: NativeTemplateFontStyle.bold,
          size: 16,
        ),
        primaryTextStyle: NativeTemplateTextStyle(textColor: p.textPrimary, style: NativeTemplateFontStyle.bold),
        secondaryTextStyle: NativeTemplateTextStyle(textColor: p.textMuted),
        tertiaryTextStyle: NativeTemplateTextStyle(textColor: p.textMuted),
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted || ad != _ad) {
            ad.dispose();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Native ad failed to load: ${error.message}');
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
      _ad = ad;
      _loaded = false;
    });
    previous?.dispose();
    ad.load();
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
    final p = context.palette;
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: ad != null && _loaded
          ? Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: p.cardBorder, width: 1.5),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 320, maxHeight: 400),
                child: AdWidget(ad: ad),
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}
