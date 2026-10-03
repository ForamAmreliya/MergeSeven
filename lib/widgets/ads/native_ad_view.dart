import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../../core/ads/ads_service.dart';

/// Shows the native ad that [AdsService] keeps loaded (all loading happens
/// there, once, from `main`). Takes no space until an ad is ready, and then
/// fills the full width at the template's own size.
class NativeAdView extends StatelessWidget {
  const NativeAdView({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AdsService.supported) return const SizedBox(width: double.infinity);
    final ads = context.read<AdsService>();
    return ValueListenableBuilder<NativeAd?>(
      valueListenable: ads.nativeMedium,
      builder: (context, ad, _) => ad == null
          ? const SizedBox(width: double.infinity)
          // Full width: only top and bottom margins, nothing on the sides.
          : Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              width: double.infinity,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 320, maxHeight: 400),
                child: AdWidget(ad: ad),
              ),
            ),
    );
  }
}
