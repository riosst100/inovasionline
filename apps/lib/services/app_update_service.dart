import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../config/env.dart';
import '../models/app_update_info.dart';

/// Checks the release.json next to the APK on the /download page (both are
/// published by CI via scripts/publish-apk.sh, with the same build number the
/// APK was built with), so a release needs no backend change.
class AppUpdateService {
  AppUpdateService();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  /// Only Android with a release URL configured (i.e. the prod flavor).
  bool get isSupported => Platform.isAndroid && Env.releaseBaseUrl != null;

  /// The newer release, or null when this build is already the latest.
  Future<AppUpdateInfo?> checkForUpdate() async {
    final baseUrl = Env.releaseBaseUrl;
    if (!Platform.isAndroid || baseUrl == null) return null;

    final response = await _dio.get<String>(
      '$baseUrl/release.json',
      // The web server / CDN may cache it; a stale copy would hide a release.
      queryParameters: {'t': DateTime.now().millisecondsSinceEpoch},
      options: Options(
        responseType: ResponseType.plain,
        headers: {'Cache-Control': 'no-cache'},
      ),
    );

    final packageInfo = await PackageInfo.fromPlatform();
    final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

    final info = AppUpdateInfo.fromReleaseJson(
      jsonDecode(response.data!) as Map<String, dynamic>,
      baseUrl: baseUrl,
      currentBuildNumber: currentBuildNumber,
    );

    if (info.buildNumber <= currentBuildNumber) return null;
    return info;
  }

  Future<File> downloadApk(
    AppUpdateInfo info, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/inovasionline-${info.buildNumber}.apk');

    await _dio.download(
      info.apkUrl,
      file.path,
      cancelToken: cancelToken,
      // A large APK on a slow connection: only give up when nothing arrives.
      options: Options(receiveTimeout: const Duration(minutes: 2)),
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      },
    );

    return file;
  }
}
