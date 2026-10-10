import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../models/face_profile.dart';
import '../../models/potocandid_photo.dart';
import '../../providers/core_providers.dart';

String _errorMessage(Object error, String fallback) {
  if (error is DioException && error.error is ApiException) {
    return (error.error as ApiException).message;
  }
  return fallback;
}

enum SelfieUploadStatus { idle, uploading, success, error }

class PotoCandidState {
  const PotoCandidState({
    this.faceProfile,
    this.faceProfileLoading = false,
    this.browsePhotos = const [],
    this.browseLoading = false,
    this.matchedPhotos = const [],
    this.matchedLoading = false,
    this.purchasedPhotos = const [],
    this.purchasesLoading = false,
    this.selfieUploadStatus = SelfieUploadStatus.idle,
    this.error,
  });

  final FaceProfile? faceProfile;
  final bool faceProfileLoading;
  final List<PotoCandidPhoto> browsePhotos;
  final bool browseLoading;
  final List<PotoCandidPhoto> matchedPhotos;
  final bool matchedLoading;
  final List<PotoCandidPhoto> purchasedPhotos;
  final bool purchasesLoading;
  final SelfieUploadStatus selfieUploadStatus;
  final String? error;

  bool get hasFaceProfile => faceProfile != null;

  PotoCandidState copyWith({
    FaceProfile? faceProfile,
    bool clearFaceProfile = false,
    bool? faceProfileLoading,
    List<PotoCandidPhoto>? browsePhotos,
    bool? browseLoading,
    List<PotoCandidPhoto>? matchedPhotos,
    bool? matchedLoading,
    List<PotoCandidPhoto>? purchasedPhotos,
    bool? purchasesLoading,
    SelfieUploadStatus? selfieUploadStatus,
    String? error,
  }) =>
      PotoCandidState(
        faceProfile: clearFaceProfile ? null : (faceProfile ?? this.faceProfile),
        faceProfileLoading: faceProfileLoading ?? this.faceProfileLoading,
        browsePhotos: browsePhotos ?? this.browsePhotos,
        browseLoading: browseLoading ?? this.browseLoading,
        matchedPhotos: matchedPhotos ?? this.matchedPhotos,
        matchedLoading: matchedLoading ?? this.matchedLoading,
        purchasedPhotos: purchasedPhotos ?? this.purchasedPhotos,
        purchasesLoading: purchasesLoading ?? this.purchasesLoading,
        selfieUploadStatus: selfieUploadStatus ?? this.selfieUploadStatus,
        error: error,
      );
}

class PotoCandidNotifier extends StateNotifier<PotoCandidState> {
  PotoCandidNotifier(this._ref) : super(const PotoCandidState());

  final Ref _ref;

  Future<void> loadFaceProfileStatus() async {
    state = state.copyWith(faceProfileLoading: true, error: null);
    try {
      final profile = await _ref.read(potoCandidServiceProvider).getFaceProfile();
      state = state.copyWith(
        faceProfile: profile,
        clearFaceProfile: profile == null,
        faceProfileLoading: false,
      );
    } catch (e) {
      state = state.copyWith(faceProfileLoading: false, error: _errorMessage(e, 'Gagal memuat profil wajah.'));
    }
  }

  Future<void> uploadSelfie(File file) async {
    state = state.copyWith(selfieUploadStatus: SelfieUploadStatus.uploading, error: null);
    try {
      final profile = await _ref.read(potoCandidServiceProvider).uploadSelfie(file);
      state = state.copyWith(faceProfile: profile, selfieUploadStatus: SelfieUploadStatus.success);
    } catch (e) {
      state = state.copyWith(
        selfieUploadStatus: SelfieUploadStatus.error,
        error: _errorMessage(e, 'Gagal mengunggah selfie.'),
      );
    }
  }

  Future<void> loadBrowsePhotos({int page = 1}) async {
    state = state.copyWith(browseLoading: true, error: null);
    try {
      final result = await _ref.read(potoCandidServiceProvider).browsePhotos(page: page);
      state = state.copyWith(browsePhotos: result.data, browseLoading: false);
    } catch (e) {
      state = state.copyWith(browseLoading: false, error: _errorMessage(e, 'Gagal memuat foto.'));
    }
  }

  Future<void> loadMatchedPhotos({int page = 1}) async {
    state = state.copyWith(matchedLoading: true, error: null);
    try {
      final result = await _ref.read(potoCandidServiceProvider).matchedPhotos(page: page);
      state = state.copyWith(matchedPhotos: result.data, matchedLoading: false);
    } catch (e) {
      state = state.copyWith(matchedLoading: false, error: _errorMessage(e, 'Gagal memuat foto yang cocok.'));
    }
  }

  Future<void> loadPurchases({int page = 1}) async {
    state = state.copyWith(purchasesLoading: true, error: null);
    try {
      final result = await _ref.read(potoCandidServiceProvider).purchases(page: page);
      state = state.copyWith(purchasedPhotos: result.data, purchasesLoading: false);
    } catch (e) {
      state = state.copyWith(purchasesLoading: false, error: _errorMessage(e, 'Gagal memuat foto yang dibeli.'));
    }
  }

  Future<bool> purchasePhoto(String photoId, {int matchedFaceIndex = 0}) async {
    try {
      await _ref.read(potoCandidServiceProvider).purchasePhoto(photoId, matchedFaceIndex: matchedFaceIndex);
      await loadMatchedPhotos();
      await loadPurchases();
      return true;
    } catch (e) {
      state = state.copyWith(error: _errorMessage(e, 'Gagal membeli foto.'));
      return false;
    }
  }
}

final potoCandidProvider = StateNotifierProvider<PotoCandidNotifier, PotoCandidState>(
  (ref) => PotoCandidNotifier(ref),
);
