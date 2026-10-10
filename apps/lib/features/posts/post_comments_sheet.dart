import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import 'post_providers.dart';

class PostCommentsSheet extends ConsumerStatefulWidget {
  const PostCommentsSheet({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends ConsumerState<PostCommentsSheet> {
  final _controller = TextEditingController();
  final List<PostComment> _comments = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await ref
          .read(postServiceProvider)
          .comments(widget.postId);
      if (mounted) {
        setState(() {
          _comments
            ..clear()
            ..addAll(result.data);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final isAuthed = ref.read(authProvider).status == AuthStatus.authenticated;
    if (!isAuthed) {
      Navigator.of(context).pop();
      context.push('/account/login');
      return;
    }

    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final comment = await ref
          .read(postServiceProvider)
          .addComment(widget.postId, body);
      if (!mounted) return;
      setState(() {
        _comments.insert(0, comment);
        _controller.clear();
        _sending = false;
      });
      ref.read(feedProvider.notifier).incrementCommentCount(widget.postId);
    } finally {
      if (mounted && _sending) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Komentar',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                  ? const Center(
                      child: Text(
                        'Belum ada komentar.',
                        style: TextStyle(color: AppColors.mutedForeground),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) =>
                          _CommentTile(comment: _comments[index]),
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Tulis komentar...',
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final PostComment comment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.surface,
            backgroundImage: comment.userAvatarUrl != null
                ? CachedNetworkImageProvider(comment.userAvatarUrl!)
                : null,
            child: comment.userAvatarUrl == null
                ? const Icon(
                    Icons.person_outline,
                    size: 16,
                    color: AppColors.mutedForeground,
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    comment.userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(comment.body, style: const TextStyle(fontSize: 13.5)),
                  if (comment.createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      formatRelativeTime(comment.createdAt!),
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
