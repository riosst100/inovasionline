import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/permissions.dart';
import '../../models/parcel.dart';
import '../../providers/providers.dart';
import '../scan/confirm_screen.dart';
import '../scan/scan_screen.dart';

/// Opens the scanner (after the location check) and refreshes the parcel lists when it closes.
Future<void> openScan(BuildContext context, WidgetRef ref, {Parcel? expected}) async {
  if (!await ensureLocationReady(context) || !context.mounted) return;
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ScanScreen(expected: expected))).then((_) {
    ref.invalidate(readyParcelsProvider);
    ref.invalidate(parcelsProvider(false));
    ref.invalidate(parcelsProvider(true));
  });
}

/// Confirms pickup or handover of [parcel] straight from a list, no QR scan needed.
Future<void> openConfirm(BuildContext context, WidgetRef ref, Parcel parcel) async {
  if (parcel.action == ParcelAction.none || !await ensureLocationReady(context) || !context.mounted) return;
  await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ConfirmScreen(parcel: parcel)));
  ref.invalidate(readyParcelsProvider);
  ref.invalidate(parcelsProvider(false));
  ref.invalidate(parcelsProvider(true));
}

/// "Pesanan" menu, three tabs: parcels to pick up, on the way, and delivered ones. Pickup and
/// handover are confirmed by tapping the parcel; scanning its QR is optional.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pesanan'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Siap Diambil'),
              Tab(text: 'Diantar'),
              Tab(text: 'Selesai'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ParcelList(
              provider: readyParcelsProvider,
              emptyText: 'Belum ada paket yang siap diambil.',
              onTap: (p) => openConfirm(context, ref, p),
            ),
            _ParcelList(
              provider: parcelsProvider(false),
              emptyText: 'Tidak ada paket di tangan.\nAmbil paket dari tab Siap Diambil atau scan QR-nya.',
              onTap: (p) => openConfirm(context, ref, p),
            ),
            _ParcelList(provider: parcelsProvider(true), emptyText: 'Belum ada pesanan yang selesai.'),
          ],
        ),
      ),
    );
  }
}

class _ParcelList extends ConsumerWidget {
  const _ParcelList({required this.provider, required this.emptyText, this.onTap});

  final ProviderBase<AsyncValue<List<Parcel>>> provider;
  final String emptyText;
  final void Function(Parcel)? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parcels = ref.watch(provider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(provider),
      child: parcels.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(icon: Icons.cloud_off, text: errorMessage(e)),
        data: (items) => items.isEmpty
            ? _Message(icon: Icons.inventory_2_outlined, text: emptyText)
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _ParcelCard(parcel: items[i], onTap: onTap),
              ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    // Scrollable so pull-to-refresh works on an empty list.
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: AppColors.mutedForeground),
              const SizedBox(height: 12),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.mutedForeground),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ParcelCard extends StatelessWidget {
  const _ParcelCard({required this.parcel, this.onTap});

  final Parcel parcel;
  final void Function(Parcel)? onTap;

  @override
  Widget build(BuildContext context) {
    final phone = parcel.customerPhone;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap == null ? null : () => onTap!(parcel),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(parcel.orderNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  if (parcel.completedAt != null)
                    Text(
                      formatTime(parcel.completedAt!),
                      style: const TextStyle(color: AppColors.mutedForeground, fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(parcel.receiver, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (parcel.address != null)
                Text(parcel.address!, style: const TextStyle(color: AppColors.mutedForeground, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('${parcel.itemsCount} barang', style: const TextStyle(fontSize: 13)),
                  if (parcel.codAmount > 0) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'COD ${formatCurrency(parcel.codAmount)}',
                        style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (phone != null && phone.isNotEmpty)
                    IconButton(
                      tooltip: 'Telepon',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.call, color: AppColors.primary),
                      onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
