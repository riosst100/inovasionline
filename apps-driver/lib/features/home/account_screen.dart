import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';

/// "Akun" menu: the driver's profile and logout.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final vehicle = user?.vehicle;
    final phone = user?.phone;

    return Scaffold(
      appBar: AppBar(title: const Text('Akun')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(user?.name ?? '-'),
                  subtitle: const Text('Nama'),
                ),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: Text(user?.email ?? '-'),
                  subtitle: const Text('Email'),
                ),
                if (phone != null && phone.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.phone_outlined),
                    title: Text(phone),
                    subtitle: const Text('Telepon'),
                  ),
                if (vehicle != null && vehicle.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.two_wheeler_outlined),
                    title: Text(vehicle),
                    subtitle: const Text('Kendaraan'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}
