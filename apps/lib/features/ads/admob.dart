import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../config/env.dart';
import '../../providers/core_providers.dart';

enum AdPlacement { home, homeBottom, productList, productDetail }

/// AdMob setup from admin (Iklan → Adsense / Admob). The App ID itself is baked
/// into the native build; this carries the ad unit IDs and where ads show.
class AdmobConfig {
  const AdmobConfig({
    required this.bannerUnitId,
    required this.interstitialUnitId,
    required this.rewardedUnitId,
    required this.nativeUnitId,
    required this.placements,
    required this.interstitialEnabled,
    required this.interstitialEvery,
    required this.postsNativeEvery,
  });

  factory AdmobConfig.fromJson(Map<String, dynamic> json) {
    final placements = json['placements'] as Map<String, dynamic>? ?? const {};
    return AdmobConfig(
      bannerUnitId: _resolve(json['banner'], _testBanner),
      interstitialUnitId: _resolve(json['interstitial'], _testInterstitial),
      rewardedUnitId: _resolve(json['rewarded'], _testRewarded),
      nativeUnitId: _resolve(json['native'], _testNative),
      placements: {
        if (placements['home_banner'] == true) AdPlacement.home,
        if (placements['home_bottom_banner'] == true) AdPlacement.homeBottom,
        if (placements['product_list_banner'] == true) AdPlacement.productList,
        if (placements['product_detail_banner'] == true) AdPlacement.productDetail,
      },
      interstitialEnabled: json['interstitial_enabled'] == true,
      interstitialEvery: (json['interstitial_every'] as num?)?.toInt() ?? 5,
      postsNativeEvery: (json['posts_native_every'] as num?)?.toInt() ?? 0,
    );
  }

  final String? bannerUnitId;
  final String? interstitialUnitId;

  /// Watched before the one-time saldo bonus can be claimed (when admin requires it).
  final String? rewardedUnitId;
  final String? nativeUnitId;
  final Set<AdPlacement> placements;
  final bool interstitialEnabled;
  final int interstitialEvery;

  /// A native ad after every Nth post in the Posts feed; 0 = none.
  final int postsNativeEvery;

  String? bannerFor(AdPlacement placement) => placements.contains(placement) ? bannerUnitId : null;

  // Google's sample units. Debug and dev-flavor builds swap them in for the real
  // ones so testing never counts as (invalid) traffic on the AdMob account.
  static const _testBanner = (android: 'ca-app-pub-3940256099942544/9214589741', ios: 'ca-app-pub-3940256099942544/2435281174');
  static const _testInterstitial = (android: 'ca-app-pub-3940256099942544/1033173712', ios: 'ca-app-pub-3940256099942544/4411468910');
  static const _testRewarded = (android: 'ca-app-pub-3940256099942544/5224354917', ios: 'ca-app-pub-3940256099942544/1712485313');
  static const _testNative = (android: 'ca-app-pub-3940256099942544/2247696110', ios: 'ca-app-pub-3940256099942544/3986624511');

  /// The unit for this platform; null when admin left it empty. Test builds always
  /// get the sample unit, so ads can be checked before real units exist.
  static String? _resolve(Object? units, ({String android, String ios}) test) {
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    if (useTestAds) return isIos ? test.ios : test.android;
    if (units is! Map) return null;
    final id = units[isIos ? 'ios' : 'android'];
    return id is String && id.isNotEmpty ? id : null;
  }
}

bool get useTestAds => !kReleaseMode || Env.isDev;

bool get _adsSupported =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

/// Null while ads are off (or the config can't be loaded). The SDK is only
/// started once there is something to show.
final admobProvider = FutureProvider<AdmobConfig?>((ref) async {
  if (!_adsSupported) return null;
  try {
    final response = await ref.watch(apiClientProvider).dio.get('/admob-config');
    final data = response.data['data'];
    if (data is! Map<String, dynamic>) return null;
    // Starting the SDK is heavy (threads, native init). Wait until the first screen is up and the
    // welcome animation has played, instead of competing with them.
    for (var i = 0; i < 40 && !ref.read(startupSettledProvider); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    await Future<void>.delayed(const Duration(seconds: 3));
    await MobileAds.instance.initialize();
    return AdmobConfig.fromJson(data);
  } catch (e) {
    debugPrint('AdMob disabled: $e');
    return null;
  }
});

/// Full-screen ad on every Nth product detail opened, at most once per [_cooldown].
class InterstitialAds {
  InterstitialAds(this._ref);

  final Ref _ref;
  static const _cooldown = Duration(seconds: 60);

  InterstitialAd? _ad;
  bool _loading = false;
  int _opens = 0;
  DateTime? _lastShown;

  Future<void> onProductOpened() async {
    final config = await _ref.read(admobProvider.future);
    final unitId = config?.interstitialUnitId;
    if (config == null || !config.interstitialEnabled || unitId == null) return;

    _opens++;
    final due = _opens % config.interstitialEvery == 0;
    final cooledDown = _lastShown == null || DateTime.now().difference(_lastShown!) >= _cooldown;
    final ad = _ad;
    if (due && cooledDown && ad != null) {
      _ad = null;
      _lastShown = DateTime.now();
      await ad.show();
      return;
    }
    _preload(unitId);
  }

  void _preload(String unitId) {
    if (_ad != null || _loading) return;
    _loading = true;
    InterstitialAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _preload(unitId);
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _preload(unitId);
            },
          );
          _ad = ad;
        },
        onAdFailedToLoad: (error) {
          _loading = false;
          debugPrint('Interstitial failed to load: ${error.message}');
        },
      ),
    );
  }
}

final interstitialAdsProvider = Provider<InterstitialAds>((ref) => InterstitialAds(ref));

enum RewardedResult { earned, skipped, unavailable }

/// Rewarded ad that unlocks the one-time saldo bonus. The reward itself is
/// confirmed server-side: AdMob calls the backend (SSV) with [userId], so the
/// app only reports whether the user watched to the end.
class RewardedAds {
  RewardedAds(this._ref);

  final Ref _ref;
  Future<RewardedAd?>? _loading;

  /// Starts loading early (e.g. while the explanation dialog is open).
  Future<RewardedAd?> preload() => _loading ??= _load();

  Future<RewardedAd?> _load() async {
    final unitId = (await _ref.read(admobProvider.future))?.rewardedUnitId;
    if (unitId == null) return null;

    final loaded = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: loaded.complete,
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded ad failed to load: ${error.message}');
          loaded.complete(null);
        },
      ),
    );
    return loaded.future.timeout(const Duration(seconds: 20), onTimeout: () => null);
  }

  Future<RewardedResult> show({required String userId}) async {
    final ad = await preload();
    _loading = null; // a rewarded ad can only be shown once
    if (ad == null) return RewardedResult.unavailable;

    await ad.setServerSideOptions(ServerSideVerificationOptions(userId: userId));
    var earned = false;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        closed.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Rewarded ad failed to show: ${error.message}');
        ad.dispose();
        closed.complete();
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    await closed.future;
    return earned ? RewardedResult.earned : RewardedResult.skipped;
  }
}

final rewardedAdsProvider = Provider<RewardedAds>((ref) => RewardedAds(ref));
