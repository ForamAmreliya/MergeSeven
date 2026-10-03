import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../../core/ads/ads_service.dart';

/// Shows the banner that [AdsService] keeps loaded (all loading happens there,
/// once, from `main`).
///
/// Takes no space until an ad is ready. It always keeps the bottom safe-area
/// padding, so it sits directly on top of the system navigation bar with only
/// a few pixels of space above it.
class BannerAdView extends StatelessWidget {
  const BannerAdView({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AdsService.supported) return const SizedBox(width: double.infinity);
    return SafeArea(
      top: false,
      child: ValueListenableBuilder<BannerAd?>(
        valueListenable: context.read<AdsService>().banner,
        // No size animation on purpose: a growing bar would re-lay-out and
        // repaint the whole game screen on every frame.
        builder: (context, ad, _) => ad == null
            ? const SizedBox(width: double.infinity)
            : Padding(
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
              ),
      ),
    );
  }
}
