import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import 'app_update_checker.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated &&
          next.user?.hasAddress == false) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go('/complete-address');
        });
      }
    });

    final authState = ref.watch(authProvider);
    if (authState.status == AuthStatus.authenticated &&
        authState.user?.hasAddress == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/complete-address');
      });
    }

    return AppUpdateChecker(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;

          if (navigationShell.currentIndex != 0) {
            navigationShell.goBranch(0);
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
          body: navigationShell,
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              child: NavigationBar(
                backgroundColor: Colors.white,
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: (index) => navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                ),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Beranda',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.rss_feed),
                    label: 'Postingan',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.chat_outlined),
                    selectedIcon: Icon(Icons.chat),
                    label: 'Chat',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'Akun',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
