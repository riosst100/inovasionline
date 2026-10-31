import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/order_tracking.dart';
import '../../providers/core_providers.dart';
import 'order_providers.dart';
import 'tracking_map.dart';

const _trackingPollInterval = Duration(seconds: 10);

/// With the socket connected, poll only every Nth tick (60s) as a safety net.
const _liveSafetyPollEvery = 6;

/// "Lacak Pengiriman": the courier, the buyer's location and the road between them on a map,
/// refreshed when the driver app reports a new fix (signal on `order-tracking.{id}`) or by polling
/// while the socket is down.
class OrderTrackingScreen extends ConsumerStatefulWidget {
  const OrderTrackingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> with WidgetsBindingObserver {
  OrderTracking? _tracking;
  String? _error;
  Timer? _pollTimer;
  VoidCallback? _unlisten;
  int _ticks = 0;

  /// The map keeps courier and destination in view until the buyer pans it themselves.
  bool _follow = true;

  /// Bumped by the recenter button to frame courier and destination again.
  int _fitRequest = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _startPolling();
    _unlisten = ref.read(realtimeProvider).listen('order-tracking.${widget.orderId}', 'tracking.updated', _load);
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_trackingPollInterval, (_) {
      if (ref.read(realtimeProvider).connected.value && ++_ticks % _liveSafetyPollEvery != 0) {
        // Still repaint so "diperbarui x detik lalu" keeps counting.
        if (mounted) setState(() {});
        return;
      }
      _load();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _load();
    } else if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unlisten?.call();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final tracking = await ref.read(orderServiceProvider).tracking(widget.orderId);
      if (!mounted) return;
      final wasActive = _tracking?.active ?? true;
      setState(() {
        _tracking = tracking;
        _error = null;
      });
      // Delivered (or otherwise moved on) while watching: the detail screen behind shows the new status.
      if (wasActive && !tracking.active) ref.invalidate(orderDetailProvider(widget.orderId));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memuat lokasi kurir.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracking = _tracking;

    return Scaffold(
      appBar: AppBar(title: const Text('Lacak Pengiriman')),
      body: switch (tracking) {
        null when _error != null => _Message(icon: Icons.error_outline, text: _error!, onRetry: _load),
        null => const Center(child: CircularProgressIndicator()),
        _ when !tracking.active => _Message(
            icon: tracking.status == 'completed' ? Icons.check_circle_outline : Icons.local_shipping_outlined,
            text: switch (tracking.status) {
              'completed' => 'Pesanan sudah diterima. Pelacakan selesai.',
              'cancelled' => 'Pesanan dibatalkan.',
              _ => 'Pesanan belum diantar kurir. Lokasi kurir muncul di sini saat pesanan dalam pengantaran.',
            },
          ),
        _ => Column(
            children: [
              Expanded(child: _buildMap(tracking)),
              _CourierPanel(tracking: tracking, error: _error),
            ],
          ),
      },
    );
  }

  Widget _buildMap(OrderTracking tracking) {
    if (tracking.location == null) {
      return const _Message(
        icon: Icons.location_searching,
        text: 'Menunggu lokasi kurir. Peta tampil setelah aplikasi kurir mengirim posisinya.',
      );
    }

    return Stack(
      children: [
        TrackingMap(
          tracking: tracking,
          follow: _follow,
          onUserMoved: () => setState(() => _follow = false),
          fitRequest: _fitRequest,
        ),
        Positioned(
          right: 12,
          bottom: 32,
          child: FloatingActionButton.small(
            heroTag: null,
            onPressed: () => setState(() {
              _follow = true;
              _fitRequest++;
            }),
            tooltip: 'Tampilkan kurir & tujuan',
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}

class _CourierPanel extends StatelessWidget {
  const _CourierPanel({required this.tracking, this.error});

  final OrderTracking tracking;
  final String? error;

  /// e.g. "± 3,2 km · sekitar 12 menit lagi"; only the distance (as the crow flies) without a road route.
  static String? _remainingLabel(OrderTracking tracking) {
    final meters = tracking.remainingMeters;
    if (meters == null) return null;
    final distance = meters < 1000
        ? '${(meters / 10).round() * 10} m'
        : '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
    final route = tracking.route;
    if (route == null) return '± $distance dari lokasi kamu';
    final minutes = (route.durationSeconds / 60).ceil();
    return '± $distance · ${minutes <= 1 ? 'sebentar lagi sampai' : 'sekitar $minutes menit lagi'}';
  }

  Future<void> _call(BuildContext context, String phone) async {
    final opened = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka aplikasi telepon.'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final driver = tracking.driver;
    final location = tracking.location;
    final vehicle = [driver?.vehicleType, driver?.vehiclePlateNumber]
        .where((e) => e != null && e.isNotEmpty)
        .join(' · ');
    final phone = driver?.phone;
    final remaining = _remainingLabel(tracking);

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
        child: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.two_wheeler)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(driver?.name ?? 'Kurir', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  if (vehicle.isNotEmpty)
                    Text(vehicle, style: const TextStyle(fontSize: 12.5, color: AppColors.mutedForeground)),
                  if (remaining != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      remaining,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    error ??
                        (location == null
                            ? 'Pesanan sedang diantar'
                            : 'Lokasi diperbarui ${formatRelativeTime(location.updatedAt).toLowerCase()}'),
                    style: TextStyle(
                      fontSize: 12,
                      color: error != null ? Theme.of(context).colorScheme.error : AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            if (phone != null && phone.isNotEmpty)
              IconButton.filledTonal(
                onPressed: () => _call(context, phone),
                tooltip: 'Telepon kurir',
                icon: const Icon(Icons.call),
              ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.mutedForeground),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.mutedForeground)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
            ],
          ],
        ),
      ),
    );
  }
}
