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
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  indicatorColor: const Color(0xFFE0F2FE),
                  iconTheme: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const IconThemeData(color: Color(0xFF0284C7));
                    }
                    return const IconThemeData(color: Color(0xFF64748B));
                  }),
                  labelTextStyle: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0284C7),
                      );
                    }
                    return const TextStyle(
                      fontSize: 11.5,
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
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: (index) => navigationShell.goBranch(
                    index,
                    initialLocation: index == navigationShell.currentIndex,
                  ),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: 'Beranda',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.rss_feed_outlined),
                      selectedIcon: Icon(Icons.rss_feed_rounded),
                      label: 'Postingan',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.chat_bubble_outline_rounded),
                      selectedIcon: Icon(Icons.chat_bubble_rounded),
                      label: 'Chat',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline_rounded),
                      selectedIcon: Icon(Icons.person_rounded),
                      label: 'Akun',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
