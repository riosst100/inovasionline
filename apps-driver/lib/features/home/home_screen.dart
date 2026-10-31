import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../core/permissions.dart';
import '../../models/parcel.dart';
import '../../providers/providers.dart';
import '../../services/delivery_tracker.dart';
import '../scan/confirm_screen.dart';
import 'account_screen.dart';
import 'dashboard_screen.dart';
import 'orders_screen.dart';

/// Bottom-navigation shell: Dashboard, Pesanan and Akun. While signed in it also shares the driver's
/// location for as long as there are parcels on the way (see [DeliveryTracker]).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;
  late final DeliveryTracker _tracker;
  StreamSubscription<Uri>? _links;

  /// A parcel QR opened from the phone camera: iodriver://scan?code=... (see the admin page /d/[code]).
  Future<void> _openLink(Uri uri) async {
    final code = uri.queryParameters['code'];
    if (uri.scheme != 'iodriver' || code == null || !mounted) return;
    try {
      final parcel = await ref.read(deliveryServiceProvider).scan(code);
      if (!mounted) return;
      if (parcel.action == ParcelAction.none) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${parcel.orderNumber} tidak bisa diproses saat ini.')));
        return;
      }
      if (!await ensureLocationReady(context) || !mounted) return;
      await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ConfirmScreen(parcel: parcel, code: code)));
      ref.invalidate(readyParcelsProvider);
      ref.invalidate(parcelsProvider(false));
      ref.invalidate(parcelsProvider(true));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  @override
  void initState() {
    super.initState();
    final links = AppLinks();
    // Cold start (link opened the app) and warm start (app already running).
    links.getInitialLink().then((uri) {
      if (uri != null) _openLink(uri);
    });
    _links = links.uriLinkStream.listen(_openLink);
    _tracker = ref.read(deliveryTrackerProvider);
    // The "Perlu Dikirim" list refreshes after every scan: first pickup starts tracking, last handover stops it.
    ref.listenManual(parcelsProvider(false), fireImmediately: true, (_, next) {
      final parcels = next.valueOrNull;
      if (parcels == null) return;
      parcels.isEmpty ? _tracker.stop() : _tracker.start();
    });
  }

  @override
  void dispose() {
    _links?.cancel();
    _tracker.stop(); // signed out
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(onOpenOrders: () => setState(() => _index = 1)),
          const OrdersScreen(),
          const AccountScreen(),
        ],
      ),
      floatingActionButton: _index == 2
          ? null
          : Consumer(
              builder: (context, ref, _) => FloatingActionButton.extended(
                onPressed: () => openScan(context, ref),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR'),
              ),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Pesanan',
          ),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Akun'),
        ],
      ),
    );
  }
}
