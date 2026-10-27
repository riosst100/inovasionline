import 'dart:io';

import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/env.dart';
import '../core/api/api_client.dart';

/// An update Google Play offers this install, and whether admin requires it.
class AvailableUpdate {
  const AvailableUpdate({
    required this.play,
    required this.mandatory,
    this.message,
  });

  final AppUpdateInfo play;

  /// This build is below the minimum set in admin (Pengaturan → Update
  /// Aplikasi), so the app may not be used until it is updated.
  final bool mandatory;

  /// Admin's text for the blocking screen; null = default text.
  final String? message;
}

/// Google Play In-App Updates. Play downloads and installs the update itself,
/// so the app needs no install permission. Only works for installs that came
/// from Google Play; anywhere else (sideloaded / debug builds) the check
/// throws.
class AppUpdateService {
  AppUpdateService(this._apiClient);

  final ApiClient _apiClient;

  /// Android prod only: the dev flavor is not on Play.
  bool get isSupported => Platform.isAndroid && !Env.isDev;

  /// The update Play offers, or null when this build is already the latest.
  ///
  /// Only ever mandatory when Play really has an update for this device:
  /// during a staged rollout, or when the minimum is set ahead of the
  /// release, nobody gets stuck on a screen they cannot get past.
  Future<AvailableUpdate?> checkForUpdate() async {
    if (!isSupported) return null;

    final policyFuture = _fetchPolicy();
    final play = await InAppUpdate.checkForUpdate();
    final available = switch (play.updateAvailability) {
      UpdateAvailability.updateAvailable ||
      UpdateAvailability.developerTriggeredUpdateInProgress => true,
      _ => false,
    };
    if (!available) return null;

    final policy = await policyFuture;
    final currentBuild =
        int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;
    return AvailableUpdate(
      play: play,
      mandatory: policy != null && currentBuild < policy.minBuildNumber,
      message: policy?.message,
    );
  }

  /// Updates right away: Play's full-screen update when it allows one,
  /// otherwise (or when that fails) the app's Play Store page. Returns false
  /// only when the user backed out of Play's update screen.
  Future<bool> updateNow(AppUpdateInfo info) async {
    if (info.immediateUpdateAllowed) {
      try {
        final result = await InAppUpdate.performImmediateUpdate();
        if (result == AppUpdateResult.userDeniedUpdate) return false;
        if (result == AppUpdateResult.success) return true;
      } catch (_) {
        // Falls through to the Play Store page.
      }
    }
    await openPlayStore(info.packageName);
    return true;
  }

  Future<void> openPlayStore(String packageName) async {
    try {
      await launchUrl(
        Uri.parse('market://details?id=$packageName'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Nothing else to try; callers keep their update button available.
    }
  }

  /// Admin's minimum build; null when the backend cannot be reached, in which
  /// case the update stays optional.
  Future<({int minBuildNumber, String? message})?> _fetchPolicy() async {
    try {
      final response = await _apiClient.dio.get('/app-version');
      final data = response.data['data'] as Map<String, dynamic>;
      final message = (data['message'] as String?)?.trim();
      return (
        minBuildNumber: (data['min_build_number'] as num?)?.toInt() ?? 0,
        message: message == null || message.isEmpty ? null : message,
      );
    } catch (_) {
      return null;
    }
  }
}
