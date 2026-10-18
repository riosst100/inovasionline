import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/order.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_list.dart';
import 'order_style.dart';

/// Tab order: "Semua" (null) first, then every status in workflow order.
const _tabs = <OrderStatus?>[null, ...OrderStatus.values];

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: _tabs.length, vsync: this);
  final _listKeys = {for (final status in _tabs) status: GlobalKey<PagedListState<Order>>()};
  String _search = '';
  Map<String, int>? _counts;
  bool _countsScheduled = false;
  int _countsGeneration = 0;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Coalesces the page-1 fetches of several tabs (e.g. after a search) into one request.
  void _loadCounts() {
    if (_countsScheduled) return;
    _countsScheduled = true;
    Future.microtask(() async {
      _countsScheduled = false;
      final generation = ++_countsGeneration;
      try {
        final counts = await ref.read(orderServiceProvider).counts(search: _search);
        if (mounted && generation == _countsGeneration) setState(() => _counts = counts);
      } catch (_) {
        // Badges are a nicety; the list itself reports load errors.
      }
    });
  }

  void _setSearch(String value) {
    setState(() => _search = value);
    // fetch reads _search at call time, so each restart picks up the new query.
    for (final key in _listKeys.values) {
      key.currentState?.refresh();
    }
  }

  Future<void> _open(Order order) async {
    final updated = await context.push<Order>('/order/${order.id}');
    if (updated == null) return;
    for (final MapEntry(key: status, value: key) in _listKeys.entries) {
      final list = key.currentState;
      if (list == null) continue;
      if (status == null) {
        list.replaceWhere((o) => o.id == updated.id, updated);
      } else if (status == updated.status) {
        // It may have just moved into this tab; reload so it shows up in order.
        list.refresh();
      } else {
        list.removeWhere((o) => o.id == updated.id);
      }
    }
    _loadCounts();
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(orderServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesanan'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: SearchField(hint: 'Cari nomor pesanan / nama pembeli', onChanged: _setSearch),
              ),
              _StatusTabBar(controller: _tabController, counts: _counts),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final status in _tabs)
            _KeepAlive(
              child: PagedList<Order>(
                key: _listKeys[status],
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                fetch: (page) {
                  if (page == 1) _loadCounts();
                  return service.list(page: page, status: status, search: _search);
                },
                emptyIcon: Icons.receipt_long_outlined,
                emptyText: _search.isNotEmpty
                    ? 'Tidak ada pesanan yang cocok.'
                    : status == null
                    ? 'Belum ada pesanan.'
                    : 'Tidak ada pesanan "${status.label}".',
                itemBuilder: (context, order) => _OrderCard(order: order, onTap: () => _open(order)),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusTabBar extends StatelessWidget {
  const _StatusTabBar({required this.controller, required this.counts});

  final TabController controller;
  final Map<String, int>? counts;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        labelPadding: const EdgeInsets.symmetric(horizontal: 10),
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 3,
        indicatorColor: AppColors.primary,
        dividerColor: AppColors.border,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.mutedForeground,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
        splashBorderRadius: BorderRadius.circular(8),
        tabs: [
          for (final (index, status) in _tabs.indexed)
            Tab(
              height: 44,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(status?.label ?? 'Semua'),
                  const SizedBox(width: 6),
                  _CountPill(
                    count: counts?[status?.name ?? 'all'],
                    color: status == null ? AppColors.primary : orderStatusColor(status),
                    selected: controller.index == index,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count, required this.color, required this.selected});

  final int? count;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final value = count;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: selected
            ? color
            : (value ?? 0) > 0
            ? color.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        value == null ? '·' : (value > 999 ? '999+' : '$value'),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: selected
              ? Colors.white
              : (value ?? 0) > 0
              ? color
              : AppColors.mutedForeground,
        ),
      ),
    );
  }
}

/// Keeps a tab's list (scroll position and loaded pages) alive while swiping between tabs.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = orderStatusColor(order.status);
    const muted = TextStyle(color: AppColors.mutedForeground, fontSize: 12);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.receipt_long_rounded, color: statusColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.orderNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                        ),
                        const SizedBox(height: 2),
                        Text(formatDateTime(order.createdAt), style: muted),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OrderStatusBadge(order.status),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.mutedForeground),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          order.customerName ?? '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      if (order.itemsCount case final count?) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.shopping_bag_outlined, size: 15, color: AppColors.mutedForeground),
                        const SizedBox(width: 4),
                        Text('$count item', style: muted),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PaymentStatusBadge(order),
                            if (order.paymentMethodName case final method?) ...[
                              const SizedBox(height: 4),
                              Text(method, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Total', style: TextStyle(color: AppColors.mutedForeground, fontSize: 11)),
                          Text(
                            formatCurrency(order.grandTotal),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
