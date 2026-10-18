import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _dashboardIndex = 0;
const _ordersIndex = 1;

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  /// How far (px) the orders tabs must be pulled past "Semua" to jump back to the dashboard.
  static const _overscrollToLeave = 80.0;

  /// Minimum fling speed (px/s) for the dashboard → orders swipe.
  static const _flingVelocity = 300.0;

  double _overscroll = 0;
  bool _left = false;

  StatefulNavigationShell get _shell => widget.navigationShell;

  void _goBranch(int index) => _shell.goBranch(index, initialLocation: index == _shell.currentIndex);

  /// Dashboard: swipe the finger right-to-left to open Pesanan (the next tab).
  void _onDashboardDragEnd(DragEndDetails details) {
    if ((details.primaryVelocity ?? 0) < -_flingVelocity) _goBranch(_ordersIndex);
  }

  /// Pesanan: its status tabs already use horizontal swipes, so only pulling past the
  /// first tab ("Semua") goes back to the dashboard.
  bool _onOrdersScroll(ScrollNotification notification) {
    // Only the status TabBarView, not the scrollable TabBar strip or the vertical lists.
    if (notification.depth != 0 || notification.metrics is! PageMetrics) return false;

    switch (notification) {
      case ScrollStartNotification():
        _overscroll = 0;
        _left = false;
      case OverscrollNotification(:final overscroll, dragDetails: _?) when overscroll < 0:
        // Clamping physics (Android).
        _overscroll -= overscroll;
        _maybeLeaveOrders();
      case ScrollUpdateNotification(:final metrics, dragDetails: _?)
          when metrics.pixels < metrics.minScrollExtent:
        // Bouncing physics (iOS).
        _overscroll = metrics.minScrollExtent - metrics.pixels;
        _maybeLeaveOrders();
      default:
        break;
    }
    return false;
  }

  void _maybeLeaveOrders() {
    if (_left || _overscroll < _overscrollToLeave) return;
    _left = true;
    _goBranch(_dashboardIndex);
  }

  @override
  Widget build(BuildContext context) {
    final index = _shell.currentIndex;

    return Scaffold(
      // Keep the same widget tree for every tab so the shell's branch state is never rebuilt.
      body: NotificationListener<ScrollNotification>(
        onNotification: index == _ordersIndex ? _onOrdersScroll : (_) => false,
        child: GestureDetector(
          onHorizontalDragEnd: index == _dashboardIndex ? _onDashboardDragEnd : null,
          child: _shell,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: _goBranch,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Pesanan',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Produk',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: 'Kategori',
          ),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Akun'),
        ],
      ),
    );
  }
}
