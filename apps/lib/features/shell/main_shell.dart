import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/nav_badge_provider.dart';
import '../../widgets/main_nav_bar.dart';
import '../orders/active_order_bar.dart';
import '../orders/order_providers.dart';
import 'app_update_checker.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Branch indexes; keep in sync with the branch order in router.dart.
  static const _ordersBranch = 3;
  static const _homeBranch = MainNavBar.homeIndex;

  /// The bottom bar, for the first-launch tour (HomeTour) to point at its tabs.
  static final navBarKey = GlobalKey();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeOrderCount =
        ref.watch(activeOrdersProvider).valueOrNull?.length ?? 0;
    final navBadge = ref.watch(navBadgeProvider).valueOrNull;

    return AppUpdateChecker(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;

          if (navigationShell.currentIndex != _homeBranch) {
            navigationShell.goBranch(_homeBranch);
            return;
          }

          final shouldExit =
              await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Keluar Aplikasi'),
                  content: const Text(
                    'Apakah Anda yakin ingin keluar dari aplikasi?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Keluar'),
                    ),
                  ],
                ),
              ) ??
              false;

          if (shouldExit) {
            SystemNavigator.pop();
          }
        },
        child: Scaffold(
          body: Stack(
            children: [
              navigationShell,
              // Floats over the page. The orders tab already lists them; the card
              // stays mounted there (hidden) to keep the notification in sync.
              Positioned(
                left: 12,
                right: 12,
                bottom: 16,
                child: ActiveOrderBar(
                  visible: navigationShell.currentIndex != _ordersBranch,
                ),
              ),
            ],
          ),
          bottomNavigationBar: MainNavBar(
            key: navBarKey,
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
            navBadge: navBadge,
            activeOrderCount: activeOrderCount,
          ),
        ),
      ),
    );
  }
}
