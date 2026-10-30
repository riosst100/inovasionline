import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../config/theme.dart';
import 'admob.dart';

/// Popup with a native ad, shown once per app launch. The ad is loaded first and
/// the popup only opens when it is ready (8s cap), so users never see an empty
/// dialog. Whether and when it runs is decided by the admin's popup schedule
/// (see HomePopup); needs AdMob on and a native unit ID. Returns whether it was shown.
class LaunchAdPopup {
  static Future<bool> show(BuildContext context, WidgetRef ref) async {
    final config = await ref.read(admobProvider.future);
    final unitId = config?.nativeUnitId;
    if (config == null || unitId == null) return false;

    final loaded = Completer<NativeAd?>();
    final ad = NativeAd(
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
        onAdLoaded: (ad) => loaded.complete(ad as NativeAd),
        onAdFailedToLoad: (ad, error) {
          debugPrint('Launch native ad failed to load: ${error.message}');
          ad.dispose();
          loaded.complete(null);
        },
      ),
    )..load();

    final ready = await loaded.future.timeout(const Duration(seconds: 8), onTimeout: () => null);
    if (ready == null || !context.mounted) {
      ad.dispose();
      return false;
    }

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      'Iklan',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedForeground),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Tutup',
                  ),
                ],
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 320, maxHeight: 360),
                child: AdWidget(ad: ready),
              ),
            ],
          ),
        ),
      ),
    );
    ad.dispose();
    return true;
  }
}
