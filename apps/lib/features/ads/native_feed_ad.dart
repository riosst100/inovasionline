import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../config/theme.dart';
import 'admob.dart';

/// Native ad styled to sit between posts in the Posts feed. Takes no space
/// until an ad has loaded (or when native ads are off).
class NativeFeedAd extends ConsumerStatefulWidget {
  const NativeFeedAd({super.key});

  @override
  ConsumerState<NativeFeedAd> createState() => _NativeFeedAdState();
}

class _NativeFeedAdState extends ConsumerState<NativeFeedAd> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  void _load(String unitId) {
    _ad = NativeAd(
      adUnitId: unitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: Colors.white,
        cornerRadius: 12,
        callToActionTextStyle: NativeTemplateTextStyle(
          backgroundColor: AppColors.primary,
          textColor: Colors.white,
          style: NativeTemplateFontStyle.bold,
        ),
      ),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _ad = null;
          debugPrint('Native ad failed to load: ${error.message}');
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    final unitId = ref.watch(admobProvider).value?.nativeUnitId;
    if (unitId == null) return const SizedBox.shrink();
    if (_ad == null && !_loaded) _load(unitId);

    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              'Iklan',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.mutedForeground),
            ),
          ),
          // Google's medium template needs about this much room to render.
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 320, maxHeight: 360),
            child: AdWidget(ad: ad),
          ),
        ],
      ),
    );
  }
}
