import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../config/theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/post.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/skeleton.dart';
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

class _PostsScreenState extends ConsumerState<PostsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(feedProvider.notifier).load());
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
      ref.read(feedProvider.notifier).loadMore();
    }
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

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Postingan')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(feedProvider.notifier).load(),
        child: feedState.loading && feedState.posts.isEmpty
            ? const _FeedSkeleton()
            : feedState.posts.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _PostComposer(onTap: _openCreatePost),
                  const SizedBox(height: 120),
                  const Icon(
                    Icons.dynamic_feed_outlined,
                    size: 56,
                    color: AppColors.mutedForeground,
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'Belum ada postingan',
                      style: TextStyle(color: AppColors.mutedForeground),
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
                    return Column(
                      children: [
                        _PostComposer(onTap: _openCreatePost),
                      ],
                    );
                  }
                  final postIndex = index - 1;
                  if (postIndex >= feedState.posts.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final post = _PostCard(post: feedState.posts[postIndex]);
                  final adEvery = ref.watch(admobProvider).value?.postsNativeEvery ?? 0;
                  if (adEvery <= 0 || (postIndex + 1) % adEvery != 0) return post;
                  return Column(
                    children: [post, const Divider(height: 1), const NativeFeedAd()],
                  );
                },
              ),
      ),
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
  const _PostCard({required this.post});

  final Post post;

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
      await ref.read(feedProvider.notifier).deletePost(post.id);
    }
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final isAuthed = ref.read(authProvider).status == AuthStatus.authenticated;
    if (!isAuthed) {
      context.push('/account/login');
      return;
    }
    await ref.read(feedProvider.notifier).sharePost(post.id);
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
    await ref.read(feedProvider.notifier).toggleLike(post.id);
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
                    Text(
                      post.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
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
              if (post.isMine)
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

class _PostVideoPlayerState extends State<_PostVideoPlayer> {
  VideoPlayerController? _controller;
  bool _loading = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
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
              Text(
                post.userName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
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
