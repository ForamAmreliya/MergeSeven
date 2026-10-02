import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../theme/app_colors.dart';
import 'ad_cover.dart';
import 'ad_ids.dart';

/// All advertising in one place: consent, SDK start-up, and every ad the app
/// uses. Banners, native ads and the reward video are all loaded here once
/// (started from `main`), so screens only display what is already loaded and
/// never kick off a load of their own.
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

  /// Loaded ads the screens show. Null until an ad is ready.
  final ValueNotifier<BannerAd?> banner = ValueNotifier(null);
  final ValueNotifier<NativeAd?> nativeMedium = ValueNotifier(null);
  final ValueNotifier<NativeAd?> nativeSmall = ValueNotifier(null);

  bool _bannerLoading = false;
  bool _nativeMediumLoading = false;
  bool _nativeSmallLoading = false;
  Brightness _brightness = Brightness.dark;
  Timer? _bannerRetry;
  Timer? _nativeRetry;

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
    _loadBanner();
    _loadNative(compact: false);
    _loadNative(compact: true);
  }

  /// Keeps the native ad templates in step with the app theme. Reloads them
  /// only when the brightness really changed.
  void setBrightness(Brightness brightness) {
    if (!supported || _brightness == brightness) return;
    _brightness = brightness;
    if (!ready.value) return;
    _disposeNative();
    _loadNative(compact: false);
    _loadNative(compact: true);
  }

  AppPalette get _palette => _brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;

  // ------------------------------------------------- banner / native ads
  void _loadBanner() {
    if (!ready.value || banner.value != null || _bannerLoading) return;
    _bannerLoading = true;
    _bannerRetry?.cancel();
    final view = PlatformDispatcher.instance.views.first;
    final width = (view.physicalSize.width / view.devicePixelRatio).truncate();
    // ignore: deprecated_member_use
    AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width).then((size) {
      if (size == null) {
        _bannerLoading = false;
        return;
      }
      BannerAd(
        adUnitId: AdIds.banner,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            _bannerLoading = false;
            banner.value = ad as BannerAd;
          },
          onAdFailedToLoad: (ad, error) {
            _bannerLoading = false;
            debugPrint('Banner failed to load: ${error.message}');
            ad.dispose();
            _bannerRetry = Timer(const Duration(seconds: 45), _loadBanner);
          },
        ),
      ).load();
    });
  }

  void _loadNative({required bool compact}) {
    final slot = compact ? nativeSmall : nativeMedium;
    if (!ready.value || slot.value != null) return;
    if (compact ? _nativeSmallLoading : _nativeMediumLoading) return;
    compact ? _nativeSmallLoading = true : _nativeMediumLoading = true;
    _nativeRetry?.cancel();
    final p = _palette;
    NativeAd(
      adUnitId: AdIds.native,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: compact ? TemplateType.small : TemplateType.medium,
        mainBackgroundColor: p.card,
        cornerRadius: 16,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFFFFFFFF),
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
          compact ? _nativeSmallLoading = false : _nativeMediumLoading = false;
          slot.value = ad as NativeAd;
        },
        onAdFailedToLoad: (ad, error) {
          compact ? _nativeSmallLoading = false : _nativeMediumLoading = false;
          debugPrint('Native ad failed to load: ${error.message}');
          ad.dispose();
          _nativeRetry = Timer(const Duration(seconds: 45), () {
            _loadNative(compact: compact);
          });
        },
      ),
    ).load();
  }

  void _disposeNative() {
    nativeMedium.value?.dispose();
    nativeSmall.value?.dispose();
    nativeMedium.value = null;
    nativeSmall.value = null;
  }

  void dispose() {
    _bannerRetry?.cancel();
    _nativeRetry?.cancel();
    banner.value?.dispose();
    _disposeNative();
    _rewarded?.dispose();
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

  /// Waits for a video to be ready, retrying the load while it waits.
  Future<bool> _waitForRewarded(Duration timeout) async {
    final end = DateTime.now().add(timeout);
    while (_rewarded == null && DateTime.now().isBefore(end)) {
      _loadRewarded(); // does nothing while a load is already running
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return _rewarded != null;
  }

  // ------------------------------------------------------------- gate
  /// Shows the video ad after the player chose "Watch Ad".
  ///
  /// Returns true only when the reward was really earned (the video was
  /// watched to the end). If no video can be loaded, or the player closes it
  /// early, it returns false and the caller gives nothing: no booster, no
  /// diamonds, and nothing is charged.
  Future<bool> rewardGate(BuildContext context) async {
    if (!supported) return true; // desktop / tests: nothing to show
    if (_gateOpen) return false;
    _gateOpen = true;
    final cover = AdCover.show(context, message: 'Loading video…');
    try {
      final hasVideo = await _waitForRewarded(const Duration(seconds: 8));
      if (!hasVideo) {
        await cover.notice('No video available right now.\nPlease try again in a moment.');
        return false;
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
          if (!closed.isCompleted) closed.complete();
        },
      );
      await ad.show(onUserEarnedReward: (_, _) => earned = true);
      await closed.future;
      _loadRewarded(); // get the next one ready
      if (!earned && context.mounted) {
        final notice = AdCover.show(context);
        await notice.notice('Watch the full video to get this.');
      }
      return earned;
    } finally {
      _gateOpen = false;
    }
  }
}
