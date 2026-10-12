import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../core/utils/formatters.dart';
import 'order_providers.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  static const _statusLabels = {
    'pending': 'Menunggu Konfirmasi',
    'accepted': 'Diterima',
    'processing': 'Diproses',
    'ready': 'Siap Dikirim/Diambil',
    'completed': 'Selesai',
    'cancelled': 'Dibatalkan',
  };

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan Pesanan'),
        content: const Text('Apakah Anda yakin ingin membatalkan pesanan ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Tidak')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Ya, Batalkan')),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await ref.read(orderCancelProvider.notifier).cancel(orderId);
    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pesanan berhasil dibatalkan.'), behavior: SnackBarBehavior.floating),
      );
    } else {
      final error = ref.read(orderCancelProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Gagal membatalkan pesanan.'), behavior: SnackBarBehavior.floating),
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
                      Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(
                        _statusLabels[order.status] ?? order.status,
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
                      order.paymentStatus == 'paid' ? 'Sudah dibayar' : 'Belum dibayar',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: order.paymentStatus == 'paid' ? AppColors.success : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
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
            if (order.isPending) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: cancelState.cancelling ? null : () => _confirmCancel(context, ref),
                  style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                  child: cancelState.cancelling
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Batalkan Pesanan'),
                ),
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
          Text(label, style: TextStyle(fontSize: bold ? 14 : 12.5, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
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
