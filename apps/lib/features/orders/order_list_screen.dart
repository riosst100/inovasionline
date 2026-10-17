import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import 'order_providers.dart';

class OrderListScreen extends ConsumerWidget {
  const OrderListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This is a bottom-nav tab, so signed-out visitors can land here too.
    final authenticated = ref.watch(authProvider.select((s) => s.status == AuthStatus.authenticated));
    if (!authenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pesanan Saya')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.receipt_long_outlined, size: 56, color: AppColors.mutedForeground),
                const SizedBox(height: 12),
                const Text('Masuk untuk melihat pesanan kamu.', style: TextStyle(color: AppColors.mutedForeground)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.push('/account/login'),
                  child: const Text('Masuk'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final ordersAsync = ref.watch(myOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pesanan Saya')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myOrdersProvider.future),
        child: ordersAsync.when(
          data: (orders) => orders.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    Icon(Icons.receipt_long_outlined, size: 56, color: AppColors.mutedForeground),
                    SizedBox(height: 12),
                    Center(child: Text('Belum ada pesanan.', style: TextStyle(color: AppColors.mutedForeground))),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _OrderTile(order: orders[index]),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Gagal memuat pesanan: $error')),
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/orders/${order.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.orderNumber,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${order.items.length} produk', style: const TextStyle(fontSize: 12.5, color: AppColors.mutedForeground)),
                Text(
                  formatCurrency(order.grandTotal),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  static const _labels = {
    'pending': 'Menunggu',
    'accepted': 'Diterima',
    'processing': 'Disiapkan',
    'ready': 'Siap',
    'completed': 'Selesai',
    'cancelled': 'Dibatalkan',
  };

  Color _color(String status) {
    return switch (status) {
      'completed' => AppColors.success,
      'cancelled' => AppColors.mutedForeground,
      _ => AppColors.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _labels[status] ?? status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
