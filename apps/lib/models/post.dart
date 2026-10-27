enum PostMediaType { image, video }

class PostMedia {
  PostMedia({
    required this.id,
    required this.url,
    this.type = PostMediaType.image,
    this.thumbnailUrl,
    this.durationSeconds,
  });

  factory PostMedia.fromJson(Map<String, dynamic> json) => PostMedia(
        id: json['id'] as String,
        url: json['url'] as String,
        type: json['type'] == 'video' ? PostMediaType.video : PostMediaType.image,
        thumbnailUrl: json['thumbnail_url'] as String?,
        durationSeconds: json['duration_seconds'] as int?,
      );

  final String id;
  final String url;
  final PostMediaType type;
  final String? thumbnailUrl;
  final int? durationSeconds;

  bool get isVideo => type == PostMediaType.video;
}

class PostProductTag {
  PostProductTag({
    required this.id,
    required this.name,
    required this.slug,
    required this.regularPrice,
    this.salePrice,
    this.imageUrl,
    this.thumbUrl,
  });

  factory PostProductTag.fromJson(Map<String, dynamic> json) => PostProductTag(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        regularPrice: double.tryParse(json['regular_price'].toString()) ?? 0,
        salePrice: json['sale_price'] != null ? double.tryParse(json['sale_price'].toString()) : null,
        imageUrl: json['image_url'] as String?,
        thumbUrl: json['thumb_url'] as String?,
      );

  final String id;
  final String name;
  final String slug;
  final double regularPrice;
  final double? salePrice;
  final String? imageUrl;
  final String? thumbUrl;

  String? get listImageUrl => thumbUrl ?? imageUrl;

  double get displayPrice => salePrice ?? regularPrice;
}

class Post {
  Post({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    this.body,
    this.media = const [],
    this.products = const [],
    this.sharedPost,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.isLiked = false,
    this.isMine = false,
    this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        userName: json['user_name'] as String? ?? 'Pengguna',
        userAvatarUrl: json['user_avatar_url'] as String?,
        body: json['body'] as String?,
        media: (json['media'] as List<dynamic>? ?? [])
            .map((e) => PostMedia.fromJson(e as Map<String, dynamic>))
            .toList(),
        products: (json['products'] as List<dynamic>? ?? [])
            .map((e) => PostProductTag.fromJson(e as Map<String, dynamic>))
            .toList(),
        sharedPost: json['shared_post'] != null ? Post.fromJson(json['shared_post'] as Map<String, dynamic>) : null,
        likeCount: json['like_count'] as int? ?? 0,
        commentCount: json['comment_count'] as int? ?? 0,
        shareCount: json['share_count'] as int? ?? 0,
        isLiked: json['is_liked'] as bool? ?? false,
        isMine: json['is_mine'] as bool? ?? false,
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      );

  final String id;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final String? body;
  final List<PostMedia> media;
  final List<PostProductTag> products;
  final Post? sharedPost;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final bool isLiked;
  final bool isMine;
  final DateTime? createdAt;

  Post copyWith({int? likeCount, bool? isLiked, int? commentCount, int? shareCount}) => Post(
        id: id,
        userId: userId,
        userName: userName,
        userAvatarUrl: userAvatarUrl,
        body: body,
        media: media,
        products: products,
        sharedPost: sharedPost,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        shareCount: shareCount ?? this.shareCount,
        isLiked: isLiked ?? this.isLiked,
        isMine: isMine,
        createdAt: createdAt,
      );
}

class PostComment {
  PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.body,
    this.createdAt,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) => PostComment(
        id: json['id'] as String,
        postId: json['post_id'] as String,
        userId: json['user_id'] as String,
        userName: json['user_name'] as String? ?? 'Pengguna',
        userAvatarUrl: json['user_avatar_url'] as String?,
        body: json['body'] as String,
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      );

  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final String body;
  final DateTime? createdAt;
}
