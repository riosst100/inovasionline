import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart';
import '../features/chat/chat_thread_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/core_providers.dart';

class ChatSellerButton extends ConsumerStatefulWidget {
  const ChatSellerButton({super.key, required this.sellerUserId, required this.sellerName, this.iconOnly = false});

  final String? sellerUserId;
  final String sellerName;
  final bool iconOnly;

  @override
  ConsumerState<ChatSellerButton> createState() => _ChatSellerButtonState();
}

class _ChatSellerButtonState extends ConsumerState<ChatSellerButton> {
  bool _loading = false;

  Future<void> _startChat() async {
    final authState = ref.read(authProvider);
    final currentUserId = authState.user?.id;
    final sellerUserId = widget.sellerUserId;

    if (authState.status != AuthStatus.authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masuk terlebih dahulu untuk chat dengan penjual.')),
      );
      return;
    }

    if (sellerUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Penjual tidak tersedia untuk dihubungi.')),
      );
      return;
    }

    if (sellerUserId == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ini adalah toko Anda sendiri.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final thread = await ref.read(chatServiceProvider).startDirectMessage(sellerUserId);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatThreadScreen(threadId: thread.id, title: thread.title, canPost: true),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuka percakapan.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _loading
        ? const SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          )
        : const Icon(Icons.chat_outlined, size: 18);

    if (widget.iconOnly) {
      return OutlinedButton(
        onPressed: _loading ? null : _startChat,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(48, 48),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
        ),
        child: icon,
      );
    }

    return OutlinedButton.icon(
      onPressed: _loading ? null : _startChat,
      icon: icon,
      label: const Text('Chat Penjual'),
    );
  }
}
