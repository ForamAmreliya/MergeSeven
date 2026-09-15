import 'dart:io';

/// AdMob ad unit IDs.
///
/// While [useTestAds] is true, Google's official test units are used so the
/// app can be developed without risking your AdMob account. Before publishing,
/// put your own unit IDs in the `_live...` constants and set [useTestAds] to
/// false.
class AdIds {
  AdIds._();

  static const bool useTestAds = true;

  // Your real ad units (from the AdMob console).
  static const _liveBannerAndroid = 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
  static const _liveInterstitialAndroid = 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
  static const _liveRewardedAndroid = 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
  static const _liveNativeAndroid = 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
  static const _liveBannerIos = 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
  static const _liveInterstitialIos = 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
  static const _liveRewardedIos = 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
  static const _liveNativeIos = 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';

  // Google's public test units.
  static const _testBannerAndroid = 'ca-app-pub-3940256099942544/9214589741';
  static const _testInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const _testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const _testNativeAndroid = 'ca-app-pub-3940256099942544/2247696110';
  static const _testBannerIos = 'ca-app-pub-3940256099942544/2435281174';
  static const _testInterstitialIos = 'ca-app-pub-3940256099942544/4411468910';
  static const _testRewardedIos = 'ca-app-pub-3940256099942544/1712485313';
  static const _testNativeIos = 'ca-app-pub-3940256099942544/3986624511';

  static String _pick(String testAndroid, String liveAndroid, String testIos, String liveIos) =>
      Platform.isIOS ? (useTestAds ? testIos : liveIos) : (useTestAds ? testAndroid : liveAndroid);

  static String get banner => _pick(_testBannerAndroid, _liveBannerAndroid, _testBannerIos, _liveBannerIos);

  static String get interstitial =>
      _pick(_testInterstitialAndroid, _liveInterstitialAndroid, _testInterstitialIos, _liveInterstitialIos);

  static String get rewarded => _pick(_testRewardedAndroid, _liveRewardedAndroid, _testRewardedIos, _liveRewardedIos);

  static String get native => _pick(_testNativeAndroid, _liveNativeAndroid, _testNativeIos, _liveNativeIos);
}
