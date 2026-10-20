import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../core/api/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../models/order.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';
import 'order_style.dart';
import 'packing_screen.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  Order? _order;
  Object? _error;
  bool _updating = false;

  /// Set once the status changes, handed back so the list can update its row.
  Order? _changed;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final order = await ref.read(orderServiceProvider).detail(widget.orderId);
      if (mounted) setState(() => _order = order);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _changeStatus(OrderStatus next) async {
    final order = _order!;
    final notes = await showModalBottomSheet<_StatusChange>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _StatusChangeSheet(order: order, next: next),
    );
    if (notes == null || !mounted) return;

    setState(() => _updating = true);
    try {
      final updated = await ref.read(orderServiceProvider).updateStatus(order.id, next, adminNotes: notes.adminNotes);
      if (!mounted) return;
      setState(() => _order = _changed = updated);
      showMessage(context, 'Status diubah menjadi "${next.label}".');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(order?.orderNumber ?? 'Detail Pesanan')),
        body: order == null
            ? (_error != null
                  ? Center(
                      child: ErrorView(message: errorMessage(_error!), onRetry: _load),
                    )
                  : const Center(child: CircularProgressIndicator()))
            : SafeArea(
                top: false,
                child: RefreshIndicator(onRefresh: _load, child: _body(order)),
              ),
        bottomNavigationBar: order == null || order.nextStatuses.isEmpty ? null : _actions(order),
      ),
    );
  }

  Widget _body(Order order) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Section(
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onLongPress: () {
                      Clipboard.setData(ClipboardData(text: order.orderNumber));
                      showMessage(context, 'Nomor pesanan disalin.');
                    },
                    child: Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ),
                OrderStatusBadge(order.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(formatDateTime(order.createdAt), style: const TextStyle(color: AppColors.mutedForeground)),
            const SizedBox(height: 12),
            _Row('Pembeli', order.customerName ?? '-'),
            _Row('Pembayaran', order.paymentMethodName ?? '-', trailing: PaymentStatusBadge(order)),
            if (order.paidAt != null) _Row('Dibayar', formatDateTime(order.paidAt!)),
          ],
        ),
        ?_packagesSection(order),
        const SizedBox(height: 12),
        _Section(
          title: 'Pengiriman',
          children: [
            _Row('Metode', order.shippingMethodName ?? order.deliveryMethod ?? '-'),
            if (order.deliveryDate != null) _Row('Tanggal', formatDate(order.deliveryDate!)),
            if (order.deliverySlotLabel != null) _Row('Slot', order.deliverySlotLabel!),
            if (order.recipientName != null) _Row('Penerima', order.recipientName!),
            if (order.recipientPhone != null)
              _Row(
                'Telepon',
                order.recipientPhone!,
                trailing: IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.call, color: AppColors.primary, size: 20),
                  onPressed: () => launchUrl(Uri.parse('tel:${order.recipientPhone}')),
                ),
              ),
            if (order.fullAddress != null && order.fullAddress!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(order.fullAddress!),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Produk (${order.items.length})',
          children: [
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NetImage(item.imageUrl, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (item.variantName != null)
                            Text(
                              item.variantName!,
                              style: const TextStyle(color: AppColors.mutedForeground, fontSize: 12),
                            ),
                          Text(
                            '${item.quantity} × ${formatCurrency(item.unitPrice)}',
                            style: const TextStyle(color: AppColors.mutedForeground, fontSize: 12),
                          ),
                          if (item.notes != null && item.notes!.isNotEmpty)
                            Text(
                              'Catatan: ${item.notes}',
                              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                        ],
                      ),
                    ),
                    Text(formatCurrency(item.lineTotal), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            const Divider(height: 20),
            _Row('Subtotal', formatCurrency(order.subtotal)),
            if (order.discountTotal > 0) _Row('Diskon', '- ${formatCurrency(order.discountTotal)}'),
            _Row('Ongkir', formatCurrency(order.shippingFee)),
            if (order.serviceFee > 0) _Row('Biaya layanan', formatCurrency(order.serviceFee)),
            _Row('Total', formatCurrency(order.grandTotal), bold: true),
          ],
        ),
        if ((order.customerNotes ?? '').isNotEmpty || (order.adminNotes ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            title: 'Catatan',
            children: [
              if ((order.customerNotes ?? '').isNotEmpty) _Row('Pembeli', order.customerNotes!),
              if ((order.adminNotes ?? '').isNotEmpty) _Row('Admin', order.adminNotes!),
            ],
          ),
        ],
        if (order.history.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            title: 'Riwayat Status',
            children: [
              for (final entry in order.history.reversed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 10, color: orderStatusColor(entry.status)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(entry.status.label)),
                      Text(
                        [
                          if (entry.at != null) formatDateTime(entry.at!),
                          if (entry.byLabel.isNotEmpty) entry.byLabel,
                        ].join(' · '),
                        style: const TextStyle(color: AppColors.mutedForeground, fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _editPackages() async {
    final updated = await Navigator.of(
      context,
    ).push<Order>(MaterialPageRoute(builder: (_) => PackingScreen(order: _order!)));
    if (updated != null && mounted) setState(() => _order = _changed = updated);
  }

  /// Parcels with their contents and, while a driver still has to scan them, one QR each.
  Widget? _packagesSection(Order order) {
    final showQr = order.deliveryMethod != 'store_pickup' && order.status.next().isNotEmpty;
    final packages = order.packages;
    // Older API without parcels: fall back to the single order QR.
    if (packages.isEmpty) {
      if (!showQr || order.qrCode == null) return null;
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: _Section(
          title: 'QR Paket',
          children: [
            Center(child: QrImageView(data: order.qrCode!, size: 180, backgroundColor: Colors.white)),
          ],
        ),
      );
    }
    if (!showQr && !order.canEditPackages && packages.length == 1) return null;

    final items = {for (final item in order.items) item.id: item};

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: _Section(
        title: 'Paket (${packages.length})',
        children: [
          for (final package in packages) ...[
            if (package.number > 1) const Divider(height: 24),
            Text(
              packages.length > 1 ? 'Paket ${package.number} dari ${packages.length}' : 'Paket 1',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            for (final MapEntry(:key, :value) in package.items.entries)
              Text(
                '$value × ${items[key]?.productName ?? '-'}'
                '${items[key]?.variantName != null ? ' (${items[key]!.variantName})' : ''}',
                style: const TextStyle(fontSize: 13),
              ),
            if (showQr && package.qrCode != null) ...[
              const SizedBox(height: 8),
              Center(child: QrImageView(data: package.qrCode!, size: 160, backgroundColor: Colors.white)),
              Center(
                child: Text(
                  '${order.orderNumber} · ${package.number}/${packages.length}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
          if (showQr) ...[
            const SizedBox(height: 8),
            Text(
              packages.length > 1
                  ? 'Tempel QR di paket yang sesuai. Driver scan salah satu QR dan wajib membawa semua ${packages.length} paket.'
                  : 'Driver scan QR ini saat mengambil dan menyerahkan paket.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedForeground, fontSize: 12),
            ),
          ],
          if (order.canEditPackages) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _updating ? null : _editPackages,
              icon: const Icon(Icons.call_split, size: 18),
              label: Text(packages.length > 1 ? 'Ubah Pembagian Paket' : 'Split Paket'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actions(Order order) {
    final forward = order.nextStatuses.where((s) => s != OrderStatus.cancelled).toList();
    final canCancel = order.nextStatuses.contains(OrderStatus.cancelled);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: _updating
            ? const SizedBox(height: 48, child: Center(child: CircularProgressIndicator()))
            : Row(
                children: [
                  if (canCancel)
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.destructive),
                        onPressed: () => _changeStatus(OrderStatus.cancelled),
                        child: const Text('Batalkan'),
                      ),
                    ),
                  // pending offers both "accept" and "start preparing"; keep the
                  // usual first step prominent and the shortcut secondary.
                  for (final (i, status) in forward.indexed) ...[
                    if (canCancel || i > 0) const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: i == 0
                          ? FilledButton(onPressed: () => _changeStatus(status), child: Text(status.actionLabel))
                          : OutlinedButton(onPressed: () => _changeStatus(status), child: Text(status.actionLabel)),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _StatusChange {
  _StatusChange(this.adminNotes);

  final String? adminNotes;
}

class _StatusChangeSheet extends StatefulWidget {
  const _StatusChangeSheet({required this.order, required this.next});

  final Order order;
  final OrderStatus next;

  @override
  State<_StatusChangeSheet> createState() => _StatusChangeSheetState();
}

class _StatusChangeSheetState extends State<_StatusChangeSheet> {
  late final _notes = TextEditingController(text: widget.order.adminNotes);

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cancelling = widget.next == OrderStatus.cancelled;
    final paid = widget.order.paymentStatus == 'paid';

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            cancelling ? 'Batalkan pesanan?' : 'Ubah status ke "${widget.next.label}"?',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            cancelling
                ? 'Stok produk dikembalikan${paid ? ' dan dana ${formatCurrency(widget.order.grandTotal)} dikembalikan ke saldo pembeli' : ''}. Tindakan ini tidak dapat dibatalkan.'
                : 'Pembeli akan menerima notifikasi perubahan status.',
            style: const TextStyle(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notes,
            maxLines: 3,
            minLines: 2,
            decoration: InputDecoration(
              labelText: cancelling ? 'Alasan / catatan admin (opsional)' : 'Catatan admin (opsional)',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: cancelling ? FilledButton.styleFrom(backgroundColor: AppColors.destructive) : null,
            onPressed: () {
              final text = _notes.text.trim();
              // Only send the notes when they changed, so a status change never clears them by accident.
              final changed = text != (widget.order.adminNotes ?? '');
              Navigator.pop(context, _StatusChange(changed ? text : null));
            },
            child: Text(cancelling ? 'Ya, Batalkan' : widget.next.actionLabel),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
          ],
          ...children,
        ],
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.trailing, this.bold = false});

  final String label;
  final String value;
  final Widget? trailing;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(color: AppColors.mutedForeground)),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: trailing == null ? TextAlign.right : TextAlign.left,
            style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}
