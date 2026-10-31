import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/api_response.dart';
import '../../models/post.dart';
import '../../models/region.dart';
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

/// Resmi: posts by users with the admin-granted verified badge. Publik: everyone's (those included),
/// filterable by region.
enum PostTab {
  official('official', 'Info Resmi'),
  public('public', 'Postingan Publik');

  const PostTab(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// The tabs a post shows in.
  static List<PostTab> forPost(Post post) => post.userVerifiedBadge ? values : const [public];
}

/// Region filter of the Publik tab; any level may be left empty (only the narrowest chosen one applies).
class PostRegionFilter {
  const PostRegionFilter({this.province, this.city, this.district, this.village});

  factory PostRegionFilter.fromJson(Map<String, dynamic> json) {
    Region? region(String key) =>
        json[key] is Map<String, dynamic> ? Region.fromJson(json[key] as Map<String, dynamic>) : null;
    return PostRegionFilter(
      province: region('province'),
      city: region('city'),
      district: region('district'),
      village: region('village'),
    );
  }

  final Region? province;
  final Region? city;
  final Region? district;
  final Region? village;

  /// The narrowest chosen region, e.g. the village; null shows every location.
  Region? get narrowest => village ?? district ?? city ?? province;

  bool get isEmpty => narrowest == null;

  Map<String, String> toQuery() => {
        'province_code': ?province?.code,
        'city_code': ?city?.code,
        'district_code': ?district?.code,
        'village_code': ?village?.code,
      };

  Map<String, dynamic> toJson() => {
        'province': province?.toJson(),
        'city': city?.toJson(),
        'district': district?.toJson(),
        'village': village?.toJson(),
      };
}

class PostRegionFilterNotifier extends StateNotifier<PostRegionFilter> {
  PostRegionFilterNotifier() : super(const PostRegionFilter()) {
    _restore();
  }

  static const _key = 'posts_region_filter';
  final _storage = const FlutterSecureStorage();

  /// Completes once the saved filter is loaded, so the first Publik load uses it.
  late final Future<void> ready = _restoreDone.future;
  final _restoreDone = Completer<void>();

  Future<void> _restore() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw != null && mounted) state = PostRegionFilter.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Unreadable or old format: start with every location.
    } finally {
      _restoreDone.complete();
    }
  }

  Future<void> set(PostRegionFilter filter) async {
    state = filter;
    await _storage.write(key: _key, value: jsonEncode(filter.toJson()));
  }
}

final postRegionFilterProvider =
    StateNotifierProvider<PostRegionFilterNotifier, PostRegionFilter>((ref) => PostRegionFilterNotifier());

/// Unread badge counts per tab, per post: of each tab's newest [limit] posts, those not yet shown on this
/// device. Older posts never count. Shown ids are stored on the device, so guests get badges too.
class PostUnreadNotifier extends StateNotifier<Map<PostTab, int>> {
  PostUnreadNotifier(this._ref) : super(const {});

  /// Same as the backend's PostService::UNREAD_LIMIT.
  static const limit = 100;

  static const _key = 'posts_seen_ids';

  /// Enough to cover both tabs' newest posts plus a few region filters.
  static const _maxStored = 1000;

  final Ref _ref;
  final _storage = const FlutterSecureStorage();

  /// Shown post ids, oldest mark first (a LinkedHashSet keeps insertion order for trimming).
  final _seen = <String>{};
  late final Future<void> _loaded = _load();
  Map<PostTab, List<String>> _recent = const {};
  Timer? _saveTimer;

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw != null) _seen.addAll((jsonDecode(raw) as List<dynamic>).cast<String>());
    } catch (_) {
      // Unreadable: every recent post counts as unread again.
    }
  }

  Future<void>? _refreshing;

  /// Fetches the tabs' newest post ids; calls made while one is running share it.
  Future<void> refresh() => _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  /// The tab's newest posts not shown yet (at most [limit]), as of the last [refresh].
  List<String> unreadIds(PostTab tab) =>
      (_recent[tab] ?? const []).where((id) => !_seen.contains(id)).toList();

  Future<void> _refresh() async {
    try {
      await _loaded;
      await _ref.read(postRegionFilterProvider.notifier).ready;
      final recent = await _ref.read(postServiceProvider).recentIds(
            region: _ref.read(postRegionFilterProvider).toQuery(),
          );
      if (!mounted) return;
      _recent = {for (final tab in PostTab.values) tab: recent[tab.apiValue] ?? const []};
      _recount();
    } catch (_) {
      // Badges are a hint; keep the last counts when offline.
    }
  }

  /// The post was shown in a feed; it no longer counts as unread.
  Future<void> markSeen(String postId) async {
    await _loaded;
    if (!_seen.add(postId)) return;
    if (_seen.length > _maxStored) _seen.remove(_seen.first);
    if (mounted) _recount();
    // Cards are marked while scrolling; write once things settle.
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), _save);
  }

  void _recount() {
    state = {for (final tab in PostTab.values) tab: unreadIds(tab).length};
  }

  Future<void> _save() => _storage.write(key: _key, value: jsonEncode(_seen.toList()));

  @override
  void dispose() {
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      _save();
    }
    super.dispose();
  }
}

final postUnreadProvider =
    StateNotifierProvider<PostUnreadNotifier, Map<PostTab, int>>((ref) => PostUnreadNotifier(ref));

enum PostSort {
  relevance('relevance', 'Relevansi'),
  newest('newest', 'Terbaru'),
  oldest('oldest', 'Terlama');

  const PostSort(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

/// Feed order of both tabs. Relevansi (unread first, then newest) each time the app starts.
final postSortProvider = StateProvider<PostSort>((ref) => PostSort.relevance);

class FeedNotifier extends StateNotifier<FeedState> {
  FeedNotifier(this._ref, this.tab) : super(const FeedState());

  final Ref _ref;
  final PostTab tab;
  int _page = 1;

  /// Unread ids sent for Relevansi, fixed at the first page: cards get marked read while scrolling, and
  /// a changing list would shift posts between pages.
  List<String> _unreadIds = const [];

  Future<PaginatedResult<Post>> _fetch(int page) async {
    var region = const <String, String>{};
    if (tab == PostTab.public) {
      await _ref.read(postRegionFilterProvider.notifier).ready;
      region = _ref.read(postRegionFilterProvider).toQuery();
    }
    final sort = _ref.read(postSortProvider);
    if (page == 1) {
      _unreadIds = const [];
      if (sort == PostSort.relevance) {
        final unread = _ref.read(postUnreadProvider.notifier);
        await unread.refresh();
        _unreadIds = unread.unreadIds(tab);
      }
    }
    return _ref.read(postServiceProvider).feed(
          page: page,
          tab: tab.apiValue,
          region: region,
          sort: sort.apiValue,
          unreadIds: _unreadIds,
        );
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final result = await _fetch(1);
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
      final result = await _fetch(_page + 1);
      _page++;
      // A post made since the first page pushes the rest down one; don't show it twice.
      final shown = state.posts.map((p) => p.id).toSet();
      state = state.copyWith(
        posts: [...state.posts, ...result.data.where((p) => !shown.contains(p.id))],
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
    // Goes to the author's tabs (Resmi too for badge holders), whichever tab started it.
    for (final tab in PostTab.forPost(post)) {
      _ref.read(feedProvider(tab).notifier).prepend(post);
    }
  }

  void prepend(Post post) {
    state = state.copyWith(posts: [post, ...state.posts]);
  }

  void remove(String postId) {
    state = state.copyWith(posts: state.posts.where((p) => p.id != postId).toList());
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
    state = state.copyWith(posts: _incrementShareCount(postId));
    for (final tab in PostTab.forPost(shared)) {
      _ref.read(feedProvider(tab).notifier).prepend(shared);
    }
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
      // A badge holder's post is in both tabs.
      for (final other in PostTab.values.where((t) => t != tab)) {
        _ref.read(feedProvider(other).notifier).remove(postId);
      }
    } catch (e) {
      state = state.copyWith(posts: previous, error: _errorMessage(e, 'Gagal menghapus postingan.'));
    }
  }

  void incrementCommentCount(String postId, {int by = 1}) {
    final index = state.posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    _replacePost(state.posts[index].copyWith(commentCount: state.posts[index].commentCount + by));
  }

  void _replacePost(Post post) {
    state = state.copyWith(
      posts: state.posts.map((p) => p.id == post.id ? post : p).toList(),
    );
  }
}

final feedProvider =
    StateNotifierProvider.family<FeedNotifier, FeedState, PostTab>((ref, tab) => FeedNotifier(ref, tab));
