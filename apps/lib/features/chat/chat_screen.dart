import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/chat_thread.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/skeleton.dart';
import 'chat_providers.dart';
import 'chat_thread_screen.dart';

const _chatListPollInterval = Duration(seconds: 5);

class _ChatListCard extends StatelessWidget {
  const _ChatListCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.timeLabel,
    this.isUnread = false,
    this.isFavorite = false,
    required this.onTap,
    this.onLongPress,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final String? timeLabel;
  final bool isUnread;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isFavorite) ...[
                          const Icon(
                            Icons.star,
                            size: 15,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (timeLabel != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            timeLabel!,
                            style: TextStyle(
                              color: isUnread
                                  ? AppColors.primary
                                  : AppColors.mutedForeground,
                              fontSize: 11.5,
                              fontWeight: isUnread
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isUnread
                                  ? AppColors.foreground
                                  : AppColors.mutedForeground,
                              fontSize: 12.5,
                              fontWeight: isUnread
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    if (authState.status == AuthStatus.authenticated) {
      return const _ChatThreadListView();
    }

    return const _GuestGlobalPreviewView();
  }
}

IconData _iconForThread(ChatThread thread) {
  if (thread.isOfficial) return Icons.campaign_outlined;
  if (thread.isGlobal) return Icons.public;
  if (thread.isRegion) return Icons.location_city_outlined;
  return Icons.person_outline;
}

String _subtitleForThread(ChatThread thread, String? currentUserId) {
  final latest = thread.latestMessage;
  if (latest != null) {
    final isMine = latest.senderId != null && latest.senderId == currentUserId;
    final senderLabel = isMine ? 'Anda' : latest.senderName;
    final prefix = !thread.isDirectMessage && senderLabel != null
        ? '$senderLabel: '
        : (isMine ? 'Anda: ' : '');
    return '$prefix${latest.body}';
  }

  return 'Belum ada pesan.';
}

class _ChatThreadListView extends ConsumerStatefulWidget {
  const _ChatThreadListView();

  @override
  ConsumerState<_ChatThreadListView> createState() =>
      _ChatThreadListViewState();
}

enum _ChatFilter { all, unread, favorite }

class _ChatThreadListViewState extends ConsumerState<_ChatThreadListView> {
  Timer? _pollTimer;
  _ChatFilter _filter = _ChatFilter.all;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(
      _chatListPollInterval,
      (_) => ref.invalidate(chatThreadsProvider),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  List<ChatThread> _applyFilter(List<ChatThread> threads) {
    return switch (_filter) {
      _ChatFilter.all => threads,
      _ChatFilter.unread => threads.where((t) => t.isUnread).toList(),
      _ChatFilter.favorite => threads.where((t) => t.isFavorite).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final threadsAsync = ref.watch(chatThreadsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chat'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Grup Chat'),
              Tab(text: 'Chat Pribadi'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Semua',
                    selected: _filter == _ChatFilter.all,
                    onTap: () => setState(() => _filter = _ChatFilter.all),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Belum dibaca',
                    selected: _filter == _ChatFilter.unread,
                    onTap: () => setState(() => _filter = _ChatFilter.unread),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Favorit',
                    selected: _filter == _ChatFilter.favorite,
                    onTap: () => setState(() => _filter = _ChatFilter.favorite),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Builder(
                builder: (context) {
                  final threads = threadsAsync.valueOrNull;
                  if (threads != null) {
                    final filtered = _applyFilter(threads);
                    final groupThreads = filtered
                        .where((t) => !t.isDirectMessage)
                        .toList();
                    final dmThreads = filtered
                        .where((t) => t.isDirectMessage)
                        .toList();

                    return TabBarView(
                      children: [
                        _ThreadList(
                          threads: groupThreads,
                          emptyText: 'Belum ada grup chat.',
                        ),
                        _ThreadList(
                          threads: dmThreads,
                          emptyText: 'Belum ada percakapan pribadi.',
                        ),
                      ],
                    );
                  }

                  if (threadsAsync.hasError) {
                    return Center(
                      child: Text(
                        'Gagal memuat percakapan: ${threadsAsync.error}',
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: 5,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (_, _) => Row(
                      children: const [
                        Skeleton(width: 48, height: 48, borderRadius: 24),
                        SizedBox(width: 12),
                        Expanded(child: Skeleton(height: 14)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class _ThreadList extends ConsumerWidget {
  const _ThreadList({required this.threads, required this.emptyText});

  final List<ChatThread> threads;
  final String emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(authProvider).user?.id;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(chatThreadsProvider.future),
      child: threads.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                Center(child: Text(emptyText)),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: threads.length,
              itemBuilder: (context, index) {
                final thread = threads[index];
                return _ChatListCard(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.primary,
                    backgroundImage: thread.otherUser?.avatarUrl != null
                        ? NetworkImage(thread.otherUser!.avatarUrl!)
                        : null,
                    child: thread.otherUser?.avatarUrl == null
                        ? Icon(_iconForThread(thread))
                        : null,
                  ),
                  title: thread.title,
                  subtitle: _subtitleForThread(thread, currentUserId),
                  timeLabel: thread.latestMessage?.createdAt != null
                      ? formatChatListTime(thread.latestMessage!.createdAt!)
                      : null,
                  isUnread: thread.isUnread,
                  isFavorite: thread.isFavorite,
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => ChatThreadScreen(
                        threadId: thread.id,
                        title: thread.title,
                        canPost: !thread.isOfficial,
                        avatarUrl: thread.otherUser?.avatarUrl,
                        avatarIcon: _iconForThread(thread),
                        isDirectMessage: thread.isDirectMessage,
                        isSeller: thread.otherUser?.isSeller ?? false,
                      ),
                    ),
                  ),
                  onLongPress: () async {
                    await ref
                        .read(chatServiceProvider)
                        .toggleFavorite(thread.id);
                    ref.invalidate(chatThreadsProvider);
                  },
                );
              },
            ),
    );
  }
}

class _GuestGlobalPreviewView extends ConsumerWidget {
  const _GuestGlobalPreviewView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: _ChatListCard(
              leading: const CircleAvatar(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.primary,
                child: Icon(Icons.public),
              ),
              title: 'Warga +62',
              subtitle: 'Obrolan seluruh pengguna',
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => const _GuestGlobalMessagesScreen(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Masuk untuk mengirim pesan dan mengakses chat wilayah serta percakapan pribadi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.push('/account/register'),
                          child: const Text('Daftar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => context.push('/account/login'),
                          child: const Text('Masuk'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestGlobalMessagesScreen extends ConsumerWidget {
  const _GuestGlobalMessagesScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewAsync = ref.watch(chatGlobalPreviewProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Warga +62')),
      body: previewAsync.when(
        data: (result) {
          final (_, messages) = result;
          return Column(
            children: [
              Container(
                width: double.infinity,
                color: AppColors.surface,
                padding: const EdgeInsets.all(12),
                child: const Text(
                  'Masuk untuk mengirim pesan dan mengakses chat wilayah.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.mutedForeground,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                child: messages.isEmpty
                    ? const Center(child: Text('Belum ada pesan.'))
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.sizeOf(context).width * 0.75,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    message.senderName ?? 'Pengguna',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    message.body,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                color: AppColors.surface,
                child: const Center(
                  child: Text(
                    'Masuk untuk ikut mengirim pesan',
                    style: TextStyle(color: AppColors.mutedForeground),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Gagal memuat chat: $error')),
      ),
    );
  }
}
