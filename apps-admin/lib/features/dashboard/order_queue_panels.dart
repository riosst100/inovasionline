import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../core/api/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../models/order_queue.dart';
import '../../models/shipping_method.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';
import '../orders/order_style.dart';

final instantOrdersProvider = FutureProvider.autoDispose<InstantOrderQueue>(
  (ref) => ref.watch(orderServiceProvider).instant(),
);

/// Keyed by delivery date (WIB, yyyy-MM-dd).
final scheduledOrdersProvider = FutureProvider.autoDispose.family<ScheduledOrders, String>(
  (ref, date) => ref.watch(orderServiceProvider).scheduled(date),
);

final shippingMethodsProvider = FutureProvider.autoDispose<List<ShippingMethod>>(
  (ref) => ref.watch(deliveryScheduleServiceProvider).shippingMethods(),
);

/// Current wall-clock time in WIB (UTC+7), whatever the device timezone.
DateTime _nowWib() => DateTime.now().toUtc().add(const Duration(hours: 7));

/// Ticking clock: "12:05", "1:04:09", "7h 04:12:05" (h = hari).
String _formatClock(Duration d) {
  final s = d.isNegative ? 0 : d.inSeconds;
  final days = s ~/ 86400;
  final hours = (s % 86400) ~/ 3600;
  String pad(int n) => n.toString().padLeft(2, '0');
  final mmss = '${pad((s % 3600) ~/ 60)}:${pad(s % 60)}';
  if (days > 0) return '${days}h ${pad(hours)}:$mmss';
  return hours > 0 ? '$hours:$mmss' : mmss;
}

enum _Urgency { late, soon, ok }

/// Red once past the ship-by limit, orange from half of it (same as the web admin).
_Urgency _urgency(DateTime deadline, int dispatchMinutes, DateTime now) {
  final left = deadline.difference(now);
  if (left.isNegative) return _Urgency.late;
  return left.inSeconds <= dispatchMinutes * 30 ? _Urgency.soon : _Urgency.ok;
}

Color _urgencyColor(_Urgency level) => switch (level) {
  _Urgency.late => AppColors.destructive,
  _Urgency.soon => AppColors.accent,
  _Urgency.ok => AppColors.success,
};

/// Card with an icon title, subtitle and optional trailing action, like the web dashboard panels.
class _Panel extends StatelessWidget {
  const _Panel({required this.icon, required this.iconColor, required this.title, required this.child, this.subtitle, this.trailing});

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 18, color: iconColor),
                        const SizedBox(width: 6),
                        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: const TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        const Divider(height: 1),
        child,
      ],
    ),
  );
}

class _PanelMessage extends StatelessWidget {
  const _PanelMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.mutedForeground, fontSize: 13),
    ),
  );
}

class _PanelError extends StatelessWidget {
  const _PanelError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      children: [
        Text(errorMessage(error), style: const TextStyle(color: AppColors.mutedForeground, fontSize: 13)),
        TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
      ],
    ),
  );
}

const _panelLoading = Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));

/// Order number + status badge over "customer · total"; tapping opens the order.
class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, required this.trailing, this.tint});

  final QueuedOrder order;
  final Widget trailing;
  final Color? tint;

  @override
  Widget build(BuildContext context) => Material(
    color: tint ?? Colors.transparent,
    child: InkWell(
      onTap: () => context.push('/order/${order.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.w700)),
                      OrderStatusBadge(order.status),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${order.customer ?? '-'} · ${formatCurrency(order.grandTotal)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.mutedForeground, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            trailing,
          ],
        ),
      ),
    ),
  );
}

/// Every shipping method with a switch to turn it on/off at checkout.
class ShippingMethodsPanel extends ConsumerStatefulWidget {
  const ShippingMethodsPanel({super.key});

  @override
  ConsumerState<ShippingMethodsPanel> createState() => _ShippingMethodsPanelState();
}

class _ShippingMethodsPanelState extends ConsumerState<ShippingMethodsPanel> {
  /// Methods with a toggle request in flight; their switch is disabled meanwhile.
  final _busy = <String>{};

  Future<void> _toggle(ShippingMethod method) async {
    if (method.isEnabled) {
      final ok = await confirm(
        context,
        title: 'Matikan metode pengiriman',
        message: '"${method.name}" tidak akan muncul lagi di checkout pembeli. Lanjutkan?',
        confirmLabel: 'Matikan',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }

    setState(() => _busy.add(method.id));
    try {
      final updated = await ref.read(deliveryScheduleServiceProvider).toggleShippingMethod(method.id);
      if (mounted) {
        showMessage(context, '${updated.name} ${updated.isEnabled ? 'diaktifkan' : 'dimatikan'}.');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      ref.invalidate(shippingMethodsProvider);
      if (mounted) setState(() => _busy.remove(method.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final methods = ref.watch(shippingMethodsProvider);

    return _Panel(
      icon: Icons.local_shipping_outlined,
      iconColor: AppColors.primary,
      title: 'Metode Pengiriman',
      child: switch (methods) {
        AsyncValue(:final value?) when value.isEmpty => const _PanelMessage('Belum ada metode pengiriman.'),
        AsyncValue(:final value?) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, method) in value.indexed) ...[
              if (index > 0) const Divider(height: 1),
              _methodRow(method),
            ],
          ],
        ),
        AsyncValue(:final error?) => _PanelError(error: error, onRetry: () => ref.invalidate(shippingMethodsProvider)),
        _ => _panelLoading,
      },
    );
  }

  Widget _methodRow(ShippingMethod method) {
    final busy = _busy.contains(method.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(method.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    StatusBadge(
                      label: method.requiresSchedule ? 'Terjadwal' : 'Instan',
                      color: method.requiresSchedule ? AppColors.info : AppColors.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  method.isEnabled ? 'Aktif' : 'Nonaktif',
                  style: TextStyle(
                    color: method.isEnabled ? AppColors.success : AppColors.mutedForeground,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: method.isEnabled, onChanged: busy ? null : (_) => _toggle(method)),
        ],
      ),
    );
  }
}

/// Every waiting instant order with a ticking wait timer, tinted green → orange → red.
class InstantOrdersPanel extends ConsumerStatefulWidget {
  const InstantOrdersPanel({super.key});

  @override
  ConsumerState<InstantOrdersPanel> createState() => _InstantOrdersPanelState();
}

class _InstantOrdersPanelState extends ConsumerState<InstantOrdersPanel> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(instantOrdersProvider);

    return _Panel(
      icon: Icons.bolt,
      iconColor: AppColors.warning,
      title: 'Pesanan Instan',
      trailing: IconButton(
        tooltip: 'Buka Pesanan',
        onPressed: () => context.go('/orders'),
        icon: const Icon(Icons.open_in_new, size: 18),
      ),
      child: switch (queue) {
        AsyncValue(:final value?) => _list(value),
        AsyncValue(:final error?) => _PanelError(error: error, onRetry: () => ref.invalidate(instantOrdersProvider)),
        _ => _panelLoading,
      },
    );
  }

  Widget _list(InstantOrderQueue queue) {
    if (queue.count == 0) return const _PanelMessage('Tidak ada pesanan instan yang menunggu dikirim.');

    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, order) in queue.orders.indexed) ...[
          if (index > 0) const Divider(height: 1),
          _instantRow(order, queue.dispatchMinutes, now),
        ],
        if (queue.count > queue.orders.length) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              '+${queue.count - queue.orders.length} pesanan lainnya di halaman Pesanan.',
              style: const TextStyle(color: AppColors.mutedForeground, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  Widget _instantRow(QueuedOrder order, int dispatchMinutes, DateTime now) {
    final deadline = order.deadlineAt ?? order.createdAt.add(Duration(minutes: dispatchMinutes));
    final level = _urgency(deadline, dispatchMinutes, now);
    final color = _urgencyColor(level);

    return _OrderRow(
      order: order,
      tint: level == _Urgency.ok ? null : color.withValues(alpha: 0.06),
      trailing: Container(
        constraints: const BoxConstraints(minWidth: 84),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.timer_outlined, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              _formatClock(now.difference(order.createdAt)),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scheduled orders of today / tomorrow, filterable per delivery slot.
class ScheduledOrdersPanel extends ConsumerStatefulWidget {
  const ScheduledOrdersPanel({super.key});

  @override
  ConsumerState<ScheduledOrdersPanel> createState() => _ScheduledOrdersPanelState();
}

class _ScheduledOrdersPanelState extends ConsumerState<ScheduledOrdersPanel> {
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  /// 0 = hari ini, 1 = besok.
  int _offset = 0;

  /// Selected slot id; null = semua jam.
  String? _slot;

  /// Delivery date in WIB for the selected day.
  String get _date => _dateFormat.format(_nowWib().add(Duration(days: _offset)));

  @override
  Widget build(BuildContext context) {
    final date = _date;
    final data = ref.watch(scheduledOrdersProvider(date));

    return _Panel(
      icon: Icons.event_available_outlined,
      iconColor: AppColors.info,
      title: 'Pesanan Terjadwal',
      subtitle: 'Pesanan dengan jadwal kirim, per slot jam pengiriman.',
      trailing: IconButton(
        tooltip: 'Buka Pesanan',
        onPressed: () => context.go('/orders'),
        icon: const Icon(Icons.open_in_new, size: 18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('Hari ini')),
                ButtonSegment(value: 1, label: Text('Besok')),
              ],
              selected: {_offset},
              onSelectionChanged: (s) => setState(() {
                _offset = s.first;
                _slot = null;
              }),
            ),
          ),
          switch (data) {
            AsyncValue(:final value?) => _content(value),
            AsyncValue(:final error?) => _PanelError(
              error: error,
              onRetry: () => ref.invalidate(scheduledOrdersProvider(date)),
            ),
            _ => _panelLoading,
          },
        ],
      ),
    );
  }

  Widget _content(ScheduledOrders data) {
    final clock = DateFormat('HH:mm').format(_nowWib());
    final slots = {for (final s in data.slots) s.id: s};
    final orders = data.orders.where((o) => _slot == null || o.deliveryScheduleId == _slot).toList();
    final day = _offset == 0 ? 'hari ini' : 'besok';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text('Semua jam · ${data.count}'),
                selected: _slot == null,
                onSelected: (_) => setState(() => _slot = null),
              ),
              for (final s in data.slots) _slotChip(s, clock),
            ],
          ),
        ),
        const Divider(height: 1),
        if (orders.isEmpty)
          _PanelMessage('Tidak ada pesanan terjadwal ${_slot == null ? '' : 'di slot ini '}untuk $day.')
        else
          for (final (index, order) in orders.indexed) ...[
            if (index > 0) const Divider(height: 1),
            _OrderRow(
              order: order,
              trailing: switch (slots[order.deliveryScheduleId]) {
                final slot? => StatusBadge(label: '${slot.label} · ${slot.timeRange}', color: AppColors.info),
                null => const SizedBox.shrink(),
              },
            ),
          ],
      ],
    );
  }

  Widget _slotChip(DeliverySlotCount s, String clock) {
    final [start, end] = switch (s.timeRange.split(' - ')) {
      [final a, final b] => [a, b],
      _ => ['', ''],
    };
    final running = _offset == 0 && start.isNotEmpty && clock.compareTo(start) >= 0 && clock.compareTo(end) < 0;
    final full = s.quota != null && s.count >= s.quota!;

    return ChoiceChip(
      tooltip: s.shippingMethod,
      selected: _slot == s.id,
      onSelected: (_) => setState(() => _slot = s.id),
      avatar: running ? const Icon(Icons.circle, size: 8, color: AppColors.success) : null,
      label: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '${s.label} '),
            TextSpan(
              text: '${s.timeRange} ',
              style: const TextStyle(color: AppColors.mutedForeground),
            ),
            TextSpan(
              text: s.quota == null ? '${s.count}' : '${s.count}/${s.quota}',
              style: TextStyle(fontWeight: FontWeight.w800, color: full ? AppColors.warning : null),
            ),
          ],
        ),
      ),
    );
  }
}
