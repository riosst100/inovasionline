import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../home/welcome_message.dart';
import '../../core/utils/formatters.dart';
import '../orders/order_providers.dart';
import '../wallet/wallet_providers.dart';
import 'edit_profile_screen.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  Future<void> _checkForUpdate(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Memeriksa update...'),
          behavior: SnackBarBehavior.floating,
        ),
      );

    try {
      final update = await ref.read(appUpdateServiceProvider).checkForUpdate();
      messenger.hideCurrentSnackBar();
      if (!context.mounted) return;
      if (update == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Aplikasi sudah versi terbaru.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      // Asked for explicitly, so Play's full-screen update straight away.
      await ref.read(appUpdateServiceProvider).updateNow(update.play);
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Gagal memeriksa update. Pastikan aplikasi diinstal dari Google Play dan coba lagi.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _showAvatarOptions(
    BuildContext context,
    WidgetRef ref,
    User user,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            if (user.avatarUrl != null)
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('Lihat Foto Profil'),
                onTap: () => Navigator.of(sheetContext).pop('view'),
              ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil Foto'),
              onTap: () => Navigator.of(sheetContext).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.of(sheetContext).pop('gallery'),
            ),
          ],
        ),
      ),
    );

    if (action == null || !context.mounted) return;

    if (action == 'view') {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  child: Center(
                    child: CachedNetworkImage(memCacheWidth: 300, imageUrl: user.avatarUrl!),
                  ),
                ),
              ),
              SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    final picked = await ImagePicker().pickImage(
      source: action == 'camera' ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 80, maxWidth: 800, maxHeight: 800,
    );
    if (picked == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Sesuaikan Foto Profil',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Sesuaikan Foto Profil',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
    if (cropped == null) return;

    final success = await ref
        .read(authProvider.notifier)
        .updateProfile(avatar: File(cropped.path));

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Foto profil diperbarui.'
              : (ref.read(authProvider).error ??
                    'Gagal memperbarui foto profil.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final authUser = authState.user;
    final user = authState.status == AuthStatus.authenticated ? authUser : null;
    final activeOrderCount = ref.watch(activeOrdersProvider).valueOrNull?.length ?? 0;
    final walletBalance = ref.watch(walletProvider).valueOrNull?.balance;
    void goToLogin() => context.push('/account/login');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          _ProfileHeader(
            user: user,
            onAvatarTap: user != null
                ? () => _showAvatarOptions(context, ref, user)
                : goToLogin,
            onEditTap: user != null
                ? () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  )
                : goToLogin,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('Aktivitas'),
                _MenuGroup(
                  children: [
                    _MenuTile(
                      icon: Icons.account_balance_wallet_rounded,
                      color: const Color(0xFF0D9488),
                      title: 'Saldo Inovasi',
                      subtitle: user == null
                          ? 'Masuk untuk melihat saldo'
                          : walletBalance == null
                              ? 'Lihat saldo dan top up'
                              : '${formatCurrency(walletBalance)} · Top up & riwayat',
                      onTap: user != null ? () => context.push('/wallet') : goToLogin,
                    ),
                    _MenuTile(
                      icon: Icons.receipt_long_rounded,
                      color: const Color(0xFF0284C7),
                      title: 'Pesanan Saya',
                      subtitle: 'Lacak dan lihat riwayat pesanan',
                      badgeCount: activeOrderCount,
                      onTap: user != null
                          ? () => context.go('/orders')
                          : goToLogin,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const _SectionLabel('Info Akun'),
                _MenuGroup(
                  children: [
                    _MenuTile(
                      icon: Icons.phone_rounded,
                      color: AppColors.primary,
                      title: 'Nomor Telepon',
                      subtitle: user != null
                          ? (user.phone ?? '-')
                          : 'Masuk untuk melihat info akun',
                      onTap: user != null ? null : goToLogin,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const _SectionLabel('Bantuan'),
                _MenuGroup(
                  children: [
                    _MenuTile(
                      icon: Icons.headset_mic_rounded,
                      color: const Color(0xFFF59E0B),
                      title: 'Chat CS',
                      subtitle: 'Butuh bantuan? Hubungi customer service',
                      onTap: () => context.push('/chat'),
                    ),
                    if (ref.read(appUpdateServiceProvider).isSupported)
                      _MenuTile(
                        icon: Icons.system_update_rounded,
                        color: const Color(0xFF6366F1),
                        title: 'Versi Aplikasi',
                        subtitle: switch (ref.watch(packageInfoProvider).valueOrNull) {
                          final info? => 'v${info.version} (${info.buildNumber}) · Ketuk untuk cek update',
                          null => 'Ketuk untuk cek update',
                        },
                        onTap: () => _checkForUpdate(context, ref),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                if (user == null)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: goToLogin,
                      icon: const Icon(Icons.login_rounded, size: 20),
                      label: const Text(
                        'Masuk / Daftar',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        backgroundColor: const Color(0xFFFEF2F2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        final name = user.name;
                        await ref.read(authProvider.notifier).logout();
                        ref
                            .read(pendingWelcomeProvider.notifier)
                            .state = WelcomeMessage(
                          name: name,
                          type: WelcomeType.logout,
                        );
                        if (context.mounted) context.go('/');
                      },
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: const Text(
                        'Keluar',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.onAvatarTap,
    required this.onEditTap,
  });

  /// Null when browsing as a guest: the header then shows a placeholder
  /// profile and its actions lead to the login screen.
  final User? user;
  final VoidCallback onAvatarTap;
  final VoidCallback onEditTap;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final user = this.user;
    final avatarUrl = user?.avatarUrl;

    return Container(
      padding: EdgeInsets.fromLTRB(20, topPadding + 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D9488), Color(0xFF115E59)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onAvatarTap,
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 34,
                    backgroundColor: const Color(0xFFF3F4F6),
                    backgroundImage: avatarUrl != null
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    child: avatarUrl == null
                        ? const Icon(
                            Icons.person_rounded,
                            size: 36,
                            color: Color(0xFF94A3B8),
                          )
                        : null,
                  ),
                ),
                if (user != null)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(color: Colors.white, width: 2),
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? 'Pengunjung',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user != null
                      ? (user.email ?? user.phone ?? '')
                      : 'Masuk untuk menikmati semua fitur',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: onEditTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          user != null
                              ? Icons.edit_rounded
                              : Icons.login_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          user != null ? 'Edit Profil' : 'Masuk / Daftar',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 21, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.destructive,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$badgeCount aktif',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }
}
