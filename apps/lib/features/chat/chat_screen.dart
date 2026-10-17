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
  if (thread.isOfficial) return Icons.campaign_rounded;
  if (thread.isGlobal) return Icons.public_rounded;
  if (thread.isRegion) return Icons.location_city_rounded;
  return Icons.person_rounded;
}

/// Gradient behind a thread's avatar icon, so each kind of chat is
/// recognisable at a glance in the list.
List<Color> _gradientForThread(ChatThread thread) {
  if (thread.isOfficial) return const [Color(0xFFA855F7), AppColors.secondary];
  if (thread.isGlobal) return const [Color(0xFF38BDF8), Color(0xFF0284C7)];
  if (thread.isRegion) return const [Color(0xFFFBBF24), Color(0xFFF59E0B)];
  return const [Color(0xFF2DD4BF), AppColors.primary];
}

String? _senderPrefix(ChatThread thread, String? currentUserId) {
  final latest = thread.latestMessage;
  if (latest == null) return null;
  final isMine = latest.senderId != null && latest.senderId == currentUserId;
  if (isMine) return 'Anda';
  if (!thread.isDirectMessage) return latest.senderName;
  return null;
}

void _openThread(BuildContext context, ChatThread thread) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => ChatThreadScreen(
        threadId: thread.id,
        title: thread.title,
        canPost: !thread.isOfficial,
        avatarUrl: thread.otherUser?.avatarUrl,
        avatarIcon: _iconForThread(thread),
        isDirectMessage: thread.isDirectMessage,
      ),
    ),
  );
}

// ==========================================
// AUTHENTICATED: THREAD LIST
// ==========================================

class _ChatThreadListView extends ConsumerStatefulWidget {
  const _ChatThreadListView();

  @override
  ConsumerState<_ChatThreadListView> createState() =>
      _ChatThreadListViewState();
}

enum _ChatFilter { all, unread, favorite }

class _ChatThreadListViewState extends ConsumerState<_ChatThreadListView>
    with SingleTickerProviderStateMixin {
  Timer? _pollTimer;
  _ChatFilter _filter = _ChatFilter.all;
  late final TabController _tabController;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _pollTimer = Timer.periodic(
      _chatListPollInterval,
      (_) => ref.invalidate(chatThreadsProvider),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<ChatThread> _applyFilter(List<ChatThread> threads) {
    final byFilter = switch (_filter) {
      _ChatFilter.all => threads,
      _ChatFilter.unread => threads.where((t) => t.isUnread).toList(),
      _ChatFilter.favorite => threads.where((t) => t.isFavorite).toList(),
    };

    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return byFilter;
    return byFilter
        .where(
          (t) =>
              t.title.toLowerCase().contains(query) ||
              (t.latestMessage?.body.toLowerCase().contains(query) ?? false),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final threadsAsync = ref.watch(chatThreadsProvider);
    final threads = threadsAsync.valueOrNull;
    final groupUnread =
        threads?.where((t) => !t.isDirectMessage && t.isUnread).length ?? 0;
    final dmUnread =
        threads?.where((t) => t.isDirectMessage && t.isUnread).length ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _ChatListHeader(
            searchController: _searchController,
            onSearchChanged: (value) => setState(() => _query = value),
            tabController: _tabController,
            groupUnread: groupUnread,
            dmUnread: dmUnread,
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              children: [
                _FilterChip(
                  label: 'Semua',
                  icon: Icons.forum_outlined,
                  selected: _filter == _ChatFilter.all,
                  onTap: () => setState(() => _filter = _ChatFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Belum dibaca',
                  icon: Icons.mark_chat_unread_outlined,
                  selected: _filter == _ChatFilter.unread,
                  onTap: () => setState(() => _filter = _ChatFilter.unread),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Favorit',
                  icon: Icons.star_outline_rounded,
                  selected: _filter == _ChatFilter.favorite,
                  onTap: () => setState(() => _filter = _ChatFilter.favorite),
                ),
              ],
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (threads != null) {
                  final filtered = _applyFilter(threads);
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _ThreadList(
                        threads: filtered
                            .where((t) => !t.isDirectMessage)
                            .toList(),
                        emptyIcon: Icons.groups_rounded,
                        emptyTitle: _emptyTitle('grup chat'),
                        emptySubtitle: 'Grup chat wilayah dan komunitas akan muncul di sini.',
                      ),
                      _ThreadList(
                        threads: filtered
                            .where((t) => t.isDirectMessage)
                            .toList(),
                        emptyIcon: Icons.chat_bubble_outline_rounded,
                        emptyTitle: _emptyTitle('percakapan pribadi'),
                        emptySubtitle:
                            'Percakapan pribadi Anda akan muncul di sini.',
                      ),
                    ],
                  );
                }

                if (threadsAsync.hasError) {
                  return _ChatEmptyState(
                    icon: Icons.wifi_off_rounded,
                    title: 'Gagal memuat percakapan',
                    subtitle: 'Periksa koneksi internetmu lalu coba lagi.',
                    action: FilledButton.icon(
                      onPressed: () => ref.invalidate(chatThreadsProvider),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Coba Lagi'),
                    ),
                  );
                }

                return const _ThreadListSkeleton();
              },
            ),
          ),
        ],
      ),
    );
  }

  String _emptyTitle(String kind) {
    if (_query.trim().isNotEmpty) {
      return 'Tidak ada hasil untuk "${_query.trim()}"';
    }
    return switch (_filter) {
      _ChatFilter.all => 'Belum ada $kind',
      _ChatFilter.unread => 'Semua pesan sudah dibaca',
      _ChatFilter.favorite => 'Belum ada $kind favorit',
    };
  }
}

class _ChatListHeader extends StatelessWidget {
  const _ChatListHeader({
    required this.searchController,
    required this.onSearchChanged,
    required this.tabController,
    required this.groupUnread,
    required this.dmUnread,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final TabController tabController;
  final int groupUnread;
  final int dmUnread;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(16, topPadding + 14, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D9488), Color(0xFF115E59)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chat',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Ngobrol dengan warga sekitar',
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Cari percakapan',
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF94A3B8),
                ),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: searchController,
                  builder: (context, value, _) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: const Color(0xFF94A3B8),
                          onPressed: () {
                            searchController.clear();
                            onSearchChanged('');
                          },
                        ),
                ),
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 42,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.white,
              labelStyle: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
              splashBorderRadius: BorderRadius.circular(10),
              tabs: [
                _TabLabel(text: 'Grup Chat', badge: groupUnread),
                _TabLabel(text: 'Chat Pribadi', badge: dmUnread),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.text, required this.badge});

  final String text;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text),
          if (badge > 0) ...[
            const SizedBox(width: 6),
            Container(
              constraints: const BoxConstraints(minWidth: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge > 99 ? '99+' : '$badge',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? AppColors.primary : const Color(0xFF64748B),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.primary : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreadList extends ConsumerWidget {
  const _ThreadList({
    required this.threads,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  final List<ChatThread> threads;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;

  Future<void> _showThreadActions(
    BuildContext context,
    WidgetRef ref,
    ChatThread thread,
  ) async {
    final toggle = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                thread.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                thread.isFavorite
                    ? Icons.star_border_rounded
                    : Icons.star_rounded,
                color: AppColors.accent,
              ),
              title: Text(
                thread.isFavorite ? 'Hapus dari Favorit' : 'Tambah ke Favorit',
              ),
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('Buka Percakapan'),
              onTap: () {
                Navigator.of(sheetContext).pop(false);
                _openThread(context, thread);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (toggle != true) return;
    await ref.read(chatServiceProvider).toggleFavorite(thread.id);
    ref.invalidate(chatThreadsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          thread.isFavorite
              ? 'Dihapus dari favorit.'
              : 'Ditambahkan ke favorit.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(authProvider).user?.id;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(chatThreadsProvider.future),
      child: threads.isEmpty
          ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: _ChatEmptyState(
                    icon: emptyIcon,
                    title: emptyTitle,
                    subtitle: emptySubtitle,
                  ),
                ),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              itemCount: threads.length,
              itemBuilder: (context, index) {
                final thread = threads[index];
                return _ChatListCard(
                  leading: _ThreadAvatar(thread: thread),
                  title: thread.title,
                  senderPrefix: _senderPrefix(thread, currentUserId),
                  subtitle: thread.latestMessage?.body ?? 'Belum ada pesan.',
                  timeLabel: thread.latestMessage?.createdAt != null
                      ? formatChatListTime(thread.latestMessage!.createdAt!)
                      : null,
                  isUnread: thread.isUnread,
                  isFavorite: thread.isFavorite,
                  isOfficial: thread.isOfficial,
                  onTap: () => _openThread(context, thread),
                  onLongPress: () => _showThreadActions(context, ref, thread),
                );
              },
            ),
    );
  }
}

class _ThreadAvatar extends StatelessWidget {
  const _ThreadAvatar({required this.thread});

  final ChatThread thread;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = thread.otherUser?.avatarUrl;

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: avatarUrl == null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _gradientForThread(thread),
              )
            : null,
        image: avatarUrl != null
            ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
            : null,
      ),
      child: avatarUrl == null
          ? Icon(_iconForThread(thread), color: Colors.white, size: 26)
          : null,
    );
  }
}

class _ChatListCard extends StatelessWidget {
  const _ChatListCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.senderPrefix,
    this.timeLabel,
    this.isUnread = false,
    this.isFavorite = false,
    this.isOfficial = false,
    required this.onTap,
    this.onLongPress,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final String? senderPrefix;
  final String? timeLabel;
  final bool isUnread;
  final bool isFavorite;
  final bool isOfficial;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isUnread ? const Color(0xFFF0FDFA) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isUnread
                    ? AppColors.primary.withValues(alpha: 0.25)
                    : const Color(0xFFF1F5F9),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
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
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: isUnread
                                          ? FontWeight.w800
                                          : FontWeight.w700,
                                      fontSize: 15,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                if (isOfficial) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.verified_rounded,
                                    size: 15,
                                    color: AppColors.secondary,
                                  ),
                                ],
                                if (isFavorite) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 16,
                                    color: Color(0xFFF59E0B),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (timeLabel != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              timeLabel!,
                              style: TextStyle(
                                color: isUnread
                                    ? AppColors.primary
                                    : const Color(0xFF94A3B8),
                                fontSize: 11.5,
                                fontWeight: isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  if (senderPrefix != null)
                                    TextSpan(
                                      text: '$senderPrefix: ',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  TextSpan(text: subtitle),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isUnread
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFF64748B),
                                fontSize: 13,
                                fontWeight: isUnread
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 6,
                                  ),
                                ],
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
      ),
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
              child: Icon(icon, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Color(0xFF64748B),
              ),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

class _ThreadListSkeleton extends StatelessWidget {
  const _ThreadListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, _) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Skeleton(width: 52, height: 52, borderRadius: 26),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 140, height: 14),
                  SizedBox(height: 8),
                  Skeleton(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// GUEST: PUBLIC PREVIEW
// ==========================================

class _GuestGlobalPreviewView extends ConsumerWidget {
  const _GuestGlobalPreviewView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(16, topPadding + 14, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D9488), Color(0xFF115E59)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chat',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ngobrol dengan warga sekitar',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              'Grup Publik',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _ChatListCard(
              leading: Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                  ),
                ),
                child: const Icon(
                  Icons.public_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              title: 'Warga +62',
              subtitle: 'Obrolan seluruh pengguna · Ketuk untuk melihat',
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => const _GuestGlobalMessagesScreen(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF1F5F9)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.08),
                      ),
                      child: const Icon(
                        Icons.forum_rounded,
                        size: 34,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Gabung obrolan sekarang',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _GuestBenefit(
                    icon: Icons.send_rounded,
                    text: 'Kirim pesan di grup Warga +62',
                  ),
                  const _GuestBenefit(
                    icon: Icons.location_city_rounded,
                    text: 'Akses grup chat wilayahmu',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => context.push('/account/register'),
                          child: const Text(
                            'Daftar',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => context.push('/account/login'),
                          child: const Text(
                            'Masuk',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
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

class _GuestBenefit extends StatelessWidget {
  const _GuestBenefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155)),
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
      appBar: AppBar(
        titleSpacing: 0,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFF0284C7),
              child: Icon(Icons.public_rounded, color: Colors.white, size: 20),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Warga +62',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Obrolan seluruh pengguna',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      backgroundColor: AppColors.chatBackground,
      body: previewAsync.when(
        data: (result) {
          final (_, messages) = result;
          return Column(
            children: [
              Expanded(
                child: messages.isEmpty
                    ? const _ChatEmptyState(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'Belum ada pesan',
                        subtitle: 'Jadilah yang pertama menyapa warga!',
                      )
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.sizeOf(context).width * 0.78,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4),
                                  topRight: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    message.senderName ?? 'Pengguna',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    message.body,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      height: 1.35,
                                    ),
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
                color: Colors.white,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color: AppColors.mutedForeground,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Masuk untuk ikut mengirim pesan',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                        FilledButton(
                          onPressed: () => context.push('/account/login'),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Masuk'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ChatEmptyState(
          icon: Icons.wifi_off_rounded,
          title: 'Gagal memuat chat',
          subtitle: 'Periksa koneksi internetmu lalu coba lagi.',
          action: FilledButton.icon(
            onPressed: () => ref.invalidate(chatGlobalPreviewProvider),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Coba Lagi'),
          ),
        ),
      ),
    );
  }
}
