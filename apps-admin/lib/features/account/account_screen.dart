import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common.dart';
import '../cod/cod_verification_screen.dart';
import 'change_password_screen.dart';

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
                  const _AvatarPicker(),
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
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Ganti Kata Sandi'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ChangePasswordScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.face_retouching_natural_outlined),
                  title: const Text('Verifikasi COD'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: (_) => const CodVerificationListScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout,color: AppColors.destructive),
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

/// Tap to change or remove the admin's own profile photo.
class _AvatarPicker extends ConsumerStatefulWidget {
  const _AvatarPicker();

  @override
  ConsumerState<_AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends ConsumerState<_AvatarPicker> {
  bool _busy = false;

  Future<void> _openMenu() async {
    final hasAvatar = ref.read(authProvider).user?.avatarUrl != null;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil Foto'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            if (hasAvatar)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.destructive),
                title: const Text('Hapus Foto', style: TextStyle(color: AppColors.destructive)),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    String? path;
    if (choice == 'delete') {
      final ok = await confirm(
        context,
        title: 'Hapus Foto',
        message: 'Hapus foto profil Anda?',
        confirmLabel: 'Hapus',
        destructive: true,
      );
      if (!ok) return;
    } else {
      final file = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (file == null) return;
      path = file.path;
    }

    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).setAvatar(path);
      if (mounted) showMessage(context, path == null ? 'Foto profil dihapus.' : 'Foto profil diperbarui.');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return GestureDetector(
      onTap: _busy ? null : _openMenu,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : user?.avatarUrl == null
                ? Text(
                    (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary),
                  )
                : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
