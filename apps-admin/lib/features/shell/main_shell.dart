import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) =>
            navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
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

/// Hosts the branch navigators: Dashboard + Pesanan and Produk + Kategori each sit side by side
/// in a [PageView] so they can be swiped between; Akun is switched without animation.
class BranchPager extends StatefulWidget {
  const BranchPager({super.key, required this.navigationShell, required this.children});

  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  @override
  State<BranchPager> createState() => _BranchPagerState();
}

class _BranchPagerState extends State<BranchPager> {
  /// Branch indexes (in page order) that can be swiped between.
  static const _groups = [
    [0, 1], // Dashboard, Pesanan
    [2, 3], // Produk, Kategori
  ];
  static const _dashboardIndex = 0;
  static const _ordersIndex = 1;

  /// How far (px) the orders tabs must be pulled past "Semua" to slide back to the dashboard.
  static const _overscrollToLeave = 80.0;

  late final _controllers = [
    for (final group in _groups) PageController(initialPage: group.contains(_index) ? group.indexOf(_index) : 0),
  ];
  double _overscroll = 0;
  bool _left = false;

  int get _index => widget.navigationShell.currentIndex;

  int? _groupOf(int index) {
    final group = _groups.indexWhere((g) => g.contains(index));
    return group < 0 ? null : group;
  }

  @override
  void didUpdateWidget(BranchPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    final from = oldWidget.navigationShell.currentIndex;
    final to = _index;
    final group = _groupOf(to);
    if (from == to || group == null) return;
    final controller = _controllers[group];
    final page = _groups[group].indexOf(to);
    // Scrolling the controller mid-build is not allowed, so wait for this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.hasClients || controller.page?.round() == page) return;
      if (_groupOf(from) == group) {
        controller.animateToPage(page, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
      } else {
        // Coming from another group: there is nothing on screen to slide from.
        controller.jumpToPage(page);
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Selects the branch once a swipe has settled on a page.
  bool _onPagerScroll(int group, ScrollNotification notification) {
    if (notification.depth != 0 || notification is! ScrollEndNotification) return false;
    final page = _controllers[group].page;
    if (page == null || page != page.roundToDouble()) return false;
    final branch = _groups[group][page.round()];
    if (branch != _index) widget.navigationShell.goBranch(branch);
    return false;
  }

  /// Pesanan: its status tabs already use horizontal swipes, so only pulling past the
  /// first tab ("Semua") slides back to the dashboard.
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
      case ScrollUpdateNotification(:final metrics, dragDetails: _?) when metrics.pixels < metrics.minScrollExtent:
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
    // didUpdateWidget slides the pager over once the branch has switched.
    widget.navigationShell.goBranch(_dashboardIndex);
  }

  Widget _page(int branch) {
    final child = widget.children[branch];
    return _KeepAlivePage(
      child: branch == _ordersIndex
          ? NotificationListener<ScrollNotification>(onNotification: _onOrdersScroll, child: child)
          : child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final index = _index;
    final children = widget.children;

    return Stack(
      fit: StackFit.expand,
      children: [
        for (final (g, group) in _groups.indexed)
          _Branch(
            active: group.contains(index),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) => _onPagerScroll(g, notification),
              child: PageView(
                controller: _controllers[g],
                // Lays out the neighbouring page before it scrolls into view, so it doesn't build mid-swipe.
                allowImplicitScrolling: true,
                children: [for (final branch in group) _page(branch)],
              ),
            ),
          ),
        for (var i = 0; i < children.length; i++)
          if (_groupOf(i) == null) _Branch(active: index == i, child: children[i]),
      ],
    );
  }
}

/// Keeps an inactive branch in the tree (preserving its state) but hidden and paused.
class _Branch extends StatelessWidget {
  const _Branch({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: !active,
      child: TickerMode(enabled: active, child: child),
    );
  }
}

/// Stops the PageView from disposing the off-screen branch navigator (and its state).
class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
