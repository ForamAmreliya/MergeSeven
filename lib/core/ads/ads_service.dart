import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_cover.dart';
import 'ad_ids.dart';

/// All advertising in one place: consent, SDK start-up, preloading the
/// rewarded interstitial, and the [rewardGate] the screens use before a
/// booster or Continue.
///
/// Ads only run on Android and iOS; elsewhere the gate simply continues.
class AdsService {
  static bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// True once consent is resolved and the Mobile Ads SDK is initialised.
  final ValueNotifier<bool> ready = ValueNotifier(false);

  /// Whether "Privacy choices" must be offered in Settings (EEA / UK).
  final ValueNotifier<bool> privacyOptionsRequired = ValueNotifier(false);

  bool _started = false;
  bool _gateOpen = false;

  RewardedInterstitialAd? _rewarded;
  bool _rewardedLoading = false;

  // ------------------------------------------------------------- start-up
  /// Gathers consent (Google UMP) if needed, then starts the SDK and preloads
  /// the video ad. Call once after the first frame.
  Future<void> init() async {
    if (!supported || _started) return;
    _started = true;
    try {
      final done = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          await ConsentForm.loadAndShowConsentFormIfRequired((error) {
            if (error != null) debugPrint('Consent form: ${error.message}');
          });
          if (!done.isCompleted) done.complete();
        },
        (error) {
          debugPrint('Consent info update failed: ${error.message}');
          if (!done.isCompleted) done.complete();
        },
      );
      await done.future;
      await _refreshPrivacyStatus();
      await _startSdkIfAllowed();
    } catch (e) {
      debugPrint('Ads init failed: $e');
    }
  }

  /// Opens Google's privacy options form so the user can change consent.
  Future<void> showPrivacyOptions() async {
    if (!supported) return;
    await ConsentForm.showPrivacyOptionsForm((error) {
      if (error != null) debugPrint('Privacy options: ${error.message}');
    });
    await _refreshPrivacyStatus();
    await _startSdkIfAllowed();
  }

  Future<void> _refreshPrivacyStatus() async {
    privacyOptionsRequired.value =
        await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
  }

  Future<void> _startSdkIfAllowed() async {
    if (ready.value || !await ConsentInformation.instance.canRequestAds()) return;
    await MobileAds.instance.initialize();
    ready.value = true;
    _loadRewarded();
  }

  // ------------------------------------------------------------- loading
  void _loadRewarded() {
    if (!ready.value || _rewarded != null || _rewardedLoading) return;
    _rewardedLoading = true;
    RewardedInterstitialAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedLoading = false;
          _rewarded = ad;
        },
        onAdFailedToLoad: (error) {
          _rewardedLoading = false;
          debugPrint('Rewarded ad failed to load: ${error.message}');
          Future<void>.delayed(const Duration(seconds: 20), _loadRewarded);
        },
      ),
    );
  }

  /// Polls until [isLoaded] or the timeout passes (ads load asynchronously).
  Future<bool> _waitFor(bool Function() isLoaded, Duration timeout) async {
    final end = DateTime.now().add(timeout);
    while (!isLoaded() && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    return isLoaded();
  }

  // ------------------------------------------------------------- gate
  /// Shows the video ad before an action (the player already chose "Watch Ad").
  /// Returns true when the action may run: the video was watched to the end,
  /// or no video could be loaded. Returns false only if the player closed the
  /// video early.
  Future<bool> rewardGate(BuildContext context) async {
    if (!supported || (!ready.value && _rewarded == null)) return true;
    if (_gateOpen) return false;
    _gateOpen = true;
    final cover = AdCover.show(context, message: 'Loading video…');
    try {
      _loadRewarded();
      final hasVideo = await _waitFor(
        () => _rewarded != null,
        ready.value ? const Duration(seconds: 6) : Duration.zero,
      );
      if (!hasVideo) return true; // nothing to show: don't block the player
      final ad = _rewarded!;
      _rewarded = null;
      var earned = false;
      final closed = Completer<void>();
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (_) => cover.hide(),
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          if (!closed.isCompleted) closed.complete();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('Rewarded ad failed to show: ${error.message}');
          ad.dispose();
          earned = true; // not the player's fault: let the action run
          if (!closed.isCompleted) closed.complete();
        },
      );
      await ad.show(onUserEarnedReward: (_, _) => earned = true);
      await closed.future;
      _loadRewarded();
      if (!earned && context.mounted) {
        final notice = AdCover.show(context);
        await notice.notice('Watch the full video to use this.');
      }
      return earned;
    } finally {
      cover.hide();
      _gateOpen = false;
    }
  }
}
