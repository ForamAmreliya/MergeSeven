import 'dart:io';

/// AdMob ad unit IDs.
///
/// Android uses the live units below. iOS has no live units yet, so it falls
/// back to Google's test units; replace [_liveBannerIos] and friends (and add
/// the iOS app ID to Info.plist) before releasing on iOS.
///
/// Set [useTestAds] to true while developing: tapping your own live ads can
/// get an AdMob account limited or banned.
class AdIds {
  AdIds._();

  static const bool useTestAds = false;

  // Live units (AdMob console).
  static const _liveBannerAndroid = 'ca-app-pub-7358280287589547/7583334281';
  static const _liveNativeAndroid = 'ca-app-pub-7358280287589547/6186667143';
  static const _liveRewardedAndroid = 'ca-app-pub-7358280287589547/9591559681';
  static const _liveBannerIos = '';
  static const _liveNativeIos = '';
  static const _liveRewardedIos = '';

  // Google's public test units.
  static const _testBannerAndroid = 'ca-app-pub-3940256099942544/9214589741';
  static const _testNativeAndroid = 'ca-app-pub-3940256099942544/2247696110';
  static const _testRewardedAndroid = 'ca-app-pub-3940256099942544/5354046379';
  static const _testBannerIos = 'ca-app-pub-3940256099942544/2435281174';
  static const _testNativeIos = 'ca-app-pub-3940256099942544/3986624511';
  static const _testRewardedIos = 'ca-app-pub-3940256099942544/6978759866';

  static String _pick(String testAndroid, String liveAndroid, String testIos, String liveIos) {
    if (Platform.isIOS) return useTestAds || liveIos.isEmpty ? testIos : liveIos;
    return useTestAds || liveAndroid.isEmpty ? testAndroid : liveAndroid;
  }

  static String get banner => _pick(_testBannerAndroid, _liveBannerAndroid, _testBannerIos, _liveBannerIos);

  static String get native => _pick(_testNativeAndroid, _liveNativeAndroid, _testNativeIos, _liveNativeIos);

  /// Rewarded interstitial: the "Watch Ad" video for boosters and Continue.
  static String get rewarded => _pick(_testRewardedAndroid, _liveRewardedAndroid, _testRewardedIos, _liveRewardedIos);
}
