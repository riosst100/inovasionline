import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/core_providers.dart';

/// "Find friends from contacts" card at the top of the feed. The only place
/// contact access is asked for: the card itself explains what it is for, so
/// "Hubungkan" goes straight to the system dialog. Hidden once access is
/// allowed or the card is closed.
class ContactConnectCard extends ConsumerStatefulWidget {
  const ContactConnectCard({super.key});

  @override
  ConsumerState<ContactConnectCard> createState() => _ContactConnectCardState();
}

class _ContactConnectCardState extends ConsumerState<ContactConnectCard>
    with WidgetsBindingObserver {
  bool _visible = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Catches access being allowed from system Settings.
    if (state == AppLifecycleState.resumed && _visible && !_busy) _refresh();
  }

  Future<void> _refresh() async {
    final contacts = ref.read(contactSyncProvider);
    final offer = await contacts.shouldOffer();
    if (!mounted) return;
    // Allowed from system Settings while the card was showing.
    if (_visible && !offer) unawaited(contacts.sync(force: true));
    setState(() => _visible = offer);
  }

  Future<void> _connect() async {
    setState(() => _busy = true);
    final granted = await ref.read(contactSyncProvider).request();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (granted) _visible = false;
    });
    if (granted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Kontak terhubung.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _close() async {
    setState(() => _visible = false);
    await ref.read(contactSyncProvider).dismiss();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.contacts_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Temukan teman dari kontak',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.foreground,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Lihat postingan & produk dari orang yang kamu kenal',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _busy ? null : _connect,
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: const Text('Hubungkan'),
            ),
            IconButton(
              onPressed: _busy ? null : _close,
              visualDensity: VisualDensity.compact,
              tooltip: 'Tutup',
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
