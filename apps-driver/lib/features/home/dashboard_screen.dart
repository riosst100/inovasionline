import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../core/formatters.dart';
import '../../providers/providers.dart';

/// "Dashboard" menu: a summary of what is still to deliver and what is already done.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, required this.onOpenOrders});

  final VoidCallback onOpenOrders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final pending = ref.watch(parcelsProvider(false));
    final done = ref.watch(parcelsProvider(true));

    Future<void> refresh() async {
      ref.invalidate(parcelsProvider(false));
      ref.invalidate(parcelsProvider(true));
      await Future.wait([ref.read(parcelsProvider(false).future), ref.read(parcelsProvider(true).future)]);
    }

    String count(AsyncValue<List<dynamic>> v) =>
        v.when(data: (l) => '${l.length}', loading: () => '...', error: (_, _) => '-');

    final cod = pending.valueOrNull?.fold<num>(0, (sum, p) => sum + p.codAmount) ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Halo, ${user?.name ?? 'Driver'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Perlu Dikirim',
                    value: count(pending),
                    icon: Icons.local_shipping_outlined,
                    onTap: onOpenOrders,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Selesai',
                    value: count(done),
                    icon: Icons.check_circle_outline,
                    onTap: onOpenOrders,
                  ),
                ),
              ],
            ),
            if (cod > 0) ...[
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.payments_outlined, color: AppColors.warning),
                  title: const Text('COD yang harus ditagih'),
                  trailing: Text(formatCurrency(cod), style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, required this.onTap});

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(height: 12),
              Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              Text(label, style: const TextStyle(color: AppColors.mutedForeground)),
            ],
          ),
        ),
      ),
    );
  }
}
