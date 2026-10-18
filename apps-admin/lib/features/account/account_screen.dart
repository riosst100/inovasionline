import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Akun')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
                    child: user?.avatarUrl == null
                        ? Text(
                            (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? '-', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        Text(user?.email ?? '', style: const TextStyle(color: AppColors.mutedForeground)),
                        if (user?.roleName != null) ...[
                          const SizedBox(height: 6),
                          StatusBadge(label: user!.roleName!, color: AppColors.primary),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.destructive),
                  title: const Text('Keluar', style: TextStyle(color: AppColors.destructive)),
                  onTap: () async {
                    final ok = await confirm(
                      context,
                      title: 'Keluar',
                      message: 'Keluar dari akun admin di perangkat ini?',
                      confirmLabel: 'Keluar',
                      destructive: true,
                    );
                    if (ok) await ref.read(authProvider.notifier).logout();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
