import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/order_tracking.dart';
import '../../providers/core_providers.dart';
import 'order_providers.dart';

const _trackingPollInterval = Duration(seconds: 10);

/// With the socket connected, poll only every Nth tick (60s) as a safety net.
const _liveSafetyPollEvery = 6;

const _courierMarker = MarkerId('courier');

/// "Lacak Pengiriman": the courier's latest position on a map, refreshed when the driver app reports
/// a new fix (signal on `order-tracking.{id}`) or by polling while the socket is down.
class OrderTrackingScreen extends ConsumerStatefulWidget {
  const OrderTrackingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> with WidgetsBindingObserver {
  OrderTracking? _tracking;
  String? _error;
  GoogleMapController? _map;
  Timer? _pollTimer;
  VoidCallback? _unlisten;
  int _ticks = 0;

  /// The map follows the courier until the buyer pans it themselves.
  bool _follow = true;

  /// Set while the camera moves on our own command, so that move doesn't count as the buyer panning.
  bool _animating = false;

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
    _map?.dispose();
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
      final location = tracking.location;
      if (_follow && location != null) _moveCamera(CameraUpdate.newLatLng(LatLng(location.latitude, location.longitude)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memuat lokasi kurir.');
    }
  }

  void _recenter() {
    final location = _tracking?.location;
    if (location == null) return;
    setState(() => _follow = true);
    _moveCamera(CameraUpdate.newLatLngZoom(LatLng(location.latitude, location.longitude), 16));
  }

  void _moveCamera(CameraUpdate update) {
    final map = _map;
    if (map == null) return;
    _animating = true;
    map.animateCamera(update);
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
    final location = tracking.location;
    if (location == null) {
      return const _Message(
        icon: Icons.location_searching,
        text: 'Menunggu lokasi kurir. Peta tampil setelah aplikasi kurir mengirim posisinya.',
      );
    }

    final position = LatLng(location.latitude, location.longitude);
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: position, zoom: 16),
          onMapCreated: (controller) => _map = controller,
          // A pan or zoom by the buyer stops the camera from snapping back to the courier.
          onCameraMoveStarted: () {
            if (!_animating && _follow) setState(() => _follow = false);
          },
          onCameraIdle: () => _animating = false,
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
          zoomControlsEnabled: false,
          markers: {
            Marker(
              markerId: _courierMarker,
              position: position,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              infoWindow: InfoWindow(title: tracking.driver?.name ?? 'Kurir'),
            ),
          },
          circles: {
            if (location.accuracy != null && location.accuracy! > 20)
              Circle(
                circleId: const CircleId('accuracy'),
                center: position,
                radius: location.accuracy!,
                strokeWidth: 1,
                strokeColor: AppColors.primary.withValues(alpha: 0.4),
                fillColor: AppColors.primary.withValues(alpha: 0.1),
              ),
          },
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: FloatingActionButton.small(
            heroTag: null,
            onPressed: _recenter,
            tooltip: 'Ke posisi kurir',
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
