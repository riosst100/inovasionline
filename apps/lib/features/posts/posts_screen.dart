import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../config/theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/post.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/address_picker.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/user_badges.dart';
import '../ads/admob.dart';
import '../ads/native_feed_ad.dart';
import 'create_post_screen.dart';
import 'post_comments_sheet.dart';
import 'post_providers.dart';

class _PostComposer extends ConsumerWidget {
  const _PostComposer({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.background,
                  backgroundImage: user?.avatarUrl != null
                      ? CachedNetworkImageProvider(user!.avatarUrl!)
                      : null,
                  child: user?.avatarUrl == null
                      ? const Icon(
                          Icons.person_outline,
                          color: AppColors.mutedForeground,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Apa yang Anda pikirkan?',
                    style: const TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 14,
                    ),
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

class PostsScreen extends ConsumerStatefulWidget {
  const PostsScreen({super.key});

  @override
  ConsumerState<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends ConsumerState<PostsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabController =
      TabController(length: PostTab.values.length, vsync: this);
  Timer? _unreadTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      for (final tab in PostTab.values) {
        ref.read(feedProvider(tab).notifier).load();
      }
      _refreshUnread();
    });
    _unreadTimer = Timer.periodic(const Duration(minutes: 1), (_) => _refreshUnread());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unreadTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshUnread();
  }

  void _refreshUnread() => ref.read(postUnreadProvider.notifier).refresh();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Postingan'),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: [for (final tab in PostTab.values) Tab(child: _TabLabel(tab: tab))],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final tab in PostTab.values)
            _FeedTab(key: PageStorageKey(tab), tab: tab, onRefreshUnread: _refreshUnread),
        ],
      ),
    );
  }
}

class _TabLabel extends ConsumerWidget {
  const _TabLabel({required this.tab});

  final PostTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(postUnreadProvider)[tab] ?? 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Same blue check as on badge holders' names; the globe takes the tab's color.
        tab == PostTab.official
            ? const Icon(Icons.verified, size: 18, color: verifiedBadgeColor)
            : const Icon(Icons.public, size: 18),
        const SizedBox(width: 6),
        Flexible(child: Text(tab.label, overflow: TextOverflow.ellipsis)),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            constraints: const BoxConstraints(minWidth: 18),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.destructive,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              // At the limit there may be more; older posts are not counted.
              count >= PostUnreadNotifier.limit ? '${PostUnreadNotifier.limit}+' : '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// One tab's feed; kept alive so switching tabs keeps its scroll position and loaded pages.
class _FeedTab extends ConsumerStatefulWidget {
  const _FeedTab({super.key, required this.tab, required this.onRefreshUnread});

  final PostTab tab;
  final VoidCallback onRefreshUnread;

  @override
  ConsumerState<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends ConsumerState<_FeedTab>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(feedProvider(widget.tab).notifier).loadMore();
    }
  }

  Future<void> _refresh() async {
    widget.onRefreshUnread();
    await ref.read(feedProvider(widget.tab).notifier).load();
  }

  Future<void> _openCreatePost() async {
    final isAuthed = ref.read(authProvider).status == AuthStatus.authenticated;
    if (!isAuthed) {
      context.push('/account/login');
      return;
    }
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const CreatePostScreen()));
  }

  Future<void> _openRegionFilter() async {
    final current = ref.read(postRegionFilterProvider);
    final picked = await showModalBottomSheet<PostRegionFilter>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RegionFilterSheet(initial: current),
    );
    if (picked == null) return;
    await _applyRegionFilter(picked);
  }

  Future<void> _applyRegionFilter(PostRegionFilter filter) async {
    await ref.read(postRegionFilterProvider.notifier).set(filter);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    await _refresh();
  }

  Future<void> _changeSort(PostSort sort) async {
    if (sort == ref.read(postSortProvider)) return;
    ref.read(postSortProvider.notifier).state = sort;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    // Both tabs share the order; the other one reloads too.
    await Future.wait([
      for (final tab in PostTab.values) ref.read(feedProvider(tab).notifier).load(),
    ]);
  }

  List<Widget> _header() => [
        _PostComposer(onTap: _openCreatePost),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: widget.tab == PostTab.public
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: _RegionFilterBar(
                          onTap: _openRegionFilter,
                          onClear: () => _applyRegionFilter(const PostRegionFilter()),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              _SortMenu(onChanged: _changeSort),
            ],
          ),
        ),
      ];

  String get _emptyMessage {
    if (widget.tab == PostTab.official) return 'Belum ada postingan resmi';
    final region = ref.watch(postRegionFilterProvider).narrowest;
    return region == null ? 'Belum ada postingan' : 'Belum ada postingan di ${region.name}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feedState = ref.watch(feedProvider(widget.tab));

    return RefreshIndicator(
        onRefresh: _refresh,
        child: feedState.loading && feedState.posts.isEmpty
            ? const _FeedSkeleton()
            : feedState.posts.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  ..._header(),
                  const SizedBox(height: 120),
                  const Icon(
                    Icons.dynamic_feed_outlined,
                    size: 56,
                    color: AppColors.mutedForeground,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      feedState.error ?? _emptyMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.mutedForeground),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount:
                    feedState.posts.length + 1 + (feedState.hasMore ? 1 : 0),
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(children: _header());
                  }
                  final postIndex = index - 1;
                  if (postIndex >= feedState.posts.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final post = _SeenMarker(
                    postId: feedState.posts[postIndex].id,
                    child: _PostCard(post: feedState.posts[postIndex], tab: widget.tab),
                  );
                  final adEvery = ref.watch(admobProvider).value?.postsNativeEvery ?? 0;
                  if (adEvery <= 0 || (postIndex + 1) % adEvery != 0) return post;
                  return Column(
                    children: [post, const Divider(height: 1), const NativeFeedAd()],
                  );
                },
              ),
    );
  }
}

/// Marks the post as seen (no longer unread in the tab badges) once its card is laid out in the feed;
/// the list builds cards lazily, so that is when it scrolls into (or just below) view.
class _SeenMarker extends ConsumerStatefulWidget {
  const _SeenMarker({required this.postId, required this.child});

  final String postId;
  final Widget child;

  @override
  ConsumerState<_SeenMarker> createState() => _SeenMarkerState();
}

class _SeenMarkerState extends ConsumerState<_SeenMarker> {
  @override
  void initState() {
    super.initState();
    // After the frame: providers can't change while the list is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(postUnreadProvider.notifier).markSeen(widget.postId);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Publik tab: which location the feed is narrowed to.
class _RegionFilterBar extends ConsumerWidget {
  const _RegionFilterBar({required this.onTap, required this.onClear});

  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final region = ref.watch(postRegionFilterProvider).narrowest;

    return InputChip(
      avatar: Icon(
        Icons.location_on_outlined,
        size: 18,
        color: region == null ? AppColors.mutedForeground : AppColors.primary,
      ),
      label: Text(
        region?.name ?? 'Semua lokasi',
        overflow: TextOverflow.ellipsis,
      ),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: region == null ? AppColors.foreground : AppColors.primary,
      ),
      selected: region != null,
      showCheckmark: false,
      selectedColor: AppColors.primary.withValues(alpha: 0.1),
      onPressed: onTap,
      onDeleted: region == null ? null : onClear,
      deleteIconColor: AppColors.primary,
    );
  }
}

/// Feed order: Relevansi (unread first), Terbaru or Terlama; shared by both tabs.
class _SortMenu extends ConsumerWidget {
  const _SortMenu({required this.onChanged});

  final ValueChanged<PostSort> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(postSortProvider);

    return PopupMenuButton<PostSort>(
      initialValue: sort,
      onSelected: onChanged,
      tooltip: 'Urutkan',
      itemBuilder: (context) => [
        for (final option in PostSort.values)
          PopupMenuItem(
            value: option,
            child: Text(
              option == PostSort.relevance ? '${option.label} (belum dibaca dulu)' : option.label,
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort_rounded, size: 18, color: AppColors.mutedForeground),
            const SizedBox(width: 4),
            Text(
              sort.label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const Icon(Icons.arrow_drop_down, size: 20, color: AppColors.mutedForeground),
          ],
        ),
      ),
    );
  }
}

class _RegionFilterSheet extends StatefulWidget {
  const _RegionFilterSheet({required this.initial});

  final PostRegionFilter initial;

  @override
  State<_RegionFilterSheet> createState() => _RegionFilterSheetState();
}

class _RegionFilterSheetState extends State<_RegionFilterSheet> {
  late AddressSelection _selection = AddressSelection(
    province: widget.initial.province,
    city: widget.initial.city,
    district: widget.initial.district,
    village: widget.initial.village,
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Filter Lokasi',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pilih sampai tingkat yang diinginkan, misalnya cukup kecamatan atau sampai desa.',
              style: TextStyle(fontSize: 12.5, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 16),
            AddressPicker(
              initial: _selection,
              required: false,
              onChanged: (selection) => setState(() => _selection = selection),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(const PostRegionFilter()),
                    child: const Text('Semua lokasi'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(PostRegionFilter(
                      province: _selection.province,
                      city: _selection.city,
                      district: _selection.district,
                      village: _selection.village,
                    )),
                    child: const Text('Terapkan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthorName extends StatelessWidget {
  const _AuthorName({required this.post, required this.fontSize});

  final Post post;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return UserNameWithBadges(
      name: post.userName,
      verified: post.userVerifiedBadge,
      adminBadge: post.userAdminBadge,
      style: TextStyle(fontWeight: FontWeight.w600, fontSize: fontSize),
    );
  }
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 20),
      itemBuilder: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Skeleton(width: 40, height: 40, borderRadius: 20),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Skeleton(width: 120, height: 12),
                  SizedBox(height: 6),
                  Skeleton(width: 80, height: 10),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Skeleton(width: double.infinity, height: 14),
          const SizedBox(height: 6),
          Skeleton(width: 220, height: 14),
          const SizedBox(height: 12),
          const Skeleton(width: double.infinity, height: 180, borderRadius: 12),
        ],
      ),
    );
  }
}

class _PostCard extends ConsumerWidget {
  const _PostCard({required this.post, required this.tab});

  final Post post;
  final PostTab tab;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hapus Postingan'),
            content: const Text(
              'Apakah Anda yakin ingin menghapus postingan ini?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Hapus'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      await ref.read(feedProvider(tab).notifier).deletePost(post.id);
    }
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final isAuthed = ref.read(authProvider).status == AuthStatus.authenticated;
    if (!isAuthed) {
      context.push('/account/login');
      return;
    }
    await ref.read(feedProvider(tab).notifier).sharePost(post.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Postingan dibagikan.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleLike(BuildContext context, WidgetRef ref) async {
    final isAuthed = ref.read(authProvider).status == AuthStatus.authenticated;
    if (!isAuthed) {
      context.push('/account/login');
      return;
    }
    await ref.read(feedProvider(tab).notifier).toggleLike(post.id);
  }

  void _openComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PostCommentsSheet(postId: post.id),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.surface,
                backgroundImage: post.userAvatarUrl != null
                    ? CachedNetworkImageProvider(post.userAvatarUrl!)
                    : null,
                child: post.userAvatarUrl == null
                    ? const Icon(
                        Icons.person_outline,
                        color: AppColors.mutedForeground,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AuthorName(post: post, fontSize: 14),
                    if (post.createdAt != null)
                      Text(
                        formatRelativeTime(post.createdAt!),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ),
              // The author, or an admin of the post's region.
              if (post.canModerate)
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_horiz,
                    color: AppColors.mutedForeground,
                  ),
                  onSelected: (value) {
                    if (value == 'delete') _confirmDelete(context, ref);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'delete', child: Text('Hapus')),
                  ],
                ),
            ],
          ),
          if (post.body != null && post.body!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(post.body!, style: const TextStyle(fontSize: 14, height: 1.4)),
          ],
          if (post.media.isNotEmpty) ...[
            const SizedBox(height: 10),
            _PostMediaGrid(media: post.media),
          ],
          if (post.products.isNotEmpty) ...[
            const SizedBox(height: 10),
            _PostProductTags(products: post.products),
          ],
          if (post.sharedPost != null) ...[
            const SizedBox(height: 10),
            _SharedPostPreview(post: post.sharedPost!),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _ActionButton(
                icon: post.isLiked ? Icons.favorite : Icons.favorite_outline,
                label: '${post.likeCount}',
                color: post.isLiked
                    ? AppColors.destructive
                    : AppColors.mutedForeground,
                onTap: () => _toggleLike(context, ref),
              ),
              const SizedBox(width: 20),
              _ActionButton(
                icon: Icons.mode_comment_outlined,
                label: '${post.commentCount}',
                color: AppColors.mutedForeground,
                onTap: () => _openComments(context),
              ),
              const SizedBox(width: 20),
              _ActionButton(
                icon: Icons.repeat,
                label: '${post.shareCount}',
                color: AppColors.mutedForeground,
                onTap: () => _share(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostMediaGrid extends StatelessWidget {
  const _PostMediaGrid({required this.media});

  final List<PostMedia> media;

  @override
  Widget build(BuildContext context) {
    if (media.length == 1 && media.first.isVideo) {
      return _PostVideoPlayer(media: media.first);
    }

    if (media.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 1.3,
          child: CachedNetworkImage(memCacheWidth: 800, imageUrl: media.first.url,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: media.length > 4 ? 4 : media.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 3,
          crossAxisSpacing: 3,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, index) {
          final isLastVisible = index == 3 && media.length > 4;
          return Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(memCacheWidth: 800, imageUrl: media[index].url, fit: BoxFit.cover),
              if (isLastVisible)
                Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  alignment: Alignment.center,
                  child: Text(
                    '+${media.length - 4}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PostVideoPlayer extends StatefulWidget {
  const _PostVideoPlayer({required this.media});

  final PostMedia media;

  @override
  State<_PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<_PostVideoPlayer> with WidgetsBindingObserver {
  /// The video that is playing now. Starting another one releases this one, so only a single
  /// decoder runs at a time (several looping videos at once is a big battery and CPU cost).
  static _PostVideoPlayerState? _active;

  VideoPlayerController? _controller;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_active == this) _active = null;
    _controller?.dispose();
    super.dispose();
  }

  /// Nothing plays while the app is in the background; tap to resume.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _controller?.pause();
      if (mounted) setState(() {});
    }
  }

  /// Another video took over: free this decoder and go back to the poster.
  void _release() {
    final controller = _controller;
    if (controller == null) return;
    if (mounted) setState(() => _controller = null);
    // After the frame, so the VideoPlayer widget is gone before its controller is disposed.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  }

  Future<void> _play() async {
    setState(() => _loading = true);
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.media.url),
    );
    try {
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      final previous = _active;
      _active = this;
      previous?._release();
      setState(() {
        _controller = controller;
        _loading = false;
      });
      controller.play();
      controller.setLooping(true);
    } catch (_) {
      controller.dispose();
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: ready ? controller.value.aspectRatio : 16 / 9,
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            if (ready)
              VideoPlayer(controller)
            else if (widget.media.thumbnailUrl != null)
              CachedNetworkImage(memCacheWidth: 800, imageUrl: widget.media.thumbnailUrl!,
                fit: BoxFit.cover,
              )
            else
              Container(color: AppColors.surface),
            if (!ready)
              InkWell(
                onTap: _loading ? null : _play,
                child: Container(
                  color: Colors.black26,
                  child: Center(
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Icon(
                            Icons.play_circle_fill,
                            color: Colors.white,
                            size: 56,
                          ),
                  ),
                ),
              ),
            if (ready)
              Positioned.fill(
                child: InkWell(
                  onTap: () => setState(() {
                    controller.value.isPlaying
                        ? controller.pause()
                        : controller.play();
                  }),
                  child: controller.value.isPlaying
                      ? null
                      : const Center(
                          child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 56),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PostProductTags extends StatelessWidget {
  const _PostProductTags({required this.products});

  final List<PostProductTag> products;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final product = products[index];
          return InkWell(
            onTap: () => context.push('/products/${product.slug}'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 200,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: product.listImageUrl != null
                          ? CachedNetworkImage(memCacheWidth: 200, imageUrl: product.listImageUrl!,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: AppColors.surface,
                              child: const Icon(Icons.image_outlined, size: 20),
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatCurrency(product.displayPrice),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SharedPostPreview extends StatelessWidget {
  const _SharedPostPreview({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.surface,
                backgroundImage: post.userAvatarUrl != null
                    ? CachedNetworkImageProvider(post.userAvatarUrl!)
                    : null,
                child: post.userAvatarUrl == null
                    ? const Icon(
                        Icons.person_outline,
                        size: 14,
                        color: AppColors.mutedForeground,
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Flexible(child: _AuthorName(post: post, fontSize: 12.5)),
            ],
          ),
          if (post.body != null && post.body!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(post.body!, style: const TextStyle(fontSize: 13)),
          ],
          if (post.media.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 1.5,
                child: CachedNetworkImage(memCacheWidth: 800, imageUrl: post.media.first.url,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
