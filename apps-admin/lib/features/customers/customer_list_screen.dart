import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/customer.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_list.dart';
import '../cod/cod_verification_screen.dart';

/// Seen within this window counts as online (the app sends a heartbeat while in the foreground).
const _onlineWindow = Duration(minutes: 5);

/// "Online" / "5 menit lalu" / a date, from the customer's last_seen_at.
String lastSeenText(DateTime? at, DateTime now) {
  if (at == null) return 'Belum pernah online';
  final ago = now.difference(at);
  if (ago < _onlineWindow) return 'Online';
  if (ago.inMinutes < 60) return '${ago.inMinutes} menit lalu';
  if (ago.inHours < 24) return '${ago.inHours} jam lalu';
  if (ago.inDays < 30) return '${ago.inDays} hari lalu';
  return formatDateTime(at);
}

/// Pengguna: customer accounts with their face-verification status and last online time.
class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final _listKey = GlobalKey<PagedListState<Customer>>();
  String _search = '';

  Future<void> _openActions(Customer customer) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) => _CustomerSheet(customer: customer),
    );
    if (action == null || !mounted) return;

    switch (action) {
      case 'event':
        await _openVerifications(customer, eventId: customer.verificationId);
      case 'all':
        await _openVerifications(customer);
      case 'revoke':
        await _revoke(customer);
    }
  }

  Future<void> _openVerifications(Customer customer, {String? eventId}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CodVerificationListScreen(
          user: (id: customer.id, name: customer.name, contact: customer.contact),
          openEventId: eventId,
        ),
      ),
    );
    // A revoke from the event review changes the user's status too.
    _listKey.currentState?.refresh();
  }

  Future<void> _revoke(Customer customer) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cabut verifikasi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cabut verifikasi wajah ${customer.name}? Pengguna wajib verifikasi ulang sebelum memakai COD/Paylater.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Alasan (wajib), mis. wajah tidak sesuai'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Cabut'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    if (reason.isEmpty) {
      showMessage(context, 'Alasan pencabutan wajib diisi.', error: true);
      return;
    }

    try {
      final updated = await ref.read(customerServiceProvider).revokeVerification(customer.id, reason);
      _listKey.currentState?.replaceWhere((c) => c.id == customer.id, updated.withLastSeenOf(customer));
      if (mounted) showMessage(context, 'Verifikasi ${customer.name} dicabut.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Pengguna')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SearchField(
              hint: 'Cari nama, email, atau no. HP',
              onChanged: (value) {
                _search = value;
                _listKey.currentState?.refresh();
              },
            ),
          ),
          Expanded(
            child: PagedList<Customer>(
              key: _listKey,
              emptyIcon: Icons.people_outline,
              emptyText: 'Belum ada pengguna.',
              fetch: (page) => ref.read(customerServiceProvider).list(page: page, search: _search),
              itemBuilder: (context, customer) =>
                  _CustomerTile(customer: customer, now: now, onTap: () => _openActions(customer)),
            ),
          ),
        ],
      ),
    );
  }
}

class VerificationBadge extends StatelessWidget {
  const VerificationBadge({super.key, required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) => switch (status) {
    'verified' => const StatusBadge(label: 'Terverifikasi', color: AppColors.success),
    'revoked' => const StatusBadge(label: 'Dicabut', color: AppColors.destructive),
    _ => const StatusBadge(label: 'Belum Verifikasi', color: AppColors.mutedForeground),
  };
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.customer, required this.now, required this.onTap});

  final Customer customer;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final seen = lastSeenText(customer.lastSeenAt, now);
    final online = seen == 'Online';
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          backgroundImage: customer.avatarUrl != null ? NetworkImage(customer.avatarUrl!) : null,
          child: customer.avatarUrl == null
              ? Text(
                  customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                )
              : null,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                customer.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (customer.isBlocked) ...[
              const SizedBox(width: 6),
              const StatusBadge(label: 'Diblokir', color: AppColors.destructive),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (customer.contact != null) Text(customer.contact!, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(
              children: [
                if (online) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  seen,
                  style: TextStyle(
                    fontSize: 12,
                    color: online ? AppColors.success : AppColors.mutedForeground,
                    fontWeight: online ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: VerificationBadge(status: customer.verificationStatus),
      ),
    );
  }
}

/// Details and verification actions for one customer; pops with the chosen action.
class _CustomerSheet extends StatelessWidget {
  const _CustomerSheet({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final status = customer.verificationStatus;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(customer.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                  VerificationBadge(status: status),
                ],
              ),
              if (customer.email != null) Text(customer.email!, style: const TextStyle(color: AppColors.mutedForeground)),
              if (customer.phone != null) Text(customer.phone!, style: const TextStyle(color: AppColors.mutedForeground)),
              const SizedBox(height: 8),
              Text(
                [
                  'Terakhir online: ${lastSeenText(customer.lastSeenAt, DateTime.now())}',
                  if (customer.createdAt != null) 'Terdaftar: ${formatDateTime(customer.createdAt!)}',
                ].join('\n'),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        const Divider(),
        if (customer.verificationId != null)
          ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: Text(status == 'revoked' ? 'Lihat event yang dicabut' : 'Lihat event verifikasi'),
            onTap: () => Navigator.pop(context, 'event'),
          ),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Semua verifikasi pengguna ini'),
          onTap: () => Navigator.pop(context, 'all'),
        ),
        if (status == 'verified')
          ListTile(
            leading: const Icon(Icons.gpp_bad_outlined, color: AppColors.destructive),
            title: const Text('Cabut Verifikasi', style: TextStyle(color: AppColors.destructive)),
            onTap: () => Navigator.pop(context, 'revoke'),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}
