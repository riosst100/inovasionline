import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/api/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../models/dashboard.dart';
import '../../models/order.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';
import '../orders/order_style.dart';
import 'order_queue_panels.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  static const _refreshEvery = Duration(seconds: 30);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // "Online" and "sedang checkout" are live numbers, so keep them fresh.
    _timer = Timer.periodic(_refreshEvery, (_) => _invalidate());
  }

  void _invalidate() {
    ref.invalidate(dashboardProvider);
    ref.invalidate(shippingMethodsProvider);
    ref.invalidate(instantOrdersProvider);
    ref.invalidate(scheduledOrdersProvider);
  }

  Future<void> _refresh() => Future.wait<Object>([
    ref.refresh(dashboardProvider.future),
    ref.refresh(shippingMethodsProvider.future),
    ref.refresh(instantOrdersProvider.future),
  ]).whenComplete(() => ref.invalidate(scheduledOrdersProvider));

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _invalidate,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // Shipping on/off first, then the dispatch queues (same order as the web dashboard), then the stats.
            const SizedBox(height: 10),
            const ShippingMethodsPanel(),
            const SizedBox(height: 12),
            const InstantOrdersPanel(),
            const SizedBox(height: 12),
            const ScheduledOrdersPanel(),
            stats.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.only(top: 40),
                child: ErrorView(message: errorMessage(e), onRetry: () => ref.invalidate(dashboardProvider)),
              ),
              data: (data) => _DashboardBody(stats: data),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Pesanan'),
        _StatGrid(
          children: [
            _StatTile(
              icon: Icons.local_shipping_outlined,
              color: AppColors.primary,
              label: 'Pesanan aktif',
              value: '${stats.activeOrders}',
              onTap: () => context.go('/orders'),
            ),
            _StatTile(
              icon: Icons.receipt_long_outlined,
              color: AppColors.info,
              label: 'Pesanan hari ini',
              value: '${stats.ordersToday}',
              caption: formatCurrency(stats.revenueToday),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _OrderStatusStrip(counts: stats.ordersByStatus),
        const _SectionTitle('Pengguna'),
        _StatGrid(
          children: [
            _StatTile(
              icon: Icons.circle,
              iconSize: 12,
              color: AppColors.success,
              label: 'Online sekarang',
              value: '${stats.usersOnline}',
              caption: '${stats.onlineMinutes} menit terakhir',
            ),
            _StatTile(
              icon: Icons.people_alt_outlined,
              color: AppColors.info,
              label: 'Aktif hari ini',
              value: '${stats.usersActiveToday}',
            ),
            _StatTile(
              icon: Icons.download_outlined,
              color: AppColors.primary,
              label: 'Total install',
              value: '${stats.installsTotal}',
              caption: '+${stats.installsToday} hari ini',
            ),
            _StatTile(
              icon: Icons.person_add_alt_outlined,
              color: AppColors.accent,
              label: 'Pengguna terdaftar',
              value: '${stats.usersRegistered}',
              caption: '+${stats.usersRegisteredToday} hari ini',
            ),
          ],
        ),
        const _SectionTitle('Aktivitas belanja'),
        _StatGrid(
          children: [
            _StatTile(
              icon: Icons.shopping_cart_checkout,
              color: AppColors.accent,
              label: 'Sedang checkout',
              value: '${stats.checkingOut}',
              caption: 'Saat ini',
            ),
            _StatTile(
              icon: Icons.add_shopping_cart,
              color: AppColors.primary,
              label: 'Tambah ke keranjang',
              value: '${stats.addedToCartToday}',
              caption: 'Hari ini',
            ),
            _StatTile(
              icon: Icons.shopping_cart_outlined,
              color: AppColors.info,
              label: 'Keranjang berisi',
              value: '${stats.cartsWithItems}',
              caption: 'Pengguna',
            ),
            _StatTile(
              icon: Icons.hourglass_bottom,
              color: AppColors.warning,
              label: 'Menunggu bayar',
              value: '${stats.awaitingPayment}',
            ),
          ],
        ),
        _SectionTitle('Produk terlaris', subtitle: '${stats.bestSellerDays} hari terakhir'),
        _ProductRanking(
          products: stats.bestSellers,
          emptyText: 'Belum ada penjualan.',
          metric: (p) => '${p.sold} terjual',
          caption: (p) => formatCurrency(p.revenue),
        ),
        const _SectionTitle('Produk populer', subtitle: 'Paling banyak dilihat'),
        _ProductRanking(
          products: stats.mostViewed,
          emptyText: 'Belum ada data kunjungan produk.',
          metric: (p) => '${p.views}×',
          caption: (_) => 'dilihat',
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Text(subtitle!, style: const TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
        ],
      ],
    ),
  );
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 10.0;
      final columns = constraints.maxWidth >= 600 ? 4 : 2;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    },
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.caption,
    this.iconSize = 20,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? caption;
  final double iconSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Center(
                    child: Icon(icon, color: color, size: iconSize),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.mutedForeground, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            Text(
              caption ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.mutedForeground, fontSize: 11),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OrderStatusStrip extends StatelessWidget {
  const _OrderStatusStrip({required this.counts});

  final Map<OrderStatus, int> counts;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final status in OrderStatus.values)
            StatusBadge(label: '${status.label} · ${counts[status] ?? 0}', color: orderStatusColor(status)),
        ],
      ),
    ),
  );
}

class _ProductRanking extends StatelessWidget {
  const _ProductRanking({required this.products, required this.emptyText, required this.metric, required this.caption});

  final List<DashboardProduct> products;
  final String emptyText;
  final String Function(DashboardProduct) metric;
  final String Function(DashboardProduct) caption;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: EmptyView(icon: Icons.inventory_2_outlined, text: emptyText),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (index, product) in products.indexed) ...[
            if (index > 0) const Divider(height: 1),
            ListTile(
              onTap: () => context.push('/product/${product.id}'),
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.mutedForeground),
                    ),
                  ),
                  NetImage(product.imageUrl, size: 40),
                ],
              ),
              title: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    metric(product),
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                  Text(caption(product), style: const TextStyle(color: AppColors.mutedForeground, fontSize: 11)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
