import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../../core/ads/ads_service.dart';
import '../../core/theme/app_colors.dart';

/// Shows the native ad that [AdsService] keeps loaded (all loading happens
/// there, once, from `main`). Takes no space until an ad is ready.
class NativeAdView extends StatelessWidget {
  /// Small template (about 100px tall) for screens with little room.
  final bool compact;

  const NativeAdView({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (!AdsService.supported) return const SizedBox(width: double.infinity);
    final p = context.palette;
    final ads = context.read<AdsService>();
    return ValueListenableBuilder<NativeAd?>(
      valueListenable: compact ? ads.nativeSmall : ads.nativeMedium,
      builder: (context, ad, _) => AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: ad == null
            ? const SizedBox(width: double.infinity)
            : Container(
                margin: EdgeInsets.only(top: compact ? 8 : 16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: p.cardBorder, width: 1.5),
                ),
                child: ConstrainedBox(
                  constraints: compact
                      ? const BoxConstraints(minHeight: 90, maxHeight: 130)
                      : const BoxConstraints(minHeight: 320, maxHeight: 400),
                  child: AdWidget(ad: ad),
                ),
              ),
      ),
    );
  }
}
