import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../core/api/account_block.dart';
import '../../providers/auth_provider.dart';

/// Covers the whole app with a lock screen while the signed-in account is
/// blocked by an admin, so no products or other data are shown.
class BlockedAccountGate extends ConsumerStatefulWidget {
  const BlockedAccountGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BlockedAccountGate> createState() => _BlockedAccountGateState();
}

class _BlockedAccountGateState extends ConsumerState<BlockedAccountGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  void _check() => ref.read(authProvider.notifier).checkBlockStatus();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AccountBlockInfo?>(
      valueListenable: AccountBlock.notifier,
      builder: (context, info, _) {
        return Stack(
          children: [
            widget.child,
            ValueListenableBuilder<FeatureBanInfo?>(
              valueListenable: AccountBlock.featureBan,
              builder: (context, ban, _) => ban == null
                  ? const SizedBox.shrink()
                  : Positioned.fill(child: _FeatureBanDialog(info: ban)),
            ),
            if (info != null)
              Positioned.fill(child: _BlockedScreen(info: info)),
          ],
        );
      },
    );
  }
}

/// Modal shown when a single feature is banned for the user. The app stays
/// usable; only the rejected action is refused.
class _FeatureBanDialog extends StatelessWidget {
  const _FeatureBanDialog({required this.info});

  final FeatureBanInfo info;

  Future<void> _contactAdmin(BuildContext context) async {
    final url = info.contactUrl;
    final uri = url == null || url.isEmpty ? null : Uri.tryParse(url);
    final opened =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kontak admin belum tersedia.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reason = info.reason;

    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.gpp_bad_rounded,
                size: 44,
                color: AppColors.destructive,
              ),
              const SizedBox(height: 12),
              Text(
                'Fitur ${info.featureLabel} Dibatasi',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Anda dilarang menggunakan fitur ${info.featureLabel.toLowerCase()} oleh admin. '
                'Jika menurut Anda ini sebuah kesalahan, silakan hubungi admin.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.mutedForeground,
                  height: 1.4,
                ),
              ),
              if (reason != null && reason.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Alasan: $reason'),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _contactAdmin(context),
                  icon: const Icon(Icons.support_agent_rounded),
                  label: const Text('Hubungi Admin'),
                ),
              ),
              TextButton(
                onPressed: () => AccountBlock.featureBan.value = null,
                child: const Text('Tutup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockedScreen extends ConsumerStatefulWidget {
  const _BlockedScreen({required this.info});

  final AccountBlockInfo info;

  @override
  ConsumerState<_BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends ConsumerState<_BlockedScreen> {
  bool _checking = false;

  Future<void> _contactAdmin() async {
    final url = widget.info.contactUrl;
    final uri = url == null || url.isEmpty ? null : Uri.tryParse(url);
    final opened =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kontak admin belum tersedia.')),
      );
    }
  }

  Future<void> _recheck() async {
    setState(() => _checking = true);
    await ref.read(authProvider.notifier).refreshAccount();
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final reason = widget.info.reason;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.destructive.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.block_rounded,
                    size: 56,
                    color: AppColors.destructive,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Akun Anda Diblokir',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Akun Anda telah diblokir oleh admin sehingga tidak dapat mengakses aplikasi. '
                  'Jika menurut Anda ini sebuah kesalahan, silakan hubungi admin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.mutedForeground,
                    height: 1.4,
                  ),
                ),
                if (reason != null && reason.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Alasan: $reason'),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _contactAdmin,
                    icon: const Icon(Icons.support_agent_rounded),
                    label: const Text('Hubungi Admin'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _checking ? null : _recheck,
                    child: Text(
                      _checking ? 'Memeriksa...' : 'Periksa Status Akun',
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                  child: const Text('Keluar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
