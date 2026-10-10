import 'dart:io';

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../core/api/api_client.dart';
import '../models/app_update_info.dart';

class AppUpdateService {
  AppUpdateService(this._apiClient);

  final ApiClient _apiClient;

  Future<AppUpdateInfo?> checkForUpdate() async {
    final response = await _apiClient.dio.get('/app-version/latest');
    final data = response.data['data'] as Map<String, dynamic>;
    final info = AppUpdateInfo.fromJson(data);

    final packageInfo = await PackageInfo.fromPlatform();
    final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

    if (info.buildNumber <= currentBuildNumber || info.apkUrl == null) {
      return null;
    }

    return info;
  }

  Future<File> downloadApk(
    String apkUrl, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/inovasionline-update.apk');

    await Dio().download(
      apkUrl,
      file.path,
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      },
    );

    return file;
  }
}
