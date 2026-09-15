import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_cover.dart';
import 'ad_ids.dart';

/// All advertising in one place: consent, SDK start-up, preloading, and the
/// two "ad gates" the screens use:
///  * [interstitialGate] – show an interstitial (if one loads quickly), then
///    continue (restart, home, back, level up).
///  * [rewardGate] – show a reward video before an action (boosters, continue).
///
/// Ads only run on Android and iOS; elsewhere the gates simply continue.
class AdsService {
  static bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// True once consent is resolved and the Mobile Ads SDK is initialised.
  final ValueNotifier<bool> ready = ValueNotifier(false);

  /// Whether "Privacy choices" must be offered in Settings (EEA / UK).
  final ValueNotifier<bool> privacyOptionsRequired = ValueNotifier(false);

  bool _started = false;
  bool _gateOpen = false;

  InterstitialAd? _interstitial;
  bool _interstitialLoading = false;
  RewardedAd? _rewarded;
  bool _rewardedLoading = false;

  // ------------------------------------------------------------- start-up
  /// Gathers consent (Google UMP) if needed, then starts the SDK and preloads
  /// full-screen ads. Call once after the first frame.
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
    _loadInterstitial();
    _loadRewarded();
  }

  // ------------------------------------------------------------- loading
  void _loadInterstitial() {
    if (!ready.value || _interstitial != null || _interstitialLoading) return;
    _interstitialLoading = true;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialLoading = false;
          _interstitial = ad;
        },
        onAdFailedToLoad: (error) {
          _interstitialLoading = false;
          debugPrint('Interstitial failed to load: ${error.message}');
          Future<void>.delayed(const Duration(seconds: 20), _loadInterstitial);
        },
      ),
    );
  }

  void _loadRewarded() {
    if (!ready.value || _rewarded != null || _rewardedLoading) return;
    _rewardedLoading = true;
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
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

  // ------------------------------------------------------------- gates
  /// Shows an interstitial ad, then returns so the caller can continue.
  /// Waits at most [wait] for an ad to load; if none is ready it continues
  /// straight away so the player is never stuck.
  Future<void> interstitialGate(BuildContext context, {Duration wait = const Duration(seconds: 3)}) async {
    if (!supported || _gateOpen || (!ready.value && _interstitial == null)) return;
    _gateOpen = true;
    final cover = AdCover.show(context);
    try {
      _loadInterstitial();
      if (!await _waitFor(() => _interstitial != null, ready.value ? wait : Duration.zero)) return;
      await _showInterstitial(cover);
    } finally {
      cover.hide();
      _gateOpen = false;
    }
  }

  /// Shows a reward video before an action. Returns true when the action may
  /// run: the video was watched to the end, or no video could be loaded (then
  /// an interstitial is shown instead if one is ready). Returns false only if
  /// the player closed the video early.
  Future<bool> rewardGate(BuildContext context) async {
    if (!supported || (!ready.value && _rewarded == null && _interstitial == null)) return true;
    if (_gateOpen) return false;
    _gateOpen = true;
    final cover = AdCover.show(context, message: 'Loading video…');
    try {
      _loadRewarded();
      final hasVideo = await _waitFor(
        () => _rewarded != null,
        ready.value ? const Duration(seconds: 6) : Duration.zero,
      );
      if (!hasVideo) {
        if (_interstitial != null) await _showInterstitial(cover);
        return true;
      }
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

  Future<void> _showInterstitial(AdCover cover) async {
    final ad = _interstitial;
    if (ad == null) return;
    _interstitial = null;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => cover.hide(),
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!closed.isCompleted) closed.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Interstitial failed to show: ${error.message}');
        ad.dispose();
        if (!closed.isCompleted) closed.complete();
      },
    );
    await ad.show();
    await closed.future.timeout(const Duration(minutes: 2), onTimeout: () {});
    _loadInterstitial();
  }
}
