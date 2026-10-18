import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'admob.dart';

/// Full-width AdMob banner for [placement]. Takes no space until an ad has
/// loaded, and stays hidden when admin turned the placement off.
class AdBanner extends ConsumerStatefulWidget {
  const AdBanner({
    super.key,
    required this.placement,
    this.padding = EdgeInsets.zero,
    this.emptyHeight = 0,
  });

  final AdPlacement placement;
  final EdgeInsets padding;

  /// Space taken while there is no ad, e.g. the gap the layout had without one.
  final double emptyHeight;

  @override
  ConsumerState<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends ConsumerState<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _requested = false;

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  Future<void> _load(String unitId, double width) async {
    _requested = true;
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width.truncate());
    if (!mounted || size == null) return;
    _ad = BannerAd(
      adUnitId: unitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _ad = null;
          debugPrint('Banner (${widget.placement.name}) failed to load: ${error.message}');
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    final unitId = ref.watch(admobProvider).value?.bannerFor(widget.placement);
    if (unitId == null) return SizedBox(height: widget.emptyHeight);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!_requested) {
          _load(unitId, constraints.maxWidth - widget.padding.horizontal);
        }

        final ad = _ad;
        if (!_loaded || ad == null) return SizedBox(height: widget.emptyHeight);

        return Padding(
          padding: widget.padding,
          // heightFactor 1: only as tall as the ad. A plain Center fills all the
          // height it is offered, which as a Scaffold.bottomNavigationBar is the
          // whole screen, covering the product grid.
          child: Center(
            heightFactor: 1,
            child: SizedBox(
              width: ad.size.width.toDouble(),
              height: ad.size.height.toDouble(),
              child: AdWidget(ad: ad),
            ),
          ),
        );
      },
    );
  }
}
