import 'dart:io';

import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/api/api_response.dart';
import '../models/face_profile.dart';
import '../models/potocandid_photo.dart';

class PotoCandidService {
  PotoCandidService(this._apiClient);

  final ApiClient _apiClient;

  Future<FaceProfile> uploadSelfie(File selfie) async {
    final formData = FormData.fromMap({
      'selfie': await MultipartFile.fromFile(selfie.path),
    });

    final response = await _apiClient.dio.post('/potocandid/face-profile', data: formData);
    return FaceProfile.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<FaceProfile?> getFaceProfile() async {
    try {
      final response = await _apiClient.dio.get('/potocandid/face-profile');
      return FaceProfile.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<PaginatedResult<PotoCandidPhoto>> browsePhotos({int page = 1, String? eventId}) async {
    final response = await _apiClient.dio.get('/potocandid/photos', queryParameters: {
      'page': page,
      'photo_event_id': eventId,
    });

    return _parsePaginated(response.data);
  }

  Future<PotoCandidPhoto> photoDetail(String photoId) async {
    final response = await _apiClient.dio.get('/potocandid/photos/$photoId');
    return PotoCandidPhoto.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<PaginatedResult<PotoCandidPhoto>> matchedPhotos({int page = 1}) async {
    final response = await _apiClient.dio.get('/potocandid/matched-photos', queryParameters: {'page': page});
    return _parsePaginated(response.data);
  }

  Future<PaginatedResult<PotoCandidPhoto>> purchases({int page = 1}) async {
    final response = await _apiClient.dio.get('/potocandid/purchases', queryParameters: {'page': page});

    final list = (response.data['data'] as List<dynamic>)
        .map((e) => PotoCandidPhoto.fromJson((e as Map<String, dynamic>)['photo'] as Map<String, dynamic>))
        .toList();
    final meta = PaginatedMeta.fromJson(response.data['meta'] as Map<String, dynamic>);

    return PaginatedResult<PotoCandidPhoto>(data: list, meta: meta);
  }

  Future<void> purchasePhoto(String photoId, {int matchedFaceIndex = 0}) async {
    await _apiClient.dio.post('/potocandid/purchases', data: {
      'photo_id': photoId,
      'matched_face_index': matchedFaceIndex,
    });
  }

  PaginatedResult<PotoCandidPhoto> _parsePaginated(Map<String, dynamic> data) {
    final list = (data['data'] as List<dynamic>)
        .map((e) => PotoCandidPhoto.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = PaginatedMeta.fromJson(data['meta'] as Map<String, dynamic>);

    return PaginatedResult<PotoCandidPhoto>(data: list, meta: meta);
  }
}
