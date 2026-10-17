import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/order.dart';
import '../../providers/core_providers.dart';
import '../../providers/nav_badge_provider.dart';
import '../wallet/wallet_providers.dart';
import '../../services/active_order_notification.dart';
import 'order_providers.dart';

/// Pinned above the bottom navigation while the buyer has an in-progress order.
/// Also drives the ongoing system notification for that order.
class ActiveOrderBar extends ConsumerStatefulWidget {
  const ActiveOrderBar({super.key, this.visible = true});

  final bool visible;

  @override
  ConsumerState<ActiveOrderBar> createState() => _ActiveOrderBarState();
}

class _ActiveOrderBarState extends ConsumerState<ActiveOrderBar> {
  late final AppLifecycleListener _lifecycle;
  var _paying = false;

  @override
  void initState() {
    super.initState();
    // Status changes while the app was in the background (driver, admin, payment).
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.invalidate(myOrdersProvider);
        // Admin may have changed or scheduled the promo badge meanwhile.
        ref.invalidate(navBadgeProvider);
        // A top-up paid outside the app (VA, ATM) may have landed.
        invalidateWalletFromWidget(ref);
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _pay(Order order) async {
    setState(() => _paying = true);
    try {
      final updated = await ref
          .read(checkoutServiceProvider)
          .payOrder(order.id);
      final url = updated.paymentRedirectUrl;
      if (url == null) throw Exception('Link pembayaran tidak tersedia.');
      if (!mounted) return;
      await context.push('/orders/${order.id}/pay', extra: url);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membuka pembayaran. Coba lagi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeOrdersProvider, (_, next) {
      final orders = next.valueOrNull;
      if (orders != null) ActiveOrderNotification.sync(orders);
    });

    final orders =
        ref.watch(activeOrdersProvider).valueOrNull ?? const <Order>[];
    if (orders.isEmpty || !widget.visible) return const SizedBox.shrink();

    final order = orders.first;
    final others = orders.length - 1;
    final needsPayment = order.needsOnlinePayment;
    final firstItem = order.items.isNotEmpty
        ? order.items.first.productName
        : null;

    final accent = needsPayment ? AppColors.accent : AppColors.primary;

    return Material(
      color: needsPayment ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDFA),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent.withValues(alpha: 0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => others > 0
            ? context.go('/orders')
            : context.push('/orders/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              Icon(
                needsPayment
                    ? Icons.payments_rounded
                    : Icons.local_shipping_rounded,
                color: accent,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      needsPayment
                          ? 'Menunggu pembayaran · ${formatCurrency(order.grandTotal)}'
                          : order.statusLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      others > 0
                          ? '${order.orderNumber} · +$others pesanan aktif lainnya'
                          : [order.orderNumber, ?firstItem].join(' · '),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.mutedForeground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (needsPayment)
                FilledButton(
                  onPressed: _paying ? null : () => _pay(order),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: _paying
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Bayar'),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.mutedForeground,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
