import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/permissions.dart';
import '../../models/parcel.dart';
import '../../providers/providers.dart';
import '../scan/scan_screen.dart';

/// Two tabs: parcels on the road (still to hand over) and delivered ones. The scan button is how
/// a parcel is picked up and later handed over.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _scan(BuildContext context, WidgetRef ref, {Parcel? expected}) async {
    if (!await ensureLocationReady(context) || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ScanScreen(expected: expected))).then((_) {
      ref.invalidate(parcelsProvider(false));
      ref.invalidate(parcelsProvider(true));
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(user?.name ?? 'Driver'),
          actions: [
            IconButton(
              tooltip: 'Keluar',
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(authProvider.notifier).logout(),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Dalam perjalanan'),
              Tab(text: 'Selesai'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ParcelList(done: false, onTap: (p) => _scan(context, ref, expected: p)),
            const _ParcelList(done: true),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _scan(context, ref),
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan QR'),
        ),
      ),
    );
  }
}

class _ParcelList extends ConsumerWidget {
  const _ParcelList({required this.done, this.onTap});

  final bool done;
  final void Function(Parcel)? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parcels = ref.watch(parcelsProvider(done));

    return RefreshIndicator(
      onRefresh: () => ref.refresh(parcelsProvider(done).future),
      child: parcels.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(icon: Icons.cloud_off, text: errorMessage(e)),
        data: (items) => items.isEmpty
            ? _Message(
                icon: Icons.inventory_2_outlined,
                text: done
                    ? 'Belum ada pesanan yang selesai.'
                    : 'Tidak ada paket di tangan.\nScan QR paket untuk mulai mengantar.',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
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
