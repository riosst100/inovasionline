import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../home/welcome_message.dart';
import 'edit_profile_screen.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    if (authState.status != AuthStatus.authenticated || user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Akun')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Anda belum masuk.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.push('/account/login'),
                child: const Text('Masuk'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Akun')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFFF3F4F6),
            backgroundImage: user.avatarUrl != null
                ? NetworkImage(user.avatarUrl!)
                : null,
            child: user.avatarUrl == null
                ? const Icon(Icons.person_outline, size: 36)
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            user.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          Text(
            user.email ?? user.phone ?? '',
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              ),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Profil'),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: const Text('Nomor Telepon'),
              subtitle: Text(user.phone ?? '-'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Peran'),
              subtitle: Text(user.role ?? '-'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Pesanan Saya'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/orders'),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              final name = user.name;
              await ref.read(authProvider.notifier).logout();
              ref.read(pendingWelcomeProvider.notifier).state = WelcomeMessage(
                name: name,
                type: WelcomeType.logout,
              );
              if (context.mounted) context.go('/');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}
