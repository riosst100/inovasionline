import 'dart:io';

import 'package:dio/dio.dart';
import '../core/api/api_client.dart';
import '../core/api/api_response.dart';
import '../models/post.dart';

class PostService {
  PostService(this._apiClient);

  final ApiClient _apiClient;

  Future<PaginatedResult<Post>> feed({int page = 1, int perPage = 15}) async {
    final response = await _apiClient.dio.get('/posts', queryParameters: {
      'page': page,
      'per_page': perPage,
    });

    final data = (response.data['data'] as List<dynamic>).map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
    final meta = PaginatedMeta.fromJson(response.data['meta'] as Map<String, dynamic>);

    return PaginatedResult<Post>(data: data, meta: meta);
  }

  Future<Post> createPost({
    String? body,
    List<File> media = const [],
    List<String> productIds = const [],
    File? video,
    File? videoThumbnail,
    int? videoDurationSeconds,
  }) async {
    final formData = FormData();

    if (body != null && body.isNotEmpty) {
      formData.fields.add(MapEntry('body', body));
    }
    for (final id in productIds) {
      formData.fields.add(MapEntry('product_ids[]', id));
    }
    for (final file in media) {
      formData.files.add(MapEntry('media[]', await MultipartFile.fromFile(file.path)));
    }
    if (video != null) {
      formData.files.add(MapEntry('video', await MultipartFile.fromFile(video.path)));
      if (videoThumbnail != null) {
        formData.files.add(MapEntry('video_thumbnail', await MultipartFile.fromFile(videoThumbnail.path)));
      }
      if (videoDurationSeconds != null) {
        formData.fields.add(MapEntry('video_duration_seconds', '$videoDurationSeconds'));
      }
    }

    final response = await _apiClient.dio.post('/posts', data: formData);
    return Post.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Post> sharePost(String postId, {String? body}) async {
    final response = await _apiClient.dio.post('/posts/$postId/share', data: {'body': body});
    return Post.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> deletePost(String postId) async {
    await _apiClient.dio.delete('/posts/$postId');
  }

  Future<bool> toggleLike(String postId) async {
    final response = await _apiClient.dio.post('/posts/$postId/like');
    return (response.data['data'] as Map<String, dynamic>)['liked'] as bool;
  }

  Future<PaginatedResult<PostComment>> comments(String postId, {int page = 1}) async {
    final response = await _apiClient.dio.get('/posts/$postId/comments', queryParameters: {'page': page});

    final data =
        (response.data['data'] as List<dynamic>).map((e) => PostComment.fromJson(e as Map<String, dynamic>)).toList();
    final meta = PaginatedMeta.fromJson(response.data['meta'] as Map<String, dynamic>);

    return PaginatedResult<PostComment>(data: data, meta: meta);
  }

  Future<PostComment> addComment(String postId, String body) async {
    final response = await _apiClient.dio.post('/posts/$postId/comments', data: {'body': body});
    return PostComment.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteComment(String commentId) async {
    await _apiClient.dio.delete('/posts/comments/$commentId');
  }
}
