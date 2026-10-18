import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/order.dart';
import '../../providers/core_providers.dart';
import 'order_providers.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  /// For status history entries; the current status uses [Order.statusLabel].
  static const _statusLabels = {
    'pending': 'Pesanan dibuat',
    'accepted': 'Diterima',
    'processing': 'Pesanan sedang disiapkan',
    'ready': 'Siap Dikirim/Diambil',
    'completed': 'Selesai',
    'cancelled': 'Dibatalkan',
  };

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref, Order order) async {
    final paid = order.paymentStatus == 'paid';
    final notifier = ref.read(orderCancelProvider.notifier);

    // While being prepared, pause the countdown so reading the terms doesn't eat the window.
    final held = order.cancelDeadline != null;
    if (held && !await notifier.hold(orderId)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(orderCancelProvider).error ?? 'Gagal membatalkan pesanan.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      // No dismissing by tapping outside when the choice is money-related or final.
      barrierDismissible: !paid && !held,
      builder: (context) => paid
          ? _RefundToBalanceConfirmDialog(amount: order.grandTotal, finalChoice: held)
          : AlertDialog(
              title: const Text('Batalkan Pesanan'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Apakah Anda yakin ingin membatalkan pesanan ini?'),
                  if (held) ...[const SizedBox(height: 12), const _FinalChoiceNote()],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(held ? 'Jangan Batalkan' : 'Tidak'),
                ),
                TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Ya, Batalkan')),
              ],
            ),
    );

    if (confirmed != true) {
      if (held) {
        await notifier.decline(orderId);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pesanan dilanjutkan dan tidak bisa dibatalkan lagi.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final success = await notifier.cancel(orderId);
    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(paid
              ? 'Pesanan dibatalkan. ${formatCurrency(order.grandTotal)} sudah masuk ke Saldo Belanja.'
              : 'Pesanan berhasil dibatalkan.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final error = ref.read(orderCancelProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Gagal membatalkan pesanan.'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _pay(BuildContext context, WidgetRef ref) async {
    try {
      final order = await ref.read(checkoutServiceProvider).payOrder(orderId);
      if (!context.mounted) return;
      final url = order.paymentRedirectUrl;
      if (url == null) throw Exception('Link pembayaran tidak tersedia.');
      await context.push('/orders/$orderId/pay', extra: url);
      ref.invalidate(orderDetailProvider(orderId));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka pembayaran. Coba lagi.'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));
    final cancelState = ref.watch(orderCancelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pesanan')),
      body: orderAsync.when(
        data: (order) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          order.orderNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        order.statusLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Produk',
              child: Column(
                children: [
                  for (final item in order.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.productName, style: const TextStyle(fontSize: 13)),
                                if (item.variantName != null)
                                  Text(item.variantName!, style: const TextStyle(fontSize: 11.5, color: AppColors.mutedForeground)),
                                Text('${item.quantity} x ${formatCurrency(item.unitPrice)}',
                                    style: const TextStyle(fontSize: 11.5, color: AppColors.mutedForeground)),
                              ],
                            ),
                          ),
                          Text(formatCurrency(item.lineTotal), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Ringkasan Pembayaran',
              child: Column(
                children: [
                  _SummaryRow('Subtotal', order.subtotal),
                  if (order.discountTotal > 0) _SummaryRow('Diskon', -order.discountTotal),
                  _SummaryRow('Ongkos Kirim', order.shippingFee),
                  if (order.serviceFee > 0) _SummaryRow('Biaya Layanan', order.serviceFee),
                  if (order.taxTotal > 0) _SummaryRow('Pajak', order.taxTotal),
                  const Divider(height: 20),
                  _SummaryRow('Total', order.grandTotal, bold: true),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (order.paymentMethod != null)
              _SectionCard(
                title: 'Metode Pembayaran',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.paymentMethod!.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    if (order.paymentMethod!.bankName != null) ...[
                      const SizedBox(height: 4),
                      Text('${order.paymentMethod!.bankName} - ${order.paymentMethod!.accountNumber ?? ''}',
                          style: const TextStyle(fontSize: 12.5)),
                      if (order.paymentMethod!.accountHolderName != null)
                        Text('a.n. ${order.paymentMethod!.accountHolderName}',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.mutedForeground)),
                    ],
                    if (order.paymentMethod!.instructions != null) ...[
                      const SizedBox(height: 6),
                      Text(order.paymentMethod!.instructions!, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      switch (order.paymentStatus) {
                        'paid' => 'Sudah dibayar',
                        'refunded' => 'Dana dikembalikan ke Saldo Inovasi',
                        'failed' => 'Pembayaran gagal / kedaluwarsa',
                        _ => 'Belum dibayar',
                      },
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: switch (order.paymentStatus) {
                          'paid' || 'refunded' => AppColors.success,
                          'failed' => AppColors.mutedForeground,
                          _ => AppColors.primary,
                        },
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (order.shippingMethod != null) ...[
              _SectionCard(
                title: 'Pengiriman',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.shippingMethod!.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    if (order.deliverySchedule != null) ...[
                      const SizedBox(height: 4),
                      Text('Jadwal: ${order.deliverySchedule!}', style: const TextStyle(fontSize: 12.5)),
                    ] else if (order.shippingMethod!.estimatedDeliveryTime != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Estimasi: ${order.shippingMethod!.estimatedDeliveryTime!}',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.mutedForeground),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (order.deliveryAddress != null)
              _SectionCard(
                title: 'Alamat Pengiriman',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.deliveryAddress!['recipient_name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(order.deliveryAddress!['recipient_phone']?.toString() ?? '', style: const TextStyle(fontSize: 12.5)),
                    const SizedBox(height: 4),
                    Text(
                      [
                        order.deliveryAddress!['address_detail'],
                        order.deliveryAddress!['village_name'],
                        order.deliveryAddress!['district_name'],
                        order.deliveryAddress!['city_name'],
                        order.deliveryAddress!['province_name'],
                      ].where((e) => e != null && e.toString().isNotEmpty).join(', '),
                      style: const TextStyle(fontSize: 12.5, color: AppColors.mutedForeground),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (order.statusHistory.isNotEmpty)
              _SectionCard(
                title: 'Riwayat Status',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in order.statusHistory.reversed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${_statusLabels[entry.status] ?? entry.status} · ${entry.at}',
                          style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                        ),
                      ),
                  ],
                ),
              ),
            if (order.needsOnlinePayment) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _pay(context, ref),
                  child: const Text('Bayar Sekarang'),
                ),
              ),
            ],
            // While being prepared the button stays visible, greyed out once cancelling has closed.
            if (order.canCancel || order.status == 'processing') ...[
              const SizedBox(height: 12),
              _CancelOrderButton(
                closed: !order.canCancel,
                deadline: order.cancelDeadline,
                frozenSeconds: order.cancelOnHold ? order.cancelSecondsLeft : null,
                cancelling: cancelState.cancelling,
                onPressed: () => _confirmCancel(context, ref, order),
              ),
            ],
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Gagal memuat pesanan: $error')),
      ),
    );
  }
}

/// Tells the buyer that "Jangan Batalkan" is final while the order is being prepared.
class _FinalChoiceNote extends StatelessWidget {
  const _FinalChoiceNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 18, color: AppColors.mutedForeground),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            const TextSpan(
              children: [
                TextSpan(text: 'Jika memilih '),
                TextSpan(text: 'Jangan Batalkan', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: ', pesanan lanjut dikemas dan '),
                TextSpan(text: 'tidak bisa dibatalkan lagi', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: '.'),
              ],
            ),
            style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
          ),
        ),
      ],
    );
  }
}

/// Hard confirmation for cancelling a paid order: the refund lands in Saldo Belanja
/// and cannot be withdrawn, so the buyer must tick an acknowledgement first.
class _RefundToBalanceConfirmDialog extends StatefulWidget {
  const _RefundToBalanceConfirmDialog({required this.amount, this.finalChoice = false});

  final double amount;

  /// Backing out ends the buyer's chance to cancel (order already being prepared).
  final bool finalChoice;

  @override
  State<_RefundToBalanceConfirmDialog> createState() => _RefundToBalanceConfirmDialogState();
}

class _RefundToBalanceConfirmDialogState extends State<_RefundToBalanceConfirmDialog> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;

    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: error, size: 40),
      title: const Text('Yakin batalkan pesanan?', textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Dana '),
                  TextSpan(
                    text: formatCurrency(widget.amount),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' akan dikembalikan ke '),
                  const TextSpan(text: 'Saldo Belanja', style: TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: ' kamu, bukan ke rekening atau metode pembayaran asal.'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: error.withValues(alpha: 0.08),
                border: Border.all(color: error.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.block, color: error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Saldo Belanja TIDAK BISA dicairkan, ditarik tunai, atau ditransfer ke rekening bank. '
                      'Saldo hanya bisa dipakai untuk belanja di aplikasi.',
                      style: TextStyle(color: error, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              value: _acknowledged,
              onChanged: (v) => setState(() => _acknowledged = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: const Text(
                'Saya mengerti dana masuk ke Saldo Belanja dan tidak bisa dicairkan ke bank.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            if (widget.finalChoice) const _FinalChoiceNote(),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Jangan Batalkan')),
        FilledButton(
          onPressed: _acknowledged ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(backgroundColor: error),
          child: const Text('Ya, Batalkan'),
        ),
      ],
    );
  }
}

/// Cancel button; with a [deadline] it counts down and turns greyed out once the window closes.
class _CancelOrderButton extends StatefulWidget {
  const _CancelOrderButton({
    required this.closed,
    required this.deadline,
    required this.cancelling,
    required this.onPressed,
    this.frozenSeconds,
  });

  /// Cancelling has closed (window over or the buyer backed out): shown greyed out.
  final bool closed;

  final DateTime? deadline;

  /// Set while the countdown is paused (cancel confirmation open): shown as-is, no ticking.
  final int? frozenSeconds;
  final bool cancelling;
  final VoidCallback onPressed;

  @override
  State<_CancelOrderButton> createState() => _CancelOrderButtonState();
}

class _CancelOrderButtonState extends State<_CancelOrderButton> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(_CancelOrderButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline || oldWidget.frozenSeconds != widget.frozenSeconds) _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.deadline == null || widget.frozenSeconds != null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {});
      if (!DateTime.now().isBefore(widget.deadline!)) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deadline = widget.deadline;
    final frozen = widget.frozenSeconds;
    final left = frozen != null ? Duration(seconds: frozen) : deadline?.difference(DateTime.now());
    final closed = widget.closed || (frozen == null && left != null && left <= Duration.zero);

    if (closed) {
      // Greyed out but still tappable, so the buyer learns why nothing happens.
      final muted = AppColors.mutedForeground;
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Pesanan sedang dikemas dan tidak bisa dibatalkan.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                ),
              style: OutlinedButton.styleFrom(
                foregroundColor: muted,
                backgroundColor: muted.withValues(alpha: 0.08),
                side: BorderSide(color: muted.withValues(alpha: 0.3)),
              ),
              child: const Text('Batalkan Pesanan'),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pesanan sudah tidak bisa dibatalkan.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
      );
    }

    final secondsLeft = left == null ? null : (left.inMilliseconds / 1000).ceil();
    final countdown = secondsLeft == null
        ? null
        : '${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}';

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: widget.cancelling ? null : widget.onPressed,
            style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: widget.cancelling
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(countdown == null ? 'Batalkan Pesanan' : 'Batalkan Pesanan ($countdown)'),
          ),
        ),
        if (countdown != null) ...[
          const SizedBox(height: 6),
          Text(
            frozen != null
                ? 'Waktu pembatalan dijeda, sisa $countdown.'
                : 'Pesanan sedang dikemas. Kamu masih bisa membatalkan dalam $countdown.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
          ),
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.amount, {this.bold = false});

  final String label;
  final double amount;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: bold ? 14 : 12.5, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          ),
          const SizedBox(width: 8),
          Text(
            formatCurrency(amount),
            style: TextStyle(
              fontSize: bold ? 15 : 12.5,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: bold ? AppColors.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
