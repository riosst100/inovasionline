import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/account_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/categories/category_list_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/orders/order_detail_screen.dart';
import '../features/orders/order_list_screen.dart';
import '../features/products/product_form_screen.dart';
import '../features/products/product_list_screen.dart';
import '../features/shell/main_shell.dart';
import '../providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Re-runs the redirect whenever the session changes (login, logout, 401).
  final authChanges = ValueNotifier<AuthStatus>(ref.read(authProvider).status);
  ref.listen(authProvider, (_, next) => authChanges.value = next.status);
  ref.onDispose(authChanges.dispose);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: authChanges,
    redirect: (context, state) {
      final status = authChanges.value;
      final location = state.matchedLocation;
      if (status == AuthStatus.unknown) return location == '/splash' ? null : '/splash';
      if (status == AuthStatus.unauthenticated) return location == '/login' ? null : '/login';
      if (location == '/login' || location == '/splash') return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(navigationShell: shell),
        // Order must match the destinations in MainShell.
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/dashboard', builder: (_, _) => const DashboardScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/orders', builder: (_, _) => const OrderListScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/products', builder: (_, _) => const ProductListScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/categories', builder: (_, _) => const CategoryListScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/account', builder: (_, _) => const AccountScreen())],
          ),
        ],
      ),
      GoRoute(
        path: '/order/:id',
        builder: (_, state) => OrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/product/new', builder: (_, _) => const ProductFormScreen()),
      GoRoute(
        path: '/product/:id',
        builder: (_, state) => ProductFormScreen(productId: state.pathParameters['id']),
      ),
    ],
  );
});
