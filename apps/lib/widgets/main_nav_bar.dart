import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../providers/nav_badge_provider.dart';

/// The app's bottom bar. Shared by MainShell and the startup skeleton
/// (AppLoadingSkeleton) so both look exactly the same.
class MainNavBar extends StatelessWidget {
  const MainNavBar({
    super.key,
    required this.selectedIndex,
    this.onDestinationSelected,
    this.navBadge,
    this.activeOrderCount = 0,
  });

  /// Branch index of the centre "Belanja" tab; keep in sync with router.dart.
  static const homeIndex = 2;

  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;
  final NavBadge? navBadge;
  final int activeOrderCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            // The shop button carries its own highlight; a pill behind it would clash.
            indicatorColor: selectedIndex == homeIndex
                ? Colors.transparent
                : const Color(0xFFE0F2FE),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: Color(0xFF0284C7));
              }
              return const IconThemeData(color: Color(0xFF64748B));
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0284C7),
                );
              }
              return const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              );
            }),
          ),
          child: NavigationBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            height: 60,
            // Default is 4px above the label; pull it closer to the icon.
            labelPadding: EdgeInsets.zero,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.rss_feed_outlined),
                selectedIcon: Icon(Icons.rss_feed_rounded),
                label: 'Postingan',
              ),
              const NavigationDestination(
                icon: Icon(Icons.sms_outlined),
                selectedIcon: Icon(Icons.sms_rounded),
                label: 'Chat',
              ),
              NavigationDestination(
                icon: _ShopNavButton(selected: false, badge: navBadge),
                selectedIcon: _ShopNavButton(
                  selected: true,
                  badge: navBadge,
                ),
                label: 'Belanja Online',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: activeOrderCount > 0,
                  label: Text('$activeOrderCount'),
                  child: const Icon(Icons.list_alt_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: activeOrderCount > 0,
                  label: Text('$activeOrderCount'),
                  child: const Icon(Icons.list_alt_rounded),
                ),
                label: 'Pesanan',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Akun',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The centre "Belanja" tab: a raised round button, always highlighted as the main menu.
class _ShopNavButton extends StatelessWidget {
  const _ShopNavButton({required this.selected, this.badge});

  final bool selected;

  /// Promo tag from admin (Pengaturan → Badge Menu); null hides it.
  final NavBadge? badge;

  @override
  Widget build(BuildContext context) {
    // Laid out as a normal 24px icon so the label keeps its room; the 42px circle
    // is painted overflowing upwards, which gives a subtle raised look.
    return SizedBox(
      width: 42,
      height: 24,
      child: OverflowBox(
        maxHeight: 42,
        alignment: Alignment.bottomCenter,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? const Color(0xFFE0F2FE)
                    : const Color(0xFFF0F9FF),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF7DD3FC)
                      : const Color(0xFFBAE6FD),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                selected
                    ? Icons.shopping_bag_rounded
                    : Icons.shopping_bag_outlined,
                color: selected
                    ? const Color(0xFF0284C7)
                    : const Color(0xFF38BDF8),
                size: 24,
              ),
            ),
            if (badge case final badge?)
              // Sits on the circle's bottom edge, just above the "Belanja Online"
              // label, clear of the icon.
              Positioned(bottom: -4, child: _PromoBadge(label: badge.label)),
          ],
        ),
      ),
    );
  }
}

/// Orange promo pill with a light sweeping across it every few seconds.
class _PromoBadge extends StatefulWidget {
  const _PromoBadge({required this.label});

  final String label;

  @override
  State<_PromoBadge> createState() => _PromoBadgeState();
}

class _PromoBadgeState extends State<_PromoBadge>
    with SingleTickerProviderStateMixin {
  /// One cycle: the shine sweeps during the first [_sweepPortion], then rests.
  static const _cycle = Duration(milliseconds: 3200);
  static const _sweepPortion = 0.3;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _cycle,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour the system "remove animations" accessibility setting.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      // 1px more at the bottom lifts the text to the optical centre of the pill.
      padding: const EdgeInsets.fromLTRB(5, 0, 5, 1),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        widget.label,
        maxLines: 1,
        softWrap: false,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          height: 1.25,
          // Split the extra line height evenly instead of stacking it above the glyphs.
          leadingDistribution: TextLeadingDistribution.even,
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _controller,
      child: pill,
      builder: (context, child) {
        final sweep = (_controller.value / _sweepPortion).clamp(0.0, 1.0);
        if (sweep >= 1) return child!;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.55),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0.35, 0.5, 0.65],
            // Slides the highlight from off the left edge to off the right edge.
            transform: _SlideGradientTransform(sweep * 2 - 1),
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

class _SlideGradientTransform extends GradientTransform {
  const _SlideGradientTransform(this.percent);

  final double percent;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * percent, 0, 0);
}
