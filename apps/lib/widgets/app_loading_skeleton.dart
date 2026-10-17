import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import 'skeleton.dart';

/// The home page and bottom bar as placeholders, shown while the app still
/// works out who the user is and where they are. Fetches nothing; the real
/// app (and its API calls) is only built once that is known.
class AppLoadingSkeleton extends StatelessWidget {
  const AppLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.95),
                      AppColors.primary.withValues(alpha: 0.6),
                      AppColors.primary.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.55, 0.9],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Location line
                      Row(
                        children: [
                          _onBrand(width: 22, height: 22, radius: 11),
                          const SizedBox(width: 8),
                          _onBrand(width: 170, height: 14),
                          const Spacer(),
                          _onBrand(width: 30, height: 30, radius: 15),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Search bar + cart
                      Row(
                        children: [
                          Expanded(child: _onBrand(height: 42, radius: 12)),
                          const SizedBox(width: 10),
                          _onBrand(width: 42, height: 42, radius: 12),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Skeleton(height: 156, borderRadius: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Quick highlights
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    4,
                    (_) => const Column(
                      children: [
                        Skeleton(width: 52, height: 52, borderRadius: 26),
                        SizedBox(height: 6),
                        Skeleton(width: 56, height: 10),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Flash sale strip
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Skeleton(height: 20, width: 140),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: Row(
                        children: List.generate(
                          3,
                          (_) => const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: Skeleton(
                              width: 140,
                              height: 200,
                              borderRadius: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Categories
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Skeleton(height: 20, width: 130),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        4,
                        (_) => const Column(
                          children: [
                            Skeleton(width: 60, height: 60, borderRadius: 16),
                            SizedBox(height: 6),
                            Skeleton(width: 48, height: 10),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: const _BottomBarPlaceholder(),
        ),
      ),
    );
  }

  /// Placeholder block on the green header, where grey would look out of place.
  static Widget _onBrand({double? width, double? height, double radius = 8}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Same look as MainShell's bottom bar, without the tabs being usable yet.
class _BottomBarPlaceholder extends StatelessWidget {
  const _BottomBarPlaceholder();

  static const _items = [
    (Icons.shopping_bag_rounded, 'Belanja Online'),
    (Icons.rss_feed_outlined, 'Postingan'),
    (Icons.sms_outlined, 'Chat'),
    (Icons.person_outline_rounded, 'Akun'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (final (index, (icon, label)) in _items.indexed)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        color: index == 0
                            ? const Color(0xFF0284C7)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: index == 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: index == 0
                              ? const Color(0xFF0284C7)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
