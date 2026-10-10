import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_exception.dart';
import '../../models/post.dart';
import '../../providers/core_providers.dart';

String _errorMessage(Object error, String fallback) {
  if (error is DioException && error.error is ApiException) {
    return (error.error as ApiException).message;
  }
  return fallback;
}

class FeedState {
  const FeedState({
    this.posts = const [],
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<Post> posts;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? error;

  FeedState copyWith({
    List<Post>? posts,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    String? error,
  }) =>
      FeedState(
        posts: posts ?? this.posts,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        hasMore: hasMore ?? this.hasMore,
        error: error,
      );
}

class FeedNotifier extends StateNotifier<FeedState> {
  FeedNotifier(this._ref) : super(const FeedState());

  final Ref _ref;
  int _page = 1;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final result = await _ref.read(postServiceProvider).feed(page: 1);
      _page = 1;
      state = FeedState(posts: result.data, hasMore: result.meta.hasMore);
    } catch (e) {
      state = state.copyWith(loading: false, error: _errorMessage(e, 'Gagal memuat postingan.'));
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;

    state = state.copyWith(loadingMore: true);
    try {
      final result = await _ref.read(postServiceProvider).feed(page: _page + 1);
      _page++;
      state = state.copyWith(
        posts: [...state.posts, ...result.data],
        loadingMore: false,
        hasMore: result.meta.hasMore,
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false);
    }
  }

  Future<void> createPost({
    String? body,
    List<File> media = const [],
    List<String> productIds = const [],
    File? video,
    File? videoThumbnail,
    int? videoDurationSeconds,
  }) async {
    final post = await _ref.read(postServiceProvider).createPost(
          body: body,
          media: media,
          productIds: productIds,
          video: video,
          videoThumbnail: videoThumbnail,
          videoDurationSeconds: videoDurationSeconds,
        );
    state = state.copyWith(posts: [post, ...state.posts]);
  }

  Future<void> toggleLike(String postId) async {
    final index = state.posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = state.posts[index];
    final optimistic = post.copyWith(
      isLiked: !post.isLiked,
      likeCount: post.isLiked ? post.likeCount - 1 : post.likeCount + 1,
    );
    _replacePost(optimistic);

    try {
      await _ref.read(postServiceProvider).toggleLike(postId);
    } catch (_) {
      _replacePost(post);
    }
  }

  Future<void> sharePost(String postId, {String? body}) async {
    final shared = await _ref.read(postServiceProvider).sharePost(postId, body: body);
    state = state.copyWith(posts: [shared, ..._incrementShareCount(postId)]);
  }

  List<Post> _incrementShareCount(String postId) {
    return state.posts
        .map((p) => p.id == postId ? p.copyWith(shareCount: p.shareCount + 1) : p)
        .toList();
  }

  Future<void> deletePost(String postId) async {
    final previous = state.posts;
    state = state.copyWith(posts: previous.where((p) => p.id != postId).toList());
    try {
      await _ref.read(postServiceProvider).deletePost(postId);
    } catch (e) {
      state = state.copyWith(posts: previous, error: _errorMessage(e, 'Gagal menghapus postingan.'));
    }
  }

  void incrementCommentCount(String postId) {
    final index = state.posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    _replacePost(state.posts[index].copyWith(commentCount: state.posts[index].commentCount + 1));
  }

  void _replacePost(Post post) {
    state = state.copyWith(
      posts: state.posts.map((p) => p.id == post.id ? post : p).toList(),
    );
  }
}

final feedProvider = StateNotifierProvider<FeedNotifier, FeedState>((ref) => FeedNotifier(ref));
