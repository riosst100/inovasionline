import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/banner.dart';
import '../../providers/core_providers.dart';
import '../../widgets/banner_carousel.dart';

/// Promo image popup over home after opening the app, at most once a day per
/// device. The image is set in admin (Banner → Popup Beranda); only the first
/// active one shows.
///
/// Waits for [startupSettledProvider] so it never covers the intro or the
/// permission prompts, and only counts as shown once it actually appears.
class HomePopup {
  HomePopup._();

  static const _lastShownKey = 'home_popup_last_shown';

  /// Once per process: home can be rebuilt (e.g. after logging in again).
  static bool _handledThisLaunch = false;

  static void scheduleOn(State state, WidgetRef ref) {
    if (_handledThisLaunch) return;
    ref.listenManual<bool>(startupSettledProvider, (_, settled) {
      if (!settled || _handledThisLaunch) return;
      _handledThisLaunch = true;
      unawaited(_maybeShow(state, ref).catchError((_) {}));
    }, fireImmediately: true);
  }

  static Future<void> _maybeShow(State state, WidgetRef ref) async {
    const storage = FlutterSecureStorage();
    final today = _dateKey(DateTime.now());
    if (await storage.read(key: _lastShownKey) == today) return;

    final popups = await ref.read(bannerServiceProvider).popupBanners();
    if (popups.isEmpty) return;
    final banner = popups.first;

    // Load the image first so the popup never opens empty, and size it to the
    // image's own aspect ratio.
    final size = await _imageSize(CachedNetworkImageProvider(banner.imageUrl));
    if (size == null || !state.mounted) return;
    // Something else (a pushed page, another dialog) is on top: skip rather
    // than stack over it; it tries again next launch.
    if (ModalRoute.of(state.context)?.isCurrent == false) return;

    await storage.write(key: _lastShownKey, value: today);
    if (!state.mounted) return;
    await showGeneralDialog<void>(
      context: state.context,
      barrierDismissible: true,
      barrierLabel: 'Tutup',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, _) => _PopupContent(
        banner: banner,
        aspectRatio: size.width / size.height,
        onTap: () {
          Navigator.of(dialogContext).pop();
          if (state.mounted) openBanner(state.context, [banner], 0);
        },
      ),
      transitionBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(curved), child: child),
        );
      },
    );
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Downloads (and caches) the image; null if it fails or takes too long.
  static Future<Size?> _imageSize(ImageProvider provider) {
    final completer = Completer<Size?>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) {
          completer.complete(Size(info.image.width.toDouble(), info.image.height.toDouble()));
        }
        stream.removeListener(listener);
      },
      onError: (_, _) {
        if (!completer.isCompleted) completer.complete(null);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future.timeout(const Duration(seconds: 15), onTimeout: () {
      stream.removeListener(listener);
      return null;
    });
  }
}

class _PopupContent extends StatelessWidget {
  const _PopupContent({required this.banner, required this.aspectRatio, required this.onTap});

  final AppBanner banner;
  final double aspectRatio;
  final VoidCallback onTap;

  /// Room around the image for the close button that sits on its corner.
  static const _closeInset = 14.0;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    // Leaves a gap on both sides and never fills the screen.
    var width = (screen.width - 2 * 36).clamp(0.0, 420.0);
    var height = width / aspectRatio;
    final maxHeight = screen.height * 0.7;
    if (height > maxHeight) {
      height = maxHeight;
      width = height * aspectRatio;
    }
    final hasLink = banner.linkUrl?.trim().isNotEmpty ?? false;

    return Center(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(_closeInset),
            child: GestureDetector(
              onTap: hasLink ? onTap : null,
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 8)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Semantics(
                  label: banner.name,
                  image: true,
                  child: CachedNetworkImage(imageUrl: banner.imageUrl, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 4,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.close, size: 20, color: Colors.black87, semanticLabel: 'Tutup'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
